import AVFoundation
import Foundation
import ScoreModel

/// The microphone as a keyboard (rule 150).
///
/// Audio comes in from the device microphone, the score-informed
/// ``NoteDetector`` hears notes in it, and each detection is handed to the
/// same judgment a MIDI key press reaches. All detection runs off the main
/// thread; only the published state and the callback touch it.
public final class Microphone: ObservableObject, @unchecked Sendable {
  /// Whether the microphone is on and judging.
  @Published public private(set) var isListening = false

  /// How much signal is arriving, 0...1 (rule 150): weak is a position and
  /// volume problem, and only what is seen gets fixed.
  @Published public private(set) var level: Double = 0

  /// Called on the main thread with every note heard.
  public var onDetection: ((NoteDetector.Detection) -> Void)?

  private let engine = AVAudioEngine()
  private let worker = DispatchQueue(label: "pianova.microphone")

  // Worker-confined state.
  private var ear: NeuralEar?
  private var suspended = false

  /// What the cursor waits for, and what it will wait for next (rule 151).
  ///
  /// The model says what sounded; this says what counts. Everything else
  /// the room offers is heard and let go.
  private var expected: Set<Pitch> = []
  private var comingNext: Set<Pitch> = []

  /// Creates a silent microphone; ``start()`` asks permission and listens.
  public init() {}

  /// Asks permission and starts listening.
  public func start() {
    #if os(iOS)
    AVAudioApplication.requestRecordPermission { [weak self] granted in
      guard granted else { return }
      DispatchQueue.main.async { self?.listen() }
    }
    #else
    listen()
    #endif
  }

  private func listen() {
    guard !isListening else { return }

    #if os(iOS)
    // Measurement mode keeps the system's voice processing away from the
    // piano: gates and gain riding eat exactly the partials the ear needs.
    try? AVAudioSession.sharedInstance()
      .setCategory(
        .playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
    try? AVAudioSession.sharedInstance().setActive(true)
    #endif

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    worker.sync { note("listen: rate=\(format.sampleRate) channels=\(format.channelCount)") }
    guard format.sampleRate > 0 else {
      worker.sync { note("listen: dead input format") }
      return
    }

    guard let fresh = try? NeuralEar(sampleRate: format.sampleRate) else {
      worker.sync { note("listen: the model would not load") }
      return
    }
    worker.sync { ear = fresh }

    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
      guard let self, let channel = buffer.floatChannelData?.pointee else { return }
      let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
      self.worker.async { self.pump(samples) }
    }

    engine.prepare()
    do {
      try engine.start()
    } catch {
      worker.sync { note("listen: engine failed \(error)") }
      input.removeTap(onBus: 0)
      return
    }
    worker.sync { note("listen: engine up") }
    isListening = true
  }

  /// Stops listening and lets the audio input go.
  public func stop() {
    guard isListening else { return }
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    worker.sync { ear = nil }
    isListening = false
    level = 0
  }

  /// Tells the ear what the page is waiting for (rule 151).
  /// - Parameters:
  ///   - pitches: The notes the cursor asks for right now.
  ///   - next: What the cursor will ask for next, so an early note is kept.
  ///   - range: The piece's compass, widened a little.
  public func expect(
    _ pitches: Set<Pitch>, next: Set<Pitch> = [], among range: ClosedRange<Pitch>
  ) {
    worker.async { [weak self] in
      self?.expected = pitches
      self?.comingNext = next
    }
  }

  /// Silences judgment while the app itself is sounding (rule 152).
  /// - Parameter silenced: Whether to drop everything heard.
  public func setSuspended(_ silenced: Bool) {
    worker.async { [weak self] in self?.suspended = silenced }
  }

  /// A diary in Documents, pulled over the cable when a device test needs eyes.
  ///
  /// Temporary instrumentation for the microphone's first days.
  private let diary: URL = {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    return (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
      .appendingPathComponent("mic-log.txt")
  }()

  private var diaryLines: [String] = []

  private func note(_ line: String) {
    NSLog("MIC %@", line)
    diaryLines.append("\(Date()) \(line)")
    if diaryLines.count % 20 == 0 || line.hasPrefix("heard") || line.hasPrefix("listen") {
      try? diaryLines.joined(separator: "\n").write(to: diary, atomically: true, encoding: .utf8)
    }
  }

  /// Maps an RMS reading onto the 0...1 meter (rule 150).
  ///
  /// Logarithmic, like hearing: the floor sits at whisper-quiet, the top at
  /// recording-level loud, and a decently mic'd piano lands past the middle.
  public static func meter(rms: Double) -> Double {
    guard rms > 0 else { return 0 }
    let decibels = 20 * log10(rms)
    return min(1, max(0, (decibels - (-70)) / ((-20) - (-70))))
  }

  private var lastMeterPush = Date.distantPast

  /// Worker-side: feeds the detector and reports upward.
  private var pumped = 0

  private func pump(_ samples: [Float]) {
    guard !suspended, let ear else { return }
    pumped += 1
    let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1)))
    if pumped % 100 == 1 {
      note("pump #\(pumped) rms=\(String(format: "%.5f", rms))")
    }

    // The meter, throttled: ten honest readings a second beat a stream.
    if Date().timeIntervalSince(lastMeterPush) > 0.1 {
      lastMeterPush = Date()
      let reading = Self.meter(rms: Double(rms))
      DispatchQueue.main.async { [weak self] in self?.level = reading }
    }
    // The model lists what sounded; the score decides what counts
    // (rules 151 and 153). A note the page is not waiting for either way
    // is still reported, so a wrong note can be shown as wrong.
    let wanted = expected.union(comingNext)
    let found = ear.hear(samples)
      .map {
        NoteDetector.Detection(
          pitch: $0.pitch,
          velocity: UInt8(max(30, min(100, 30 + $0.confidence * 70))),
          isExpected: expected.contains($0.pitch))
      }

    guard !found.isEmpty else { return }
    for hit in found {
      note("heard midi=\(hit.pitch.midiNoteNumber) expected=\(hit.isExpected ? 1 : 0)")
    }
    DispatchQueue.main.async { [weak self] in
      for detection in found { self?.onDetection?(detection) }
    }
  }
}

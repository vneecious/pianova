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

  /// Called on the main thread with every note heard.
  public var onDetection: ((NoteDetector.Detection) -> Void)?

  private let engine = AVAudioEngine()
  private let worker = DispatchQueue(label: "pianova.microphone")

  // Worker-confined state.
  private var detector: NoteDetector?
  private var suspended = false

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
    guard format.sampleRate > 0 else { return }

    let fresh = NoteDetector(sampleRate: format.sampleRate)
    worker.sync { detector = fresh }

    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
      guard let self, let channel = buffer.floatChannelData?.pointee else { return }
      let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
      self.worker.async { self.pump(samples) }
    }

    engine.prepare()
    guard (try? engine.start()) != nil else {
      input.removeTap(onBus: 0)
      return
    }
    isListening = true
  }

  /// Stops listening and lets the audio input go.
  public func stop() {
    guard isListening else { return }
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    worker.sync { detector = nil }
    isListening = false
  }

  /// Tells the ear what the page is waiting for (rule 151).
  /// - Parameters:
  ///   - pitches: The notes the cursor asks for right now.
  ///   - range: The piece's compass, widened a little.
  public func expect(_ pitches: Set<Pitch>, among range: ClosedRange<Pitch>) {
    worker.async { [weak self] in self?.detector?.expect(pitches, among: range) }
  }

  /// Silences judgment while the app itself is sounding (rule 152).
  /// - Parameter silenced: Whether to drop everything heard.
  public func setSuspended(_ silenced: Bool) {
    worker.async { [weak self] in self?.suspended = silenced }
  }

  /// Worker-side: feeds the detector and reports upward.
  private func pump(_ samples: [Float]) {
    guard !suspended, let detector else { return }
    let found = detector.process(samples)
    guard !found.isEmpty else { return }
    DispatchQueue.main.async { [weak self] in
      for detection in found { self?.onDetection?(detection) }
    }
  }
}

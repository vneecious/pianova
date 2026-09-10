import AVFoundation
import Foundation
import MIDIInput
import ScoreModel

/// Sounds the on-screen keyboard.
///
/// The real instrument makes its own sound; this exists so the keyboard on
/// screen is not silent, which would train the eye and leave the ear out.
///
/// The waveform comes from ``PianoTone``, which is pure and tested. This type
/// is only the audio plumbing around it.
@MainActor
public final class TonePlayer: ObservableObject {
  /// Whether sound is turned off.
  @Published public var isMuted = false

  /// Whether notes are handed to the connected instrument instead of
  /// synthesised here.
  ///
  /// On by default: the closest thing to the player's own piano is the player's
  /// own piano, and routing also removes the double sound of the instrument and
  /// the app answering the same key.
  @Published public var routesToInstrument = true {
    didSet {
      guard !routesToInstrument else { return }
      instrument.allNotesOff()
    }
  }

  /// The connected instrument, when one answered.
  private let instrument = MIDIOutput()

  /// Whether sound is currently coming out of the instrument itself.
  public var isRoutingToInstrument: Bool { routesToInstrument && instrument.isConnected }

  /// Looks for an instrument to play through.
  /// - Returns: Whether one was found.
  @discardableResult
  public func connectInstrument() -> Bool {
    instrument.start()
  }

  /// Stops talking to the instrument, leaving nothing ringing.
  public func disconnectInstrument() {
    instrument.stop()
  }

  /// Whether real recorded samples are in use, rather than the synth.
  @Published public private(set) var usesSampledPiano = false

  private let engine = AVAudioEngine()
  private let voices = VoiceBank()
  private let sampler = AVAudioUnitSampler()
  /// Whether the nodes have been attached and connected.
  ///
  /// Separate from whether the engine is *running*, which is not ours to cache:
  /// the engine stops itself when the audio configuration changes, and a cached
  /// flag saying otherwise is exactly how the sound never comes back.
  private var isGraphBuilt = false

  /// Whether audio is actually flowing, asked of the engine rather than
  /// remembered.
  public var isRunning: Bool { engine.isRunning }

  /// What ``start()`` has to do, given the state of the engine and the graph.
  ///
  /// Pulled out as a plain function so the decision can be tested without an
  /// audio device, which is the part that got this wrong twice.
  /// - Parameters:
  ///   - engineRunning: Whether the engine is running right now.
  ///   - graphBuilt: Whether the nodes are attached and connected.
  /// - Returns: What needs doing.
  nonisolated static func startAction(
    engineRunning: Bool,
    graphBuilt: Bool
  ) -> StartAction {
    if engineRunning { return .nothing }
    return graphBuilt ? .startOnly : .buildAndStart
  }

  /// What starting the player needs to do.
  public enum StartAction: Equatable, Sendable {
    /// Audio is already flowing.
    case nothing
    /// The graph is intact; the engine just has to be started again.
    case startOnly
    /// The graph has to be built first.
    case buildAndStart
  }

  /// The sample bank macOS ships with, which contains a recorded grand piano.
  ///
  /// A synthesised tone can be made piano-like, but nothing sounds as much like
  /// a piano as a recording of one. Where the bank exists we use it; elsewhere
  /// the synth stands in.
  nonisolated private static let systemBank = URL(
    fileURLWithPath:
      "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

  /// Where a sound bank the user installed is looked for.
  ///
  /// Application Support rather than the app bundle, because the bank is the
  /// user's file under the user's licence: the app provides the mechanism, not
  /// the samples.
  public static var installedBankFolder: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    return (base.first ?? URL(fileURLWithPath: NSTemporaryDirectory()))
      .appendingPathComponent("Pianova", isDirectory: true)
      .appendingPathComponent("SoundBanks", isDirectory: true)
  }

  /// Sound banks shipped inside the app.
  ///
  /// Public domain material only, so it can travel with the app and work on
  /// first launch with nothing for the player to install. The folder may be
  /// empty in a fresh clone, and then the synthesiser takes over.
  public static func bundledBanks() -> [URL] {
    guard let folder = Bundle.module.url(forResource: "SoundBanks", withExtension: nil) else {
      return []
    }
    return banks(in: folder)
  }

  /// Sound banks the player installed themselves.
  public static func installedBanks() -> [URL] {
    banks(in: installedBankFolder)
  }

  /// Every loadable bank in a folder, by name.
  ///
  /// A recorded piano beats any amount of synthesis: the timbre comes from
  /// hundreds of strings resonating together, which is not something adding
  /// harmonics can reach.
  private static func banks(in folder: URL) -> [URL] {
    let contents =
      (try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil)) ?? []

    return
      contents
      .filter { ["sf2", "dls"].contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// Which bank to load, in order of preference.
  ///
  /// What the player chose comes first, then what ships with the app, and the
  /// system bank last — on macOS it exists but is a two-megabyte General MIDI
  /// set, a few kilobytes per instrument, and it sounds like it.
  /// - Parameters:
  ///   - installed: Banks the player put in place.
  ///   - bundled: Banks shipped inside the app.
  ///   - systemExists: Whether the system bank is present, as it is on macOS.
  /// - Returns: The bank to load, or `nil` to fall back to the synthesiser.
  nonisolated static func bankToLoad(
    installed: [URL],
    bundled: [URL],
    systemExists: Bool
  ) -> URL? {
    if let chosen = installed.first { return chosen }
    if let shipped = bundled.first { return shipped }
    return systemExists ? systemBank : nil
  }

  /// Which sound bank is in use, or `nil` when the synthesiser is.
  @Published public private(set) var loadedBankName: String?

  /// Copies a sound bank into place and reloads with it.
  ///
  /// The user supplies the samples, under whatever licence they chose: the app
  /// provides the mechanism, never the recordings.
  /// - Parameter url: The `.sf2` or `.dls` the user picked.
  /// - Throws: Whatever copying the file threw.
  public func installBank(from url: URL) throws {
    let folder = Self.installedBankFolder
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    let destination = folder.appendingPathComponent(url.lastPathComponent)
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: url, to: destination)

    reloadBank()
  }

  /// Rebuilds the audio graph so a newly installed bank is picked up.
  public func reloadBank() {
    teardown()
    start()
  }

  /// General MIDI programme number for the acoustic grand piano.
  private static let grandPianoProgram: UInt8 = 0

  /// Creates a silent player.
  ///
  /// Call ``start()`` before playing.
  public init() {
    observeConfigurationChanges()
  }

  /// Starts the audio engine.
  ///
  /// Safe to call again; a second call does nothing.
  public func start() {
    let action = Self.startAction(engineRunning: engine.isRunning, graphBuilt: isGraphBuilt)
    guard action != .nothing else { return }

    if action == .startOnly {
      do {
        engine.prepare()
        try engine.start()
        return
      } catch {
        // The graph did not survive whatever stopped the engine; rebuild it.
        teardown()
      }
    }

    #if os(iOS)
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    #endif

    let reported = engine.outputNode.inputFormat(forBus: 0)
    let resolved = Self.renderFormat(
      hardwareSampleRate: reported.sampleRate, hardwareChannels: reported.channelCount)
    let sampleRate = resolved.sampleRate
    voices.sampleRate = sampleRate

    // Try the recorded piano first; the synth is the fallback, not the plan.
    engine.attach(sampler)
    engine.connect(sampler, to: engine.mainMixerNode, format: nil)

    let bank = Self.bankToLoad(
      installed: Self.installedBanks(),
      bundled: Self.bundledBanks(),
      systemExists: FileManager.default.fileExists(atPath: Self.systemBank.path))

    if let bank {
      usesSampledPiano =
        (try? sampler.loadSoundBankInstrument(
          at: bank,
          program: Self.grandPianoProgram,
          bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
          bankLSB: UInt8(kAUSampler_DefaultBankLSB))) != nil
      loadedBankName = usesSampledPiano ? bank.deletingPathExtension().lastPathComponent : nil
    } else {
      usesSampledPiano = false
      loadedBankName = nil
    }

    let source = Self.makeSourceNode(voices: voices)

    let renderFormat = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate, channels: resolved.channels)

    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: renderFormat)

    isGraphBuilt = true

    do {
      engine.prepare()
      try engine.start()
    } catch {
      teardown()
    }
  }

  /// Drops the graph so the next ``start()`` builds it again.
  private func teardown() {
    engine.stop()
    for node in engine.attachedNodes where node !== engine.outputNode {
      engine.detach(node)
    }
    isGraphBuilt = false
  }

  /// Rebuilds and restarts whenever the audio configuration changes.
  ///
  /// Plugging the piano into the iPad is exactly this: the route changes, the
  /// engine stops itself and tears down its connections. Without this the app
  /// goes quiet the moment the instrument is connected — the one moment it must
  /// not.
  private func observeConfigurationChanges() {
    NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.teardown()
        self.start()
      }
    }
  }

  /// Sounds a note.
  /// - Parameters:
  ///   - pitch: The key that was struck.
  ///   - velocity: How hard, 1...127.
  public func play(_ pitch: Pitch, velocity: UInt8 = 80) {
    guard !isMuted else { return }

    if isRoutingToInstrument {
      instrument.noteOn(pitch, velocity: velocity)
      // The screen keyboard has no key release, so the instrument is told to
      // let go after long enough for its own sound to have decayed.
      Task { [instrument] in
        try? await Task.sleep(for: .seconds(3))
        instrument.noteOff(pitch)
      }
      return
    }

    start()

    guard usesSampledPiano else {
      voices.add(PianoTone(pitch: pitch, velocity: velocity))
      return
    }

    let note = pitch.midiNoteNumber
    sampler.startNote(note, withVelocity: velocity, onChannel: 0)

    // The screen keyboard has no key release, so the note is let go after long
    // enough for the sample to have decayed on its own.
    Task { [sampler] in
      try? await Task.sleep(for: .seconds(3))
      sampler.stopNote(note, onChannel: 0)
    }
  }

  /// Sample rate to fall back on when the hardware reports nothing usable.
  nonisolated static let fallbackSampleRate: Double = 44_100

  /// The format to render into, given what the output node reports.
  ///
  /// It cannot simply be trusted. On iOS the output node reports **0 Hz and 0
  /// channels** until the audio session is active and the engine prepared, and
  /// `AVAudioFormat` returns `nil` for zero channels — which leaves the
  /// synthesiser connected to nothing and the app completely silent. macOS
  /// reports a valid format straight away, so the bug only ever showed on the
  /// iPad.
  /// - Parameters:
  ///   - hardwareSampleRate: What the output node reports, possibly zero.
  ///   - hardwareChannels: What the output node reports, possibly zero.
  /// - Returns: A sample rate and channel count that are always usable.
  nonisolated static func renderFormat(
    hardwareSampleRate: Double,
    hardwareChannels: UInt32
  ) -> (sampleRate: Double, channels: UInt32) {
    let rate = hardwareSampleRate > 0 ? hardwareSampleRate : fallbackSampleRate
    return (sampleRate: rate, channels: max(hardwareChannels, 1))
  }

  /// Builds the render node outside the main actor.
  ///
  /// This has to be `nonisolated`. A closure written inside a `@MainActor`
  /// type inherits that isolation, and the audio thread calling it then trips
  /// the runtime's executor check and kills the process. Real-time audio never
  /// runs on the main actor.
  /// - Parameter voices: The bank to render from.
  /// - Returns: A source node safe to call from the audio thread.
  private nonisolated static func makeSourceNode(voices: VoiceBank) -> AVAudioSourceNode {
    AVAudioSourceNode { _, _, frameCount, audioBufferList in
      let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
      voices.render(frameCount: Int(frameCount), into: buffers)
      return noErr
    }
  }

  /// Sounds a metronome click.
  /// - Parameter isAccent: Whether it marks the first beat of the bar.
  public func click(isAccent: Bool = false) {
    guard !isMuted else { return }
    start()
    voices.add(PianoTone.click(isAccent: isAccent))
  }

  /// Silences everything currently ringing, here and on the instrument.
  public func stopAll() {
    instrument.allNotesOff()
    voices.removeAll()
    for note in UInt8(0)...UInt8(127) {
      sampler.stopNote(note, onChannel: 0)
    }
  }
}

/// The notes currently ringing.
///
/// Touched from the audio render thread, so it holds plain values behind a lock
/// and never allocates while rendering.
private final class VoiceBank: @unchecked Sendable {
  /// Most notes that may ring at once.
  ///
  /// Beyond this the oldest is dropped: a fixed ceiling keeps the render pass
  /// bounded, which matters more than letting a stuck chord pile up.
  private static let maxVoices = 16

  private struct Voice {
    let tone: PianoTone
    var frame: Int
  }

  private let lock = NSLock()
  private var voices: [Voice] = []
  private var rate: Double = 44_100

  var sampleRate: Double {
    get { lock.withLock { rate } }
    set { lock.withLock { rate = newValue } }
  }

  func add(_ tone: PianoTone) {
    lock.withLock {
      if voices.count >= Self.maxVoices {
        voices.removeFirst()
      }
      voices.append(Voice(tone: tone, frame: 0))
    }
  }

  func removeAll() {
    lock.withLock { voices.removeAll() }
  }

  func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
    lock.lock()
    let rate = self.rate
    var active = voices
    // Take the list and leave an empty one behind: anything struck while this
    // pass runs lands in the fresh list and is merged back at the end.
    voices.removeAll(keepingCapacity: true)
    lock.unlock()

    for frame in 0..<frameCount {
      var mix = 0.0

      for index in active.indices {
        let time = Double(active[index].frame) / rate
        mix += active[index].tone.sample(at: time)
        active[index].frame += 1
      }

      // Headroom so a full chord cannot clip.
      let value = Float(max(-1, min(1, mix * 0.35)))
      for buffer in buffers {
        let samples = buffer.mData?.assumingMemoryBound(to: Float.self)
        samples?[frame] = value
      }
    }

    active.removeAll { $0.tone.hasFaded(at: Double($0.frame) / rate) }

    lock.withLock {
      voices = active + voices
    }
  }
}

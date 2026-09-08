import AVFoundation
import Foundation
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

  /// Whether real recorded samples are in use, rather than the synth.
  @Published public private(set) var usesSampledPiano = false

  private let engine = AVAudioEngine()
  private let voices = VoiceBank()
  private let sampler = AVAudioUnitSampler()
  private var isRunning = false

  /// The sample bank macOS ships with, which contains a recorded grand piano.
  ///
  /// A synthesised tone can be made piano-like, but nothing sounds as much like
  /// a piano as a recording of one. Where the bank exists we use it; elsewhere
  /// the synth stands in.
  private static let systemBank = URL(
    fileURLWithPath:
      "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

  /// General MIDI programme number for the acoustic grand piano.
  private static let grandPianoProgram: UInt8 = 0

  /// Creates a silent player.
  ///
  /// Call ``start()`` before playing.
  public init() {}

  /// Starts the audio engine.
  ///
  /// Safe to call again; a second call does nothing.
  public func start() {
    guard !isRunning else { return }

    #if os(iOS)
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    #endif

    let format = engine.outputNode.inputFormat(forBus: 0)
    let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100
    voices.sampleRate = sampleRate

    // Try the recorded piano first; the synth is the fallback, not the plan.
    engine.attach(sampler)
    engine.connect(sampler, to: engine.mainMixerNode, format: nil)

    if FileManager.default.fileExists(atPath: Self.systemBank.path) {
      usesSampledPiano =
        (try? sampler.loadSoundBankInstrument(
          at: Self.systemBank,
          program: Self.grandPianoProgram,
          bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
          bankLSB: UInt8(kAUSampler_DefaultBankLSB))) != nil
    }

    let source = Self.makeSourceNode(voices: voices)

    let monoFormat = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate, channels: format.channelCount)

    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: monoFormat)

    do {
      try engine.start()
      isRunning = true
    } catch {
      isRunning = false
    }
  }

  /// Sounds a note.
  /// - Parameters:
  ///   - pitch: The key that was struck.
  ///   - velocity: How hard, 1...127.
  public func play(_ pitch: Pitch, velocity: UInt8 = 80) {
    guard !isMuted else { return }
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

  /// Silences everything currently ringing.
  public func stopAll() {
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

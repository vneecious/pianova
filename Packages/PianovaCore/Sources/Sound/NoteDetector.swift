import Accelerate
import Foundation
import ScoreModel

/// Hears notes in audio, guided by the score (rules 150-151).
///
/// Not a blind transcriber: the page says which pitches are expected, and
/// expectation is what makes a tablet microphone reliable. Each candidate
/// pitch is measured at its exact fundamental and harmonics (Goertzel — no
/// FFT bin quantisation, which matters in the bass), and a press is energy
/// born in an attack. Everything here is pure and runs the same on a file
/// of synthetic samples as on a live microphone.
public final class NoteDetector {
  /// One heard note.
  public struct Detection: Equatable, Sendable {
    /// What sounded.
    public let pitch: Pitch

    /// How hard, estimated from the attack's energy.
    public let velocity: UInt8

    /// Whether the score was waiting for it.
    public let isExpected: Bool
  }

  /// Analysis window: ~170 ms at 48 kHz — low notes need the length.
  private let window: Int

  /// Stride between analyses: ~43 ms at 48 kHz.
  private let hop: Int

  private let sampleRate: Double
  private var expected: Set<Pitch> = []
  private var candidates: [Pitch] = []
  private var buffer: [Float] = []
  private let hann: [Float]

  /// Each candidate's score as last seen, for telling attack from sustain.
  private var smoothed: [UInt8: Double] = [:]

  /// Which analysis frame is being looked at, for the refractory below.
  private var frameIndex = 0

  /// The room's quietness, crept up on slowly.
  ///
  /// Presses are only looked for well above this: at whisper level every
  /// ratio is noise against noise, and the page blinked red at silence.
  private var noiseFloor = 1e-3

  /// Accusations waiting for their second look (rule 151): a wrong note has
  /// to survive two consecutive windows before it is spoken — the click of
  /// a chair does not.
  private var suspicions: [UInt8: Int] = [:]

  /// The room's recent loudness, decaying slowly.
  ///
  /// Scores are read against this rather than against the frame's own level:
  /// a frame-relative score is blind to a re-attack — numerator and
  /// denominator double together — while against a slow gauge the new
  /// attack stands out as the jump it is.
  private var gauge = 0.0

  /// When each pitch was last pressed, in frames.
  ///
  /// One attack spans several overlapping windows, each seeing the score
  /// jump; without a refractory a single press reads as three or four.
  private var lastPress: [UInt8: Int] = [:]

  /// Creates a detector for one stream.
  /// - Parameter sampleRate: Samples per second of the incoming audio.
  public init(sampleRate: Double) {
    self.sampleRate = sampleRate
    window = 8192
    hop = 2048
    hann = vDSP.window(
      ofType: Float.self, usingSequence: .hanningDenormalized, count: 8192, isHalfWindow: false)
  }

  /// Tells the detector what the page is waiting for.
  /// - Parameters:
  ///   - pitches: The notes the cursor asks for right now.
  ///   - range: Every pitch worth watching — the piece's compass.
  public func expect(_ pitches: Set<Pitch>, among range: ClosedRange<Pitch>) {
    expected = pitches
    candidates = (range.lowerBound.midiNoteNumber...range.upperBound.midiNoteNumber)
      .map(Pitch.init)
  }

  /// Feeds audio and returns whatever new presses it heard.
  /// - Parameter samples: Mono samples at the detector's rate.
  /// - Returns: New detections, in time order.
  public func process(_ samples: [Float]) -> [Detection] {
    buffer.append(contentsOf: samples)
    var found: [Detection] = []

    while buffer.count >= window {
      found += analyze(Array(buffer.prefix(window)))
      buffer.removeFirst(hop)
    }
    return found
  }

  // MARK: - One window

  /// The relative weight of each harmonic in a note's score.
  private static let harmonicWeights: [Double] = [1, 0.6, 0.4, 0.25]

  /// A press must score at least this, relative to the frame's level.
  private static let pressThreshold = 0.1

  /// An unexpected note needs stronger evidence than an expected one.
  private static let accusationThreshold = 0.3

  /// An attack is a score jumping past its own recent past.
  ///
  /// Low enough that striking a key again over its own ringing still reads
  /// as a jump; a held note only decays, and never comes near it.
  private static let attackRatio = 1.5

  private func analyze(_ frame: [Float]) -> [Detection] {
    var rms: Float = 0
    vDSP_rmsqv(frame, 1, &rms, vDSP_Length(frame.count))

    // Silence resets the past: nothing rings, nothing compares.
    frameIndex += 1
    // The floor only learns from quiet: creeping up through the music ends
    // with the gate swallowing the piano itself.
    if Double(rms) < noiseFloor * 4 {
      noiseFloor = min(Double(max(rms, 1e-5)), noiseFloor * 1.02)
    }
    guard Double(rms) > max(2.5 * noiseFloor, 5e-4) else {
      smoothed = [:]
      suspicions = [:]
      return []
    }

    let windowed = vDSP.multiply(frame, hann)
    gauge = max(Double(rms), gauge * 0.98)
    let level = max(gauge, 1e-3)

    // Every candidate's harmonic amplitudes, at exact frequencies.
    var amplitudes: [UInt8: [Double]] = [:]
    var scores: [UInt8: Double] = [:]
    for pitch in candidates {
      let f0 = frequency(of: pitch)
      var partials: [Double] = []
      for rank in 1...Self.harmonicWeights.count {
        let f = f0 * Double(rank)
        guard f < sampleRate * 0.45 else { break }
        partials.append(goertzel(windowed, at: f))
      }
      amplitudes[pitch.midiNoteNumber] = partials
      let weighted = zip(partials, Self.harmonicWeights).reduce(0) { $0 + $1.0 * $1.1 }
      scores[pitch.midiNoteNumber] = weighted / (level + 1e-9)
    }

    var found: [Detection] = []
    var accused: [Detection] = []
    for pitch in candidates {
      let midi = pitch.midiNoteNumber
      let score = scores[midi] ?? 0
      let partials = amplitudes[midi] ?? []
      let isExpected = expected.contains(pitch)
      let threshold = isExpected ? Self.pressThreshold : Self.accusationThreshold

      let past = smoothed[midi] ?? 0
      defer { smoothed[midi] = max(score, past * 0.8) }

      let attacked = score > threshold && score > past * Self.attackRatio
      let sustained = score > threshold

      // A wrong note is only spoken after surviving two consecutive looks
      // (rule 151): an expected note answers on the attack, a suspicion has
      // to still be there in the next window.
      let confirmed: Bool
      if isExpected {
        confirmed = attacked
      } else if attacked {
        suspicions[midi] = frameIndex
        confirmed = false
      } else {
        confirmed = sustained && suspicions[midi] == frameIndex - 1
      }
      guard confirmed else { continue }

      // One attack, one press: the same jump seen by the next overlapping
      // window is still the same finger going down.
      if let last = lastPress[midi], frameIndex - last < 5 { continue }

      // A real note has its own fundamental — the octave above an expected
      // note does not put energy there (rule 151). In the bass the piano
      // itself barely sounds the fundamental, so the third partial vouches
      // instead: the octave-ghost only ever has the even ones.
      let strongest = partials.max() ?? 0
      let fundamental = partials.first ?? 0
      let oddPartial = partials.count > 2 ? partials[2] : 0
      let speaksForItself =
        fundamental >= 0.25 * strongest
        || (fundamental >= 0.05 * strongest && oddPartial >= 0.25 * strongest)
      guard speaksForItself else { continue }

      // The ghost guards protect against false ACCUSATIONS; the note the
      // score waits for answers for itself (rule 151). Without this, the
      // left hand's real E3 swallowed the melody's expected E4 as "just a
      // harmonic" — and octave doubling between hands is music, not noise.
      if !isExpected {
        // A harmonic of something louder is not a note of its own: never
        // accuse the overtones of a right note.
        if dominatedByLowerNote(pitch, scores: scores) { continue }

        // The attack's click spills energy onto the semitone neighbours; a
        // candidate dwarfed by one right beside it is that skirt, not a key.
        let neighbours = [-2, -1, 1, 2].compactMap { scores[UInt8(Int(midi) + $0)] }
        if let loudest = neighbours.max(), loudest > score * 2 { continue }
      }

      let velocity = UInt8(max(30, min(95, 30 + score * 45)))
      lastPress[midi] = frameIndex
      let detection = Detection(pitch: pitch, velocity: velocity, isExpected: isExpected)
      if isExpected {
        found.append(detection)
      } else {
        accused.append(detection)
      }
    }

    // No hand plays five wrong notes at once: a window accusing in bulk
    // heard a cough or a dropped pencil, and says nothing (rule 151).
    if accused.count <= 4 { found.append(contentsOf: accused) }
    return found
  }

  /// Whether this pitch sits on a harmonic of a stronger, lower candidate.
  private func dominatedByLowerNote(_ pitch: Pitch, scores: [UInt8: Double]) -> Bool {
    let f = frequency(of: pitch)
    let own = scores[pitch.midiNoteNumber] ?? 0

    for lower in candidates where lower < pitch {
      let base = frequency(of: lower)
      let ratio = f / base
      let nearest = ratio.rounded()
      guard nearest >= 2, nearest <= 6, abs(ratio - nearest) / nearest < 0.03 else { continue }
      if (scores[lower.midiNoteNumber] ?? 0) > own * 0.8 { return true }
    }
    return false
  }

  /// Equal temperament, A4 = 440 Hz.
  private func frequency(of pitch: Pitch) -> Double {
    440 * pow(2, (Double(pitch.midiNoteNumber) - 69) / 12)
  }

  /// Amplitude at one exact frequency — the Goertzel filter.
  private func goertzel(_ samples: [Float], at frequency: Double) -> Double {
    let omega = 2 * Double.pi * frequency / sampleRate
    let coefficient = 2 * cos(omega)
    var previous = 0.0
    var beforeThat = 0.0

    for sample in samples {
      let current = Double(sample) + coefficient * previous - beforeThat
      beforeThat = previous
      previous = current
    }

    let power =
      previous * previous + beforeThat * beforeThat - coefficient * previous * beforeThat
    // Normalised to read as amplitude: N/2 for the bin, half again for Hann.
    return sqrt(max(power, 0)) / (Double(samples.count) / 4)
  }
}

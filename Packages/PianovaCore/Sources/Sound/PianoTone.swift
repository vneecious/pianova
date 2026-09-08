import Foundation
import ScoreModel

extension Pitch {
  /// The frequency of this pitch in hertz, in equal temperament.
  ///
  /// Anchored on A4 at 440 Hz, the tuning reference. Every semitone multiplies
  /// the frequency by the twelfth root of two, so an octave doubles it.
  public var frequency: Double {
    440 * pow(2, (Double(midiNoteNumber) - 69) / 12)
  }
}

/// One struck note, as a waveform.
///
/// Pure maths: given a time it returns a sample. No audio hardware involved,
/// which is what makes the shape of the sound testable.
public struct PianoTone: Equatable, Sendable {
  /// How long the note takes to reach full volume, in seconds.
  ///
  /// Short but not instant: a hammer strike has a rise, and jumping straight to
  /// full amplitude clicks.
  public static let attack: Double = 0.006

  /// How quickly the note fades, as a time constant in seconds.
  public static let decayTime: Double = 0.9

  /// After this long the note is inaudible and can be discarded.
  public static let duration: Double = 3.0

  /// Relative loudness of the partials.
  ///
  /// A piano string is not a sine, and four partials are not enough either: the
  /// upper ones are most of what the ear uses to tell a struck string from a
  /// test tone.
  static let harmonics: [Double] = [1.0, 0.52, 0.34, 0.20, 0.13, 0.08, 0.05, 0.03]

  /// String stiffness, which pushes each partial sharp of a whole multiple.
  ///
  /// Real piano strings are stiff, so their partials are not exact multiples of
  /// the fundamental — they stretch upwards. This inharmonicity is the single
  /// most piano-like thing a synthesised tone can have; without it the sound
  /// reads as an organ.
  static let inharmonicity = 0.0004

  /// How much louder the hammer thud is on a hard strike.
  static let hammerLevel = 0.18

  /// The pitch being sounded.
  public let frequency: Double

  /// How hard the key was struck, from 0 to 1.
  public let amplitude: Double

  /// How quickly this note fades, as a time constant in seconds.
  ///
  /// A metronome click needs a far shorter one than a struck string, or the
  /// clicks blur into each other at speed.
  public let decay: Double

  /// Creates a tone.
  /// - Parameters:
  ///   - frequency: The pitch in hertz.
  ///   - amplitude: How hard the key was struck, from 0 to 1.
  ///   - decay: Time constant of the fade, in seconds.
  public init(frequency: Double, amplitude: Double, decay: Double = PianoTone.decayTime) {
    self.frequency = frequency
    self.amplitude = max(0, min(1, amplitude))
    self.decay = max(decay, 0.001)
  }

  /// Creates a tone for a pitch.
  /// - Parameters:
  ///   - pitch: The key that was struck.
  ///   - velocity: MIDI velocity, 1...127.
  public init(pitch: Pitch, velocity: UInt8) {
    self.init(frequency: pitch.frequency, amplitude: Double(velocity) / 127)
  }

  /// A metronome click: high, quiet and short.
  /// - Parameter isAccent: Whether it marks the first beat of the bar.
  /// - Returns: A tone that dies quickly enough not to blur the next beat.
  public static func click(isAccent: Bool = false) -> PianoTone {
    PianoTone(
      frequency: isAccent ? 1760 : 1320,
      amplitude: isAccent ? 0.5 : 0.32,
      decay: 0.05)
  }

  /// How long this note lasts before it can be discarded.
  public var lifetime: Double { min(decay * 4, Self.duration) }

  /// How loud the note is at a given moment, from 0 to 1.
  /// - Parameter time: Seconds since the key was struck.
  /// - Returns: The envelope value.
  public func envelope(at time: Double) -> Double {
    guard time > 0 else { return 0 }
    guard time >= Self.attack else { return time / Self.attack }
    return exp(-(time - Self.attack) / decay)
  }

  /// The waveform at a given moment, in the range -1...1.
  /// - Parameter time: Seconds since the key was struck.
  /// - Returns: One sample.
  public func sample(at time: Double) -> Double {
    guard time >= 0, time < lifetime else { return 0 }

    let weightSum = Self.harmonics.reduce(0, +)

    let wave = Self.harmonics.enumerated()
      .reduce(0.0) { total, pair in
        let partial = Double(pair.offset + 1)

        // Stiff strings stretch their partials sharp of a whole multiple.
        let stretch = sqrt(1 + Self.inharmonicity * partial * partial)
        let partialFrequency = frequency * partial * stretch

        // Upper partials die away far faster than the fundamental, which is
        // why a piano note turns from bright to mellow as it rings.
        let partialDecay = exp(-time * pow(partial, 1.4) * 0.55 / decay)

        // A hard strike excites the upper partials; a soft one barely does.
        let brightness = partial <= 2 ? 1 : (0.35 + 0.65 * amplitude)

        return total
          + pair.element * partialDecay * brightness
          * sin(2 * Double.pi * partialFrequency * time)
      }

    return (wave / weightSum + hammer(at: time)) * envelope(at: time) * amplitude
  }

  /// The thud of the hammer, a short burst at the very start of the note.
  ///
  /// Deterministic pseudo-noise rather than a random generator, so the waveform
  /// stays a pure function of time and can be reasoned about in tests.
  /// - Parameter time: Seconds since the key was struck.
  /// - Returns: The noise contribution, already faded.
  private func hammer(at time: Double) -> Double {
    guard time < 0.04 else { return 0 }

    let step = (time * 44_100).rounded()
    let scrambled = sin(step * 12.9898) * 43_758.5453
    let noise = scrambled - scrambled.rounded(.down) - 0.5

    return noise * Self.hammerLevel * exp(-time / 0.008)
  }

  /// Whether the note has faded past hearing.
  /// - Parameter time: Seconds since the key was struck.
  /// - Returns: `true` once it can be discarded.
  public func hasFaded(at time: Double) -> Bool {
    time >= lifetime
  }
}

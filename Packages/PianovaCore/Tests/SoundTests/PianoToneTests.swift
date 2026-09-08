import ScoreModel
import Testing

@testable import Sound

/// A4 is the tuning reference: 440 hertz.
@Test func aFourIsFourHundredAndForty() {
  #expect(abs(Pitch(69).frequency - 440) < 0.001)
}

/// An octave doubles the frequency.
@Test func anOctaveDoublesTheFrequency() {
  #expect(abs(Pitch(81).frequency - 880) < 0.001)
  #expect(abs(Pitch(57).frequency - 220) < 0.001)
}

/// Middle C sits at about 261.6 hertz.
@Test func middleCIsAboutTwoHundredAndSixtyTwoHertz() {
  #expect(abs(Pitch(60).frequency - 261.626) < 0.01)
}

/// Higher notes have higher frequencies, all the way up the keyboard.
@Test func frequencyRisesWithPitch() {
  let frequencies = (21...108).map { Pitch(UInt8($0)).frequency }

  #expect(zip(frequencies, frequencies.dropFirst()).allSatisfy { $1 > $0 })
}

private let tone = PianoTone(frequency: 440, amplitude: 1)

/// A note starts silent and rises during the attack.
@Test func theNoteRisesFromSilence() {
  #expect(tone.envelope(at: 0) == 0)
  #expect(tone.envelope(at: PianoTone.attack / 2) > 0)
  #expect(tone.envelope(at: PianoTone.attack / 2) < 1)
}

/// The envelope reaches full volume at the end of the attack.
@Test func theEnvelopePeaksAtTheEndOfTheAttack() {
  #expect(abs(tone.envelope(at: PianoTone.attack) - 1) < 0.001)
}

/// After the attack the note only fades.
@Test func theNoteOnlyFadesAfterTheAttack() {
  let times = stride(from: PianoTone.attack, through: 2.0, by: 0.05).map { $0 }
  let values = times.map { tone.envelope(at: $0) }

  #expect(zip(values, values.dropFirst()).allSatisfy { $1 < $0 })
}

/// The envelope never exceeds full volume, so notes cannot clip on their own.
@Test func theEnvelopeNeverExceedsOne() {
  let times = stride(from: 0, through: 3.0, by: 0.001).map { $0 }

  #expect(times.allSatisfy { tone.envelope(at: $0) <= 1.0001 })
}

/// Samples stay inside the range an audio buffer accepts.
@Test func samplesStayInRange() {
  let times = stride(from: 0, through: 2.0, by: 0.0001).map { $0 }

  #expect(times.allSatisfy { abs(tone.sample(at: $0)) <= 1 })
}

/// Energy of a tone over a window, which is how loudness is actually measured.
private func energy(_ tone: PianoTone, from start: Double, to end: Double) -> Double {
  let step = 1.0 / 44_100
  var total = 0.0
  var time = start

  while time < end {
    let value = tone.sample(at: time)
    total += value * value
    time += step
  }

  return total
}

/// A softer strike is quieter.
///
/// Measured as energy over a window, not sample by sample: velocity now changes
/// the timbre as well as the level, so the two waveforms have different shapes
/// and either can be at a peak while the other crosses zero.
@Test func aSofterStrikeIsQuieter() {
  let soft = PianoTone(frequency: 440, amplitude: 0.25)

  #expect(energy(soft, from: 0.01, to: 0.5) < energy(tone, from: 0.01, to: 0.5))
}

/// A harder strike is brighter, not merely louder.
///
/// The upper partials carry more of the sound when the hammer hits harder,
/// which is what makes a real piano change colour with dynamics.
@Test func aHarderStrikeIsBrighter() {
  let soft = PianoTone(frequency: 220, amplitude: 0.2)
  let hard = PianoTone(frequency: 220, amplitude: 1.0)

  // Normalise out the level difference and compare what is left in the attack,
  // where the upper partials still ring.
  let softShape = energy(soft, from: 0.001, to: 0.05) / (0.2 * 0.2)
  let hardShape = energy(hard, from: 0.001, to: 0.05) / (1.0 * 1.0)

  #expect(hardShape > softShape)
}

/// Partials are stretched sharp, as stiff strings really are.
@Test func partialsAreStretchedSharp() {
  #expect(PianoTone.inharmonicity > 0)
}

/// Velocity maps into amplitude, and is clamped to a sane range.
@Test func velocityMapsIntoAmplitude() {
  let hard = PianoTone(pitch: Pitch(60), velocity: 127)
  let soft = PianoTone(pitch: Pitch(60), velocity: 20)

  #expect(hard.amplitude > soft.amplitude)
  #expect(hard.amplitude <= 1)
  #expect(PianoTone(frequency: 440, amplitude: 5).amplitude == 1)
  #expect(PianoTone(frequency: 440, amplitude: -3).amplitude == 0)
}

/// Nothing sounds before the key is struck, or after the note has died.
@Test func nothingSoundsOutsideTheNote() {
  #expect(tone.sample(at: -0.5) == 0)
  #expect(tone.sample(at: PianoTone.duration + 0.1) == 0)
  #expect(tone.hasFaded(at: PianoTone.duration))
  #expect(tone.hasFaded(at: 0.5) == false)
}

/// A tone built from a pitch sounds at that pitch's frequency.
@Test func aToneFromAPitchUsesItsFrequency() {
  #expect(PianoTone(pitch: Pitch(69), velocity: 100).frequency == Pitch(69).frequency)
}

/// A click dies quickly, so beats do not blur into each other.
@Test func aClickFadesFasterThanAStruckNote() {
  let click = PianoTone.click()
  let note = PianoTone(frequency: 440, amplitude: 1)

  #expect(click.decay < note.decay)
  #expect(click.lifetime < 0.3)
  #expect(click.hasFaded(at: 0.3))
}

/// The downbeat click is louder and higher than the others.
@Test func theDownbeatClickStandsOut() {
  #expect(PianoTone.click(isAccent: true).amplitude > PianoTone.click().amplitude)
  #expect(PianoTone.click(isAccent: true).frequency > PianoTone.click().frequency)
}

/// A shorter decay really does silence the note sooner.
@Test func aShorterDecaySilencesSooner() {
  let quick = PianoTone(frequency: 440, amplitude: 1, decay: 0.05)
  let slow = PianoTone(frequency: 440, amplitude: 1, decay: 1.0)

  #expect(quick.envelope(at: 0.2) < slow.envelope(at: 0.2))
}

/// A silly decay cannot divide by zero.
@Test func aSillyDecayIsClamped() {
  #expect(PianoTone(frequency: 440, amplitude: 1, decay: 0).decay > 0)
  #expect(PianoTone(frequency: 440, amplitude: 1, decay: -5).decay > 0)
}

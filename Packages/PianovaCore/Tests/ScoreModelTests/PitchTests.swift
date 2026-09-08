import Testing

@testable import ScoreModel

/// Middle C is MIDI note 60.
///
/// This anchors every other pitch calculation.
@Test func middleCIsMidiNoteSixty() {
  #expect(Pitch(60).midiNoteNumber == 60)
}

/// Pitches with the same note number are the same pitch, so they collapse in a set.
///
/// Chord items depend on this.
@Test func pitchesWithTheSameNoteNumberAreEqual() {
  #expect(Pitch(60) == Pitch(60))
  #expect(Set([Pitch(60), Pitch(60), Pitch(64)]).count == 2)
}

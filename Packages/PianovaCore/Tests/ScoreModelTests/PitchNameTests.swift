import Testing

@testable import ScoreModel

/// Middle C is C4 in scientific pitch notation.
@Test func middleCIsNamedC4() {
  #expect(Pitch(60).scientificName == "C4")
}

/// Black keys are spelled with sharps.
@Test func blackKeysUseSharps() {
  #expect(Pitch(61).scientificName == "C#4")
  #expect(Pitch(66).scientificName == "F#4")
}

/// The octave number changes at C, not at A.
@Test func octaveNumberChangesAtC() {
  #expect(Pitch(59).scientificName == "B3")
  #expect(Pitch(60).scientificName == "C4")
}

/// The ends of an 88-key keyboard are A0 and C8.
@Test func keyboardExtremesAreNamedCorrectly() {
  #expect(Pitch(21).scientificName == "A0")
  #expect(Pitch(108).scientificName == "C8")
}

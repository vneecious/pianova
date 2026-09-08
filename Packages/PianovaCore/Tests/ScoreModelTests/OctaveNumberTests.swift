import Testing

@testable import ScoreModel

/// Middle C sits in octave 4.
@Test func middleCIsInOctaveFour() {
  #expect(Pitch(60).octaveNumber == 4)
}

/// The octave number changes at C, not at A.
@Test func octaveNumberRollsOverAtC() {
  #expect(Pitch(59).octaveNumber == 3)
  #expect(Pitch(60).octaveNumber == 4)
  #expect(Pitch(71).octaveNumber == 4)
  #expect(Pitch(72).octaveNumber == 5)
}

/// The ends of an 88-key keyboard are in octaves 0 and 8.
@Test func keyboardExtremesLandInTheExpectedOctaves() {
  #expect(Pitch(21).octaveNumber == 0)
  #expect(Pitch(108).octaveNumber == 8)
}

/// The octave number agrees with the scientific name already in use.
@Test func octaveNumberAgreesWithTheScientificName() {
  for note in [21, 43, 60, 61, 77, 108] {
    let pitch = Pitch(UInt8(note))
    #expect(pitch.scientificName.hasSuffix("\(pitch.octaveNumber)"))
  }
}

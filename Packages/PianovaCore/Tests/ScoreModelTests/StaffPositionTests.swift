import Testing

@testable import ScoreModel

/// The bottom line of the treble staff is E4, by definition.
@Test func trebleBottomLineIsE4() {
  #expect(Pitch(64).staffStep(in: .treble) == 0)
}

/// The top line of the treble staff is F5.
///
/// Lines sit on even steps, so the five lines are 0, 2, 4, 6 and 8.
@Test func trebleTopLineIsF5() {
  #expect(Pitch(77).staffStep(in: .treble) == 8)
}

/// Middle C sits on the first ledger line below the treble staff.
///
/// This is the single most important landmark when learning to read, and the
/// exact claim the README makes about connecting staff to keyboard.
@Test func middleCIsOneLedgerLineBelowTheTrebleStaff() {
  #expect(Pitch(60).staffStep(in: .treble) == -2)
}

/// The bottom line of the bass staff is G2.
@Test func bassBottomLineIsG2() {
  #expect(Pitch(43).staffStep(in: .bass) == 0)
}

/// The top line of the bass staff is A3.
@Test func bassTopLineIsA3() {
  #expect(Pitch(57).staffStep(in: .bass) == 8)
}

/// Middle C sits on the first ledger line above the bass staff.
///
/// The mirror of the treble case: the same key, drawn in two different places.
@Test func middleCIsOneLedgerLineAboveTheBassStaff() {
  #expect(Pitch(60).staffStep(in: .bass) == 10)
}

/// An accidental does not move the note head.
///
/// C sharp is drawn on the C line with a sharp in front of it, not between
/// C and D.
@Test func sharpsSitOnTheSameStepAsTheNaturalNote() {
  #expect(Pitch(61).staffStep(in: .treble) == Pitch(60).staffStep(in: .treble))
  #expect(Pitch(66).staffStep(in: .treble) == Pitch(65).staffStep(in: .treble))
}

/// Consecutive letter names are one half-space apart.
@Test func adjacentLetterNamesDifferByOneStep() {
  #expect(Pitch(62).staffStep(in: .treble) - Pitch(60).staffStep(in: .treble) == 1)
  #expect(Pitch(64).staffStep(in: .treble) - Pitch(62).staffStep(in: .treble) == 1)
}

/// An octave spans seven diatonic steps.
@Test func anOctaveSpansSevenSteps() {
  #expect(Pitch(72).staffStep(in: .treble) - Pitch(60).staffStep(in: .treble) == 7)
}

/// Black keys are the ones needing a sharp sign.
@Test func blackKeysRequireASharp() {
  #expect(Pitch(61).requiresSharp)
  #expect(Pitch(66).requiresSharp)
  #expect(Pitch(70).requiresSharp)
}

/// White keys never carry an accidental.
@Test func whiteKeysDoNotRequireASharp() {
  for note in [60, 62, 64, 65, 67, 69, 71] {
    #expect(Pitch(UInt8(note)).requiresSharp == false)
  }
}

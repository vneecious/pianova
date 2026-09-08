import Testing

@testable import ScoreModel

/// Every white key maps to its own letter.
@Test func whiteKeysMapToTheirLetters() {
  #expect(Pitch(60).letter == .c)
  #expect(Pitch(62).letter == .d)
  #expect(Pitch(64).letter == .e)
  #expect(Pitch(65).letter == .f)
  #expect(Pitch(67).letter == .g)
  #expect(Pitch(69).letter == .a)
  #expect(Pitch(71).letter == .b)
}

/// An accidental does not change the letter.
///
/// README › Modo cards rule 6 depends on this: C sharp is answered as C.
@Test func sharpsKeepTheLetterOfTheNaturalBelow() {
  #expect(Pitch(61).letter == .c)
  #expect(Pitch(66).letter == .f)
  #expect(Pitch(70).letter == .a)
}

/// The letter repeats every octave.
@Test func lettersRepeatEveryOctave() {
  #expect(Pitch(48).letter == .c)
  #expect(Pitch(60).letter == .c)
  #expect(Pitch(72).letter == .c)
}

/// Letters run C through B, matching the diatonic order used on the staff.
@Test func lettersAreOrderedFromC() {
  #expect(NoteLetter.allCases.map(\.rawValue) == [0, 1, 2, 3, 4, 5, 6])
  #expect(NoteLetter.allCases.first == .c)
  #expect(NoteLetter.allCases.last == .b)
}

import CoreGraphics
import Testing

@testable import ScoreModel

private let octave = KeyboardLayout(range: 60...72)

/// An octave from middle C has eight white keys, C through the next C.
@Test func anOctaveHasEightWhiteKeys() {
  #expect(octave.whiteKeys.map(\.midiNoteNumber) == [60, 62, 64, 65, 67, 69, 71, 72])
}

/// An octave has five black keys.
@Test func anOctaveHasFiveBlackKeys() {
  #expect(octave.blackKeys.map(\.midiNoteNumber) == [61, 63, 66, 68, 70])
}

/// In the group of two, C sharp leans left of the gap and D sharp leans right.
///
/// This asymmetry is what a real keyboard looks like, and it is how a hand
/// finds its place without looking.
@Test func theGroupOfTwoLeansOutwards() {
  let cSharp = octave.blackKeyCentre(for: Pitch(61))
  let dSharp = octave.blackKeyCentre(for: Pitch(63))

  #expect(cSharp != nil && cSharp! < 1)
  #expect(dSharp != nil && dSharp! > 2)
}

/// In the group of three, F sharp leans left, G sharp is centred and A sharp
/// leans right.
@Test func theGroupOfThreeFansOut() {
  let fSharp = octave.blackKeyCentre(for: Pitch(66))
  let gSharp = octave.blackKeyCentre(for: Pitch(68))
  let aSharp = octave.blackKeyCentre(for: Pitch(70))

  #expect(fSharp != nil && fSharp! < 4)
  #expect(gSharp == 5)
  #expect(aSharp != nil && aSharp! > 6)
}

/// Black keys stay near their gap: leaning is not drifting onto a neighbour.
@Test func blackKeysStayNearTheirGap() {
  for black in octave.blackKeys {
    guard let centre = octave.blackKeyCentre(for: black),
      let below = octave.whiteKeyIndex(of: Pitch(black.midiNoteNumber - 1))
    else {
      Issue.record("sem posição para \(black.scientificName)")
      continue
    }

    #expect(abs(centre - CGFloat(below + 1)) <= 0.2)
  }
}

/// There is no black key between E and F, nor between B and C.
@Test func thereAreNoBlackKeysInTheGaps() {
  #expect(octave.blackKeyCentre(for: Pitch(64)) == nil)
  #expect(octave.blackKeyCentre(for: Pitch(65)) == nil)
  #expect(octave.blackKeyCentre(for: Pitch(71)) == nil)
}

/// White keys report their position, left to right.
@Test func whiteKeysReportTheirPosition() {
  #expect(octave.whiteKeyIndex(of: Pitch(60)) == 0)
  #expect(octave.whiteKeyIndex(of: Pitch(62)) == 1)
  #expect(octave.whiteKeyIndex(of: Pitch(72)) == 7)
  #expect(octave.whiteKeyIndex(of: Pitch(61)) == nil)
}

/// A range starting on a black key still lays out correctly.
@Test func rangesStartingOnABlackKeyStillLayOut() {
  let layout = KeyboardLayout(range: 61...65)

  #expect(layout.whiteKeys.map(\.midiNoteNumber) == [62, 64, 65])
  #expect(layout.blackKeys.map(\.midiNoteNumber) == [61, 63])
}

/// The standard keyboard is a fixed window, not one derived from an exercise.
///
/// Finding the note is part of the exercise, so the keyboard must not shrink to
/// only the keys that are needed.
@Test func theStandardKeyboardIsAFixedWindow() {
  #expect(KeyboardLayout.standard.range == 36...84)
  #expect(KeyboardLayout.standard.whiteKeys.count == 29)
  #expect(KeyboardLayout.standard.range.contains(60))
}

/// Keys are asked to be comfortably larger than the minimum touch target.
@Test func keysAreComfortablyLargerThanTheTouchMinimum() {
  #expect(KeyboardLayout.preferredWhiteKeyWidth >= 44)
  #expect(KeyboardLayout.standard.preferredWidth == 29 * KeyboardLayout.preferredWhiteKeyWidth)
}

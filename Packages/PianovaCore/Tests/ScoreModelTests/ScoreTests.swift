import Testing

@testable import ScoreModel

/// Rule 33 — a bar that holds what the signature asks is complete.
@Test func aFullBarIsComplete() {
  let bar = Measure([
    ScoreNote(Pitch(60), .quarter), ScoreNote(Pitch(62), .quarter),
    ScoreNote(Pitch(64), .half),
  ])

  #expect(bar.beats == 4)
  #expect(bar.isComplete(in: .fourFour))
  #expect(bar.isComplete(in: .threeFour) == false)
}

/// Rule 33 — a bar that overflows is not complete either.
@Test func anOverfullBarIsNotComplete() {
  let bar = Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 5))

  #expect(bar.isComplete(in: .fourFour) == false)
}

/// Rule 35 — a rest occupies time without sounding.
@Test func aRestTakesTimeAndSoundsNothing() {
  let rest = ScoreNote.rest(.half)

  #expect(rest.isRest)
  #expect(rest.pitches.isEmpty)
  #expect(rest.beats == 2)
}

/// A dotted figure is worth half again.
@Test func aDottedFigureIsWorthHalfAgain() {
  #expect(ScoreNote(Pitch(60), .half, dotted: true).beats == 3)
  #expect(ScoreNote(Pitch(60), .quarter, dotted: true).beats == 1.5)
}

/// A rest is not something to strike, so it never reaches the engine.
@Test func restsAreNotOfferedAsPitchesToPlay() {
  let part = Part(
    clef: .treble,
    measures: [
      Measure([
        ScoreNote(Pitch(60), .quarter), .rest(.quarter),
        ScoreNote(Pitch(64), .half),
      ])
    ])

  #expect(part.soundingPitches.map(\.midiNoteNumber) == [60, 64])
  #expect(part.notes.count == 3)
}

/// A chord is one event with several pitches.
@Test func aChordIsOneEvent() {
  let chord = ScoreNote(
    pitches: [60, 64, 67].map { Pitch(UInt8($0)) }, duration: Duration(.half))

  #expect(chord.beats == 2)
  #expect(chord.pitches.count == 3)
  #expect(chord.isRest == false)
}

// MARK: - Key signatures

/// Sharps are written in the fixed order F C G D A E B.
@Test func sharpsAreWrittenInTheConventionalOrder() {
  #expect(KeySignature(fifths: 1).alteredLetters == [.f])
  #expect(KeySignature(fifths: 3).alteredLetters == [.f, .c, .g])
  #expect(KeySignature(fifths: 1).usesSharps)
}

/// Flats run the same list backwards: B E A D G C F.
@Test func flatsAreWrittenInReverseOrder() {
  #expect(KeySignature(fifths: -1).alteredLetters == [.b])
  #expect(KeySignature(fifths: -3).alteredLetters == [.b, .e, .a])
  #expect(KeySignature(fifths: -2).usesSharps == false)
}

/// C major writes nothing at all.
@Test func cMajorWritesNoAccidental() {
  #expect(KeySignature.c.accidentalCount == 0)
  #expect(KeySignature.c.alteredLetters.isEmpty)
}

// MARK: - Whole scores

/// A score whose bars all fill is well formed.
@Test func aScoreWithFullBarsIsWellFormed() {
  let score = Score(
    title: "Teste", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4)),
        Measure([ScoreNote(Pitch(60), .whole)]),
      ]))

  #expect(score.isWellFormed)
  #expect(score.incompleteMeasures.isEmpty)
}

/// Rule 33 — a short bar in the middle is reported, and says which one.
@Test func aShortBarIsReportedWithItsPosition() {
  let score = Score(
    title: "Teste", composer: "—",
    rightHand: Part(
      clef: .treble,
      measures: [
        Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4)),
        Measure([ScoreNote(Pitch(60), .half)]),
      ]))

  #expect(score.isWellFormed == false)
  #expect(score.incompleteMeasures.count == 1)
  #expect(score.incompleteMeasures.first?.index == 1)
}

/// Rule 33 — an upbeat bar is short on purpose, and only the first one is.
@Test func onlyThePickupBarMayBeShort() {
  let pickup = Measure([ScoreNote(Pitch(67), .quarter)])
  let full = Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4))

  let good = Score(
    title: "Anacruse", composer: "—",
    rightHand: Part(clef: .treble, measures: [pickup, full]),
    hasPickup: true)
  #expect(good.isWellFormed)

  // The same short bar in second place is a mistake, not an upbeat.
  let bad = Score(
    title: "Anacruse", composer: "—",
    rightHand: Part(clef: .treble, measures: [full, pickup]),
    hasPickup: true)
  #expect(bad.isWellFormed == false)
}

/// Both hands are checked, not just the one that is read first.
@Test func theLeftHandIsCheckedToo() {
  let full = Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4))
  let short = Measure([ScoreNote(Pitch(48), .quarter)])

  let score = Score(
    title: "Duas mãos", composer: "—",
    rightHand: Part(clef: .treble, measures: [full]),
    leftHand: Part(clef: .bass, measures: [short]))

  #expect(score.isWellFormed == false)
  #expect(score.incompleteMeasures.first?.part == .bass)
  #expect(score.isTwoHanded)
}

/// Rule 31 — a score carries its own time signature and key.
@Test func aScoreCarriesItsTimeSignatureAndKey() {
  let score = Score(
    title: "Valsa", composer: "—",
    timeSignature: .threeFour, key: .g,
    rightHand: Part(
      clef: .treble,
      measures: [Measure(Array(repeating: ScoreNote(Pitch(67), .quarter), count: 3))]))

  #expect(score.timeSignature.beatsPerBar == 3)
  #expect(score.timeSignature.label == "3/4")
  #expect(score.key.fifths == 1)
  #expect(score.isWellFormed)
}

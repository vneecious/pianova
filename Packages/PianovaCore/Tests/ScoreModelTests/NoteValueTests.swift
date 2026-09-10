import Testing

@testable import ScoreModel

/// The figures follow the halving that defines the whole system.
@Test func eachFigureIsHalfTheOneBefore() {
  #expect(NoteValue.whole.beats == 4)
  #expect(NoteValue.half.beats == NoteValue.whole.beats / 2)
  #expect(NoteValue.quarter.beats == NoteValue.half.beats / 2)
  #expect(NoteValue.eighth.beats == NoteValue.quarter.beats / 2)
}

/// Two of a figure are worth one of the figure above it.
@Test func twoOfAFigureMakeTheOneAbove() {
  #expect(NoteValue.eighth.beats * 2 == NoteValue.quarter.beats)
  #expect(NoteValue.quarter.beats * 2 == NoteValue.half.beats)
  #expect(NoteValue.half.beats * 2 == NoteValue.whole.beats)
}

/// Figures order by length, longest last when sorted ascending.
@Test func figuresOrderByLength() {
  #expect(NoteValue.sixteenth < NoteValue.eighth)
  #expect(NoteValue.eighth < NoteValue.quarter)
  #expect(NoteValue.quarter < NoteValue.half)
  #expect(NoteValue.allCases.sorted().first == .sixteenth)
  #expect(NoteValue.allCases.sorted().last == .whole)
}

/// Each figure carries its Portuguese name and the name of its rest.
@Test func figuresAreNamedInPortuguese() {
  #expect(NoteValue.whole.name == "semibreve")
  #expect(NoteValue.quarter.name == "semínima")
  #expect(NoteValue.quarter.restName == "pausa de semínima")
}

/// A dot adds half the figure's own value.
@Test func aDotAddsHalfTheValue() {
  #expect(Duration(.half, dotted: true).beats == 3)
  #expect(Duration(.quarter, dotted: true).beats == 1.5)
  #expect(Duration(.whole, dotted: true).beats == 6)
}

/// Without a dot the duration is just the figure.
@Test func withoutADotTheDurationIsThePlainFigure() {
  #expect(Duration(.quarter).beats == 1)
  #expect(Duration(.quarter).isDotted == false)
}

/// A dotted figure reads as such.
@Test func dottedFiguresAreNamedAsDotted() {
  #expect(Duration(.half, dotted: true).name == "mínima pontuada")
  #expect(Duration(.half).name == "mínima")
}

/// A bar of four four holds four beats.
@Test func fourFourHoldsFourBeats() {
  #expect(TimeSignature.fourFour.beatsPerBar == 4)
  #expect(TimeSignature.fourFour.beatValue == .quarter)
  #expect(TimeSignature.fourFour.label == "4/4")
}

/// Three four holds three, with the same unit.
@Test func threeFourHoldsThreeBeats() {
  #expect(TimeSignature.threeFour.beatsPerBar == 3)
  #expect(TimeSignature.threeFour.label == "3/4")
}

/// The lower number names the figure worth one beat.
@Test func theLowerNumberNamesTheBeatFigure() {
  #expect(TimeSignature(beatsPerBar: 6, beatValue: .eighth).label == "6/8")
  #expect(TimeSignature(beatsPerBar: 2, beatValue: .half).label == "2/2")
}

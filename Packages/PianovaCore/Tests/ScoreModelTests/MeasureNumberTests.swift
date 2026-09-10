import Testing

@testable import ScoreModel

/// Four bars of four crotchets.
private let plain = Score(
  title: "Quatro compassos", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: (0..<4)
      .map { _ in
        Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4))
      }))

/// The same, opening on a single upbeat crotchet.
private let withPickup = Score(
  title: "Com anacruse", composer: "—",
  rightHand: Part(
    clef: .treble,
    measures: [Measure([ScoreNote(Pitch(67), .quarter)])]
      + (0..<3)
      .map { _ in
        Measure(Array(repeating: ScoreNote(Pitch(60), .quarter), count: 4))
      }),
  hasPickup: true)

/// Rule 73 — the first bar is 1, not 0.
@Test func theFirstBarIsNumberOne() {
  #expect(plain.measureNumber(atColumn: 0) == 1)
  #expect(plain.measureNumber(atColumn: 3) == 1)
}

/// Rule 73 — the number goes up once per bar line, and only there.
@Test func theNumberRisesAtEachBarLine() {
  #expect(plain.measureNumber(atColumn: 4) == 2)
  #expect(plain.measureNumber(atColumn: 7) == 2)
  #expect(plain.measureNumber(atColumn: 8) == 3)
  #expect(plain.measureNumber(atColumn: 12) == 4)
}

/// Rule 74 — an upbeat is not numbered, and the first full bar is 1.
@Test func thePickupIsNotNumbered() {
  #expect(withPickup.measureNumber(atColumn: 0) == 0, "a anacruse não recebe número")
  #expect(withPickup.measureNumber(atColumn: 1) == 1, "o primeiro compasso cheio é o 1")
  #expect(withPickup.measureNumber(atColumn: 5) == 2)
}

/// Numbering never goes backwards as the piece runs.
@Test func numberingOnlyRises() {
  for score in [plain, withPickup] {
    var previous = -1
    for column in score.columns.indices {
      let number = score.measureNumber(atColumn: column)
      #expect(number >= previous, "\(score.title): número caiu na coluna \(column)")
      previous = number
    }
  }
}

/// The last column belongs to the last bar, and there are as many as written.
@Test func theLastColumnIsInTheLastBar() {
  #expect(plain.measureNumber(atColumn: plain.columns.count - 1) == 4)
  #expect(withPickup.measureNumber(atColumn: withPickup.columns.count - 1) == 3)
}

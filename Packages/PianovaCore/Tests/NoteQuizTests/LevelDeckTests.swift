import ScoreModel
import Testing

@testable import NoteQuiz

/// Deterministic randomness, so deck tests do not flake.
private struct FixedGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private let trebleOnly = QuizLevel(sections: [.init(clef: .treble, range: 64...77)])
private let mixed = QuizLevel(sections: [
  .init(clef: .treble, range: 60...77),
  .init(clef: .bass, range: 43...60),
])

/// A single-clef level only ever produces that clef.
@Test func singleClefLevelPoolUsesOneClef() {
  let pool = CardDeck.pool(for: trebleOnly)

  #expect(!pool.isEmpty)
  #expect(pool.allSatisfy { $0.clef == .treble })
}

/// README › Progressão — rule 7: a level with two sections produces both clefs.
@Test func mixedLevelPoolContainsBothClefs() {
  let pool = CardDeck.pool(for: mixed)

  #expect(pool.contains { $0.clef == .treble })
  #expect(pool.contains { $0.clef == .bass })
}

/// Levels never produce black keys, matching rule 6.
@Test func levelPoolExcludesBlackKeys() {
  #expect(CardDeck.pool(for: mixed).allSatisfy { !$0.pitch.requiresSharp })
}

/// The same pitch in two clefs is two different cards, because it is read from
/// two different places on the staff.
@Test func middleCAppearsOnceForEachClefInAMixedLevel() {
  let middleCCards = CardDeck.pool(for: mixed).filter { $0.pitch == Pitch(60) }

  #expect(middleCCards.count == 2)
  #expect(Set(middleCCards.map(\.clef)).count == 2)
}

/// A level deck holds exactly the number of cards asked for.
@Test func levelDeckHoldsTheRequestedNumberOfCards() {
  var generator = FixedGenerator(seed: 7)

  let deck = CardDeck.build(level: mixed, count: 12, using: &generator)

  #expect(deck.count == 12)
}

/// Over a full round, a mixed level really does deal both clefs.
@Test func mixedLevelDeckDealsBothClefs() {
  var generator = FixedGenerator(seed: 11)

  let deck = CardDeck.build(level: mixed, count: 20, using: &generator)

  #expect(deck.contains { $0.clef == .treble })
  #expect(deck.contains { $0.clef == .bass })
}

/// A single-clef level deck never sneaks in the other clef.
@Test func singleClefLevelDeckStaysInOneClef() {
  var generator = FixedGenerator(seed: 13)

  let deck = CardDeck.build(level: trebleOnly, count: 20, using: &generator)

  #expect(deck.allSatisfy { $0.clef == .treble })
}

/// The same seed produces the same level deck.
@Test func sameSeedProducesTheSameLevelDeck() {
  var first = FixedGenerator(seed: 99)
  var second = FixedGenerator(seed: 99)

  let deckA = CardDeck.build(level: mixed, count: 12, using: &first)
  let deckB = CardDeck.build(level: mixed, count: 12, using: &second)

  #expect(deckA == deckB)
}

/// A level with no sections yields an empty deck rather than looping forever.
@Test func emptyLevelYieldsAnEmptyDeck() {
  var generator = FixedGenerator(seed: 17)

  let deck = CardDeck.build(level: QuizLevel(sections: []), count: 5, using: &generator)

  #expect(deck.isEmpty)
}

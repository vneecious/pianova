import ScoreModel
import Testing

@testable import NoteQuiz

/// Deterministic randomness, so deck tests do not flake.
private struct MixGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private let plainLevel = QuizLevel(sections: [.init(clef: .treble, range: 64...77)])
private let mixedLevel = QuizLevel(
  sections: [.init(clef: .treble, range: 60...77)],
  includesReversedCards: true)

/// A level without reversed cards deals none.
@Test func plainLevelDealsOnlyNamingCards() {
  var generator = MixGenerator(seed: 21)

  let deck = CardDeck.build(level: plainLevel, count: 12, using: &generator)

  #expect(deck.allSatisfy { $0.direction == .nameTheNote })
}

/// README › Cards invertidos — rule 14: one third of the round is reversed.
@Test func mixedLevelDealsOneThirdReversed() {
  var generator = MixGenerator(seed: 22)

  let deck = CardDeck.build(level: mixedLevel, count: 12, using: &generator)
  let reversed = deck.filter { $0.direction == .placeTheNote }

  #expect(reversed.count == 4)
  #expect(deck.count == 12)
}

/// Rounding down means reversed cards never outnumber direct ones, even in a
/// very short round.
@Test func reversedCardsNeverOutnumberDirectOnes() {
  let generator = MixGenerator(seed: 23)

  for count in 1...15 {
    var local = generator
    let deck = CardDeck.build(level: mixedLevel, count: count, using: &local)
    let reversed = deck.filter { $0.direction == .placeTheNote }.count

    #expect(reversed <= count - reversed)
  }
}

/// Reversing a card does not change which pitch it is about.
@Test func reversedCardsKeepValidPitches() {
  var generator = MixGenerator(seed: 24)

  let deck = CardDeck.build(level: mixedLevel, count: 12, using: &generator)
  let pool = Set(CardDeck.pool(for: mixedLevel).map(\.pitch))

  #expect(deck.allSatisfy { pool.contains($0.pitch) })
}

/// The same seed produces the same mix.
@Test func sameSeedProducesTheSameMix() {
  var first = MixGenerator(seed: 25)
  var second = MixGenerator(seed: 25)

  let deckA = CardDeck.build(level: mixedLevel, count: 12, using: &first)
  let deckB = CardDeck.build(level: mixedLevel, count: 12, using: &second)

  #expect(deckA == deckB)
}

/// Marking keeps the deck in the order it was given.
@Test func markingReversedKeepsTheOrder() {
  let cards = [60, 62, 64, 65, 67, 69]
    .map {
      NoteCard(pitch: Pitch(UInt8($0)), clef: .treble)
    }

  let marked = CardDeck.markingReversed(cards)

  #expect(marked.map(\.pitch) == cards.map(\.pitch))
}

/// One card in three is reversed.
@Test func markingReversedFlipsOneInThree() {
  let cards = (0..<9).map { NoteCard(pitch: Pitch(UInt8(60 + $0)), clef: .treble) }

  let reversed = CardDeck.markingReversed(cards).filter { $0.direction == .placeTheNote }

  #expect(reversed.count == 3)
}

/// The first card is never the reversed one.
@Test func aRoundNeverOpensOnAReversedCard() {
  let cards = (0..<9).map { NoteCard(pitch: Pitch(UInt8(60 + $0)), clef: .treble) }

  #expect(CardDeck.markingReversed(cards).first?.direction == .nameTheNote)
}

/// An interval of one would reverse everything, so it is refused.
@Test func aDegenerateIntervalChangesNothing() {
  let cards = [NoteCard(pitch: Pitch(60), clef: .treble)]

  #expect(CardDeck.markingReversed(cards, interval: 1) == cards)
}

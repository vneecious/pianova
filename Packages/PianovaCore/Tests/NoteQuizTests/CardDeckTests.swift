import ScoreModel
import Testing

@testable import NoteQuiz

/// Deterministic randomness, so deck tests do not flake.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

/// An octave of white keys from middle C is exactly the C major scale.
@Test func naturalPitchesCoverTheWhiteKeys() {
  let pitches = CardDeck.naturalPitches(in: 60...72)

  #expect(pitches.map(\.midiNoteNumber) == [60, 62, 64, 65, 67, 69, 71, 72])
}

/// Black keys never appear in a deck.
@Test func naturalPitchesExcludeBlackKeys() {
  let pitches = CardDeck.naturalPitches(in: 60...72)

  #expect(pitches.allSatisfy { !$0.requiresSharp })
}

/// A deck holds exactly the number of cards asked for.
@Test func deckHoldsTheRequestedNumberOfCards() {
  var generator = SeededGenerator(seed: 1)

  let deck = CardDeck.build(
    pitches: CardDeck.naturalPitches(in: 60...72), clef: .treble, count: 5,
    using: &generator)

  #expect(deck.count == 5)
}

/// Asking for more cards than there are pitches repeats them instead of
/// returning a short deck.
@Test func deckRepeatsPitchesWhenMoreCardsAreRequested() {
  var generator = SeededGenerator(seed: 2)

  let deck = CardDeck.build(
    pitches: [Pitch(60), Pitch(62)], clef: .treble, count: 6,
    using: &generator)

  #expect(deck.count == 6)
}

/// Every card in a deck uses the clef it was built for.
@Test func everyCardUsesTheRequestedClef() {
  var generator = SeededGenerator(seed: 3)

  let deck = CardDeck.build(
    pitches: CardDeck.naturalPitches(in: 43...57), clef: .bass, count: 8,
    using: &generator)

  #expect(deck.allSatisfy { $0.clef == .bass })
}

/// The same seed produces the same deck, which is what makes these tests
/// meaningful in the first place.
@Test func sameSeedProducesTheSameDeck() {
  var first = SeededGenerator(seed: 42)
  var second = SeededGenerator(seed: 42)
  let pitches = CardDeck.naturalPitches(in: 60...72)

  let deckA = CardDeck.build(pitches: pitches, clef: .treble, count: 8, using: &first)
  let deckB = CardDeck.build(pitches: pitches, clef: .treble, count: 8, using: &second)

  #expect(deckA == deckB)
}

/// An empty pitch list yields an empty deck rather than looping forever.
@Test func emptyPitchListYieldsAnEmptyDeck() {
  var generator = SeededGenerator(seed: 4)

  let deck = CardDeck.build(pitches: [], clef: .treble, count: 5, using: &generator)

  #expect(deck.isEmpty)
}

import ScoreModel

/// Builds decks of cards.
public enum CardDeck {
  /// One card in this many is reversed, on levels that include them.
  ///
  /// Rounding down keeps reversed cards from ever outnumbering direct ones.
  public static let reversedCardInterval = 3

  /// White-key pitches inside a range, ascending.
  ///
  /// Black keys are left out because naming them is a different skill, covered
  /// by README › Modo cards rule 6.
  /// - Parameter range: The MIDI note range to draw from, inclusive.
  /// - Returns: The natural pitches in the range, low to high.
  public static func naturalPitches(in range: ClosedRange<UInt8>) -> [Pitch] {
    range.map(Pitch.init).filter { !$0.requiresSharp }
  }

  /// Every card a level can produce, one per pitch per section.
  ///
  /// The same pitch in two clefs is two different cards, because it is read
  /// from two different places on the staff.
  /// - Parameter level: The level to draw from.
  /// - Returns: The full pool, in section then pitch order.
  public static func pool(for level: QuizLevel) -> [NoteCard] {
    level.sections.flatMap { section in
      naturalPitches(in: section.range).map { NoteCard(pitch: $0, clef: section.clef) }
    }
  }

  /// Builds a shuffled deck for a level, mixing its clefs when it has more
  /// than one section.
  /// - Parameters:
  ///   - level: The level to draw from.
  ///   - count: How many cards the deck should hold.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: The deck, in the order it should be presented.
  public static func build<G: RandomNumberGenerator>(
    level: QuizLevel,
    count: Int,
    using generator: inout G
  ) -> [NoteCard] {
    var cards = draw(from: pool(for: level), count: count, using: &generator)

    // Rule 14: from level two on, a third of the round asks for the position
    // instead of the name.
    guard level.includesReversedCards else { return cards }
    let reversedCount = cards.count / reversedCardInterval
    guard reversedCount > 0 else { return cards }

    let positions = Array(cards.indices).shuffled(using: &generator).prefix(reversedCount)
    for position in positions {
      cards[position] = cards[position].asking(.placeTheNote)
    }

    return cards
  }

  /// Builds a shuffled deck, repeating pitches when more cards are asked for
  /// than there are pitches available.
  /// - Parameters:
  ///   - pitches: The pitches to draw from.
  ///   - clef: The clef every card is drawn in.
  ///   - count: How many cards the deck should hold.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: The deck, in the order it should be presented.
  public static func build<G: RandomNumberGenerator>(
    pitches: [Pitch],
    clef: Clef,
    count: Int,
    using generator: inout G
  ) -> [NoteCard] {
    draw(
      from: pitches.map { NoteCard(pitch: $0, clef: clef) },
      count: count,
      using: &generator)
  }

  /// Marks every nth card as a placement card, keeping the given order.
  ///
  /// Used when the deck order is chosen by what the player keeps missing: the
  /// order must survive, so the reversal cannot shuffle.
  /// - Parameters:
  ///   - cards: The deck, in the order it will be shown.
  ///   - interval: One card in this many is reversed.
  /// - Returns: The same deck with some cards flipped.
  public static func markingReversed(
    _ cards: [NoteCard], interval: Int = reversedCardInterval
  ) -> [NoteCard] {
    guard interval > 1 else { return cards }

    return cards.enumerated()
      .map { index, card in
        // Offset by one so the first card is always a plain one: opening a round
        // on the harder direction reads as a jump.
        (index + 1) % interval == 0 ? card.asking(.placeTheNote) : card
      }
  }

  /// Draws cards from a bag that refills once empty.
  ///
  /// Every card appears once before any repeats, which spreads practice more
  /// evenly than picking at random each time.
  private static func draw<G: RandomNumberGenerator>(
    from pool: [NoteCard],
    count: Int,
    using generator: inout G
  ) -> [NoteCard] {
    guard !pool.isEmpty, count > 0 else { return [] }

    var cards: [NoteCard] = []
    cards.reserveCapacity(count)

    var bag: [NoteCard] = []
    while cards.count < count {
      if bag.isEmpty {
        bag = pool.shuffled(using: &generator)
      }
      cards.append(bag.removeLast())
    }

    return cards
  }
}

import ScoreModel

/// Which way a card is asked.
public enum CardDirection: Equatable, Sendable {
  /// Shows the note on the staff and asks for its name.
  case nameTheNote
  /// Shows the name and asks where the note sits on the staff.
  case placeTheNote

  /// Plays the note and asks for its name, with nothing written on screen.
  ///
  /// The ear is the one link the staff cannot train: reading teaches what a
  /// note looks like, never what it sounds like.
  case hearTheNote
}

/// An answer given to a card.
public enum QuizAnswer: Equatable, Sendable {
  /// A note name, for a card asked the `nameTheNote` way.
  case letter(NoteLetter)
  /// A position on the staff, in half-spaces above the bottom line.
  case staffStep(Int)
}

/// One card: a pitch on a staff, asked in one of the two directions.
public struct NoteCard: Equatable, Sendable {
  /// The pitch the card is about.
  public let pitch: Pitch

  /// The clef it is read in.
  public let clef: Clef

  /// Which way the card is asked.
  public let direction: CardDirection

  /// Creates a card.
  /// - Parameters:
  ///   - pitch: The pitch the card is about.
  ///   - clef: The clef it is read in.
  ///   - direction: Which way the card is asked.
  public init(pitch: Pitch, clef: Clef, direction: CardDirection = .nameTheNote) {
    self.pitch = pitch
    self.clef = clef
    self.direction = direction
  }

  /// The same card, asked the other way round.
  /// - Parameter direction: The direction to ask it in.
  /// - Returns: A copy asked that way.
  public func asking(_ direction: CardDirection) -> NoteCard {
    NoteCard(pitch: pitch, clef: clef, direction: direction)
  }

  /// The answer that solves this card.
  ///
  /// Rule 13: a placement card wants one specific position, so the expected
  /// answer carries the step, not just the letter.
  public var expectedAnswer: QuizAnswer {
    switch direction {
    case .nameTheNote, .hearTheNote:
      return .letter(pitch.letter)
    case .placeTheNote:
      return .staffStep(pitch.staffStep(in: clef))
    }
  }

  /// Whether an answer solves this card.
  ///
  /// An answer of the wrong shape never solves a card: naming a card that asked
  /// for a position is simply wrong.
  /// - Parameter answer: The answer given.
  /// - Returns: `true` when it is right.
  public func accepts(_ answer: QuizAnswer) -> Bool {
    answer == expectedAnswer
  }
}

/// What an answer did to the round.
public enum AnswerOutcome: Equatable, Sendable {
  /// Right answer; the next card is up.
  case correct
  /// Wrong answer; the card goes to the back of the queue.
  case wrong(expected: QuizAnswer)
  /// Right answer, and the queue is now empty.
  case finished
}

/// A round of cards.
///
/// See README › Modo cards for the rules it enforces.
public struct QuizSession {
  /// Cards still to be answered correctly, in order.
  public private(set) var queue: [NoteCard]

  /// How many cards were answered correctly.
  public private(set) var correctCount = 0

  /// How many wrong answers were given.
  public private(set) var mistakeCount = 0

  /// Creates a round from a deck.
  /// - Parameter cards: The cards to work through.
  public init(cards: [NoteCard]) {
    queue = cards
  }

  /// The card being asked, or `nil` when the round is over.
  public var currentCard: NoteCard? { queue.first }

  /// Whether every card has been answered correctly.
  public var isFinished: Bool { queue.isEmpty }

  /// How many cards remain in the queue.
  public var remainingCount: Int { queue.count }

  /// Answers the current card.
  /// - Parameter answer: The answer given.
  /// - Returns: What the answer did to the round.
  public mutating func answer(_ answer: QuizAnswer) -> AnswerOutcome {
    guard let card = queue.first else { return .finished }
    queue.removeFirst()

    // Rule 4: a missed card is postponed, never dropped, so rule 5 can only be
    // satisfied once every card has actually been answered correctly.
    guard card.accepts(answer) else {
      mistakeCount += 1
      queue.append(card)
      return .wrong(expected: card.expectedAnswer)
    }

    correctCount += 1
    return queue.isEmpty ? .finished : .correct
  }

  /// Answers the current card with a note name.
  /// - Parameter letter: The letter chosen.
  /// - Returns: What the answer did to the round.
  public mutating func answer(_ letter: NoteLetter) -> AnswerOutcome {
    answer(.letter(letter))
  }
}

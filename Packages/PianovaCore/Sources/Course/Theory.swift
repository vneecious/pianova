import ScoreModel

/// The four blocks the theory syllabus is built from.
///
/// The order is the one Med's *Introdução à Teoria da Música* uses: notation
/// first, then intervals, then scales, then chords. Each block only needs what
/// the ones before it established.
public enum TheoryTopic: String, CaseIterable, Sendable, Identifiable {
  /// Staff, clefs, note values, rests, bars.
  case notation
  /// Distance between two notes.
  case intervals
  /// Ordered successions of notes.
  case scales
  /// Notes sounding together.
  case chords

  /// Stable identity for `ForEach`.
  public var id: String { rawValue }

  /// The block letter, as the book numbers them.
  public var letter: String {
    switch self {
    case .notation: return "A"
    case .intervals: return "B"
    case .scales: return "C"
    case .chords: return "D"
    }
  }

  /// The block name shown to the player.
  public var title: String {
    switch self {
    case .notation: return "Notação musical"
    case .intervals: return "Intervalos"
    case .scales: return "Escalas"
    case .chords: return "Acordes"
    }
  }
}

/// One multiple-choice theory question.
public struct TheoryQuestion: Equatable, Sendable, Identifiable {
  /// Stable identifier, unique across the whole bank.
  public let id: String

  /// Which block it belongs to.
  public let topic: TheoryTopic

  /// Identifier of the teaching page that covers this question.
  ///
  /// A question may only be asked once that page has been read. Without this
  /// link a round could ask about note values right after a page on clefs.
  public let noteID: String

  /// The question itself.
  public let prompt: String

  /// A music glyph to show above the question, as a SMuFL code point.
  ///
  /// Empty when the question needs no symbol. Showing the real symbol beats
  /// describing it in words, which is half the point of learning notation.
  public let glyph: String

  /// The answers on offer, in the order they are shown.
  public let options: [String]

  /// Which option is right.
  public let correctIndex: Int

  /// One line on *why*, shown after answering.
  public let explanation: String

  /// Creates a question.
  /// - Parameters:
  ///   - id: Stable identifier, unique across the bank.
  ///   - topic: Which block it belongs to.
  ///   - noteID: The teaching page that covers it.
  ///   - prompt: The question itself.
  ///   - glyph: SMuFL code point to show, or empty for none.
  ///   - options: The answers on offer.
  ///   - correctIndex: Which option is right.
  ///   - explanation: One line on why.
  public init(
    id: String,
    topic: TheoryTopic,
    noteID: String,
    prompt: String,
    glyph: String = "",
    options: [String],
    correctIndex: Int,
    explanation: String
  ) {
    self.id = id
    self.topic = topic
    self.noteID = noteID
    self.prompt = prompt
    self.glyph = glyph
    self.options = options
    self.correctIndex = correctIndex
    self.explanation = explanation
  }

  /// The answer that is right.
  public var correctOption: String { options[correctIndex] }
}

/// What answering a theory question did to the round.
public enum TheoryOutcome: Equatable, Sendable {
  /// Right; the next question is up.
  case correct
  /// Wrong; the question goes to the back of the queue.
  case wrong(expected: String)
  /// Right, and the queue is now empty.
  case finished
}

/// A run of theory questions.
///
/// Same rule as the note cards: a missed question is postponed, never dropped,
/// so the round only ends once everything has been answered correctly.
public struct TheorySession {
  /// Questions still to be answered correctly, in order.
  public private(set) var queue: [TheoryQuestion]

  /// How many were answered correctly.
  public private(set) var correctCount = 0

  /// How many wrong answers were given.
  public private(set) var mistakeCount = 0

  /// Creates a round.
  /// - Parameter questions: The questions to work through.
  public init(questions: [TheoryQuestion]) {
    queue = questions
  }

  /// The question being asked, or `nil` once the round is over.
  public var currentQuestion: TheoryQuestion? { queue.first }

  /// Whether every question has been answered correctly.
  public var isFinished: Bool { queue.isEmpty }

  /// How many questions remain.
  public var remainingCount: Int { queue.count }

  /// Answers the current question.
  /// - Parameter index: Which option was chosen.
  /// - Returns: What the answer did to the round.
  public mutating func answer(_ index: Int) -> TheoryOutcome {
    guard let question = queue.first else { return .finished }
    queue.removeFirst()

    guard index == question.correctIndex else {
      mistakeCount += 1
      queue.append(question)
      return .wrong(expected: question.correctOption)
    }

    correctCount += 1
    return queue.isEmpty ? .finished : .correct
  }
}

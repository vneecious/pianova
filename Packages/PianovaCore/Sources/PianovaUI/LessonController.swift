import Course
import ExerciseEngine
import Foundation
import MIDIInput
import NoteQuiz
import Progress
import ScoreModel
import SwiftUI

/// Runs one lesson: its steps, in order, until they are all cleared.
@MainActor
public final class LessonController: ObservableObject {
  /// The lesson being taken.
  public let lesson: Lesson

  /// Which step is running.
  @Published public private(set) var stepIndex = 0

  /// Whether every step is done.
  @Published public private(set) var isFinished = false

  /// Creates a controller for a lesson.
  /// - Parameter lesson: The lesson to run.
  public init(lesson: Lesson) {
    self.lesson = lesson
  }

  /// The step running now, or `nil` once the lesson is over.
  public var currentStep: LessonStep? {
    guard lesson.steps.indices.contains(stepIndex) else { return nil }
    return lesson.steps[stepIndex]
  }

  /// How far through the lesson the player is, from 0 to 1.
  public var fraction: Double {
    guard !lesson.steps.isEmpty else { return 1 }
    return Double(stepIndex) / Double(lesson.steps.count)
  }

  /// Human count of the step, for the header.
  public var stepNumber: Int { min(stepIndex + 1, lesson.steps.count) }

  /// How many steps the lesson has.
  public var stepCount: Int { lesson.steps.count }

  /// Moves on to the next step, or finishes the lesson.
  public func completeStep() {
    guard stepIndex + 1 < lesson.steps.count else {
      isFinished = true
      return
    }
    stepIndex += 1
  }
}

/// Runs one deck of cards, reporting when it is cleared.
@MainActor
public final class CardRoundController: ObservableObject {
  /// A wrong answer held on screen so the right one can be shown beside it.
  public struct Reveal: Equatable {
    /// The card that was missed.
    public let card: NoteCard
    /// What the player answered.
    public let chosen: QuizAnswer
    /// What would have been right.
    public let expected: QuizAnswer
  }

  /// The round in progress.
  @Published public private(set) var session: QuizSession

  /// Set while a wrong answer is being shown; blocks further answers.
  @Published public private(set) var reveal: Reveal?

  /// Whether the last answer was right.
  @Published public private(set) var wasCorrect = false

  /// Called once the deck is cleared.
  public var onFinished: () -> Void = {}

  /// Called after every answer, so the review log can learn from it.
  public var onAnswered: (NoteCard, Bool) -> Void = { _, _ in }

  /// Creates a round.
  /// - Parameter cards: The deck to work through.
  public init(cards: [NoteCard]) {
    session = QuizSession(cards: cards)
  }

  /// How many cards are left.
  public var remainingCount: Int { session.remainingCount }

  /// Answers the current card.
  /// - Parameter answer: The answer given.
  public func answer(_ answer: QuizAnswer) {
    guard !session.isFinished, reveal == nil else { return }
    let card = session.currentCard

    switch session.answer(answer) {
    case .correct:
      wasCorrect = true
      if let card { onAnswered(card, true) }
    case .wrong(let expected):
      wasCorrect = false
      if let card {
        onAnswered(card, false)
        reveal = Reveal(card: card, chosen: answer, expected: expected)
      }
    case .finished:
      wasCorrect = true
      if let card { onAnswered(card, true) }
      onFinished()
    }
  }

  /// Dismisses the reveal and moves on.
  public func continueAfterReveal() {
    reveal = nil
  }
}

/// Runs one sequence to play on the instrument, reporting when it is cleared.
@MainActor
public final class PlayRoundController: ObservableObject {
  /// What the player should be told right now.
  public enum Status: Equatable {
    /// Nothing played yet.
    case waiting
    /// The last press cleared an item.
    case correct(Pitch)
    /// The last press was right but the chord is unfinished.
    case incomplete(Pitch)
    /// The last press was wrong.
    case mistake(played: Pitch, expected: String, movedBack: Bool)
    /// Every item is cleared.
    case finished
  }

  /// The run in progress.
  @Published public private(set) var session: ExerciseSession

  /// What the player should be told right now.
  @Published public private(set) var status: Status = .waiting

  /// The clef the sequence is written in.
  public let clef: Clef

  /// Title shown above the staff, when the sequence is a piece.
  public let title: String?

  /// Called once the sequence is cleared.
  public var onFinished: () -> Void = {}

  /// Creates a run.
  /// - Parameters:
  ///   - exercise: The sequence to play.
  ///   - clef: The clef it is written in.
  ///   - title: Title to show, when the sequence is a piece.
  public init(exercise: Exercise, clef: Clef, title: String? = nil) {
    session = ExerciseSession(exercise: exercise)
    self.clef = clef
    self.title = title
  }

  /// Visual state for each item, parallel to the exercise items.
  public var itemStates: [ItemState] {
    let failedIndex: Int? = {
      guard case .mistake = status else { return nil }
      return session.cursorIndex
    }()

    return session.exercise.items.indices.map { index in
      if index == failedIndex { return .failed }
      if index < session.cursorIndex { return .done }
      if index == session.cursorIndex { return .current }
      return .pending
    }
  }

  /// Plays a key from the on-screen keyboard.
  /// - Parameter pitch: The key that was pressed.
  public func playPitch(_ pitch: Pitch) {
    handle(.pressed(pitch, velocity: 80))
  }

  /// Applies one key event.
  /// - Parameter event: The event decoded from the instrument.
  public func handle(_ event: MIDIKeyEvent) {
    guard case .pressed(let pitch, _) = event, !session.isFinished else { return }

    let expected = session.currentItem
    let before = session.cursorIndex

    switch session.press(pitch, at: Date().timeIntervalSinceReferenceDate) {
    case .advanced:
      status = .correct(pitch)
    case .incomplete:
      status = .incomplete(pitch)
    case .wrong:
      let names =
        expected?.pitches.map(\.scientificName).sorted().joined(separator: " + ") ?? "?"
      status = .mistake(played: pitch, expected: names, movedBack: session.cursorIndex != before)
    case .finished:
      status = .finished
      onFinished()
    }
  }
}

/// Runs one round of theory questions, reporting when it is cleared.
@MainActor
public final class TheoryRoundController: ObservableObject {
  /// A wrong answer held on screen next to the right one.
  public struct Reveal: Equatable {
    /// The question that was answered.
    public let question: TheoryQuestion
    /// Which option was chosen.
    public let chosenIndex: Int
    /// Whether the choice was right.
    public let wasRight: Bool
    /// The line explaining why.
    public let explanation: String
  }

  /// The round in progress.
  @Published public private(set) var session: TheorySession

  /// Set while an answer is being shown; blocks further answers.
  @Published public private(set) var reveal: Reveal?

  /// Whether the last answer was right.
  @Published public private(set) var wasCorrect = false

  /// Called once the round is cleared.
  public var onFinished: () -> Void = {}

  /// Called after every answer, so the review log can learn from it.
  public var onAnswered: (TheoryQuestion, Bool) -> Void = { _, _ in }

  /// Creates a round.
  /// - Parameter questions: The questions to work through.
  public init(questions: [TheoryQuestion]) {
    session = TheorySession(questions: questions)
  }

  /// How many questions remain.
  public var remainingCount: Int { session.remainingCount }

  /// While revealing, the answered question stays on screen instead of the
  /// next one, so the explanation has something to point at.
  public var displayedQuestion: TheoryQuestion? {
    reveal?.question ?? session.currentQuestion
  }

  /// Answers the current question.
  /// - Parameter index: Which option was chosen.
  public func answer(_ index: Int) {
    guard !session.isFinished, reveal == nil else { return }
    guard let question = session.currentQuestion else { return }

    switch session.answer(index) {
    case .correct, .finished:
      wasCorrect = true
    case .wrong:
      wasCorrect = false
    }

    onAnswered(question, index == question.correctIndex)

    // Every answer is explained, right or wrong: the reason is the lesson.
    reveal = Reveal(
      question: question,
      chosenIndex: index,
      wasRight: index == question.correctIndex,
      explanation: question.explanation)
  }

  /// Dismisses the explanation and moves on.
  public func continueAfterReveal() {
    reveal = nil
    if session.isFinished {
      onFinished()
    }
  }
}

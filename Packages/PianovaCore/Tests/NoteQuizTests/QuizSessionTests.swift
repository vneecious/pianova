import ScoreModel
import Testing

@testable import NoteQuiz

private let middleC = NoteCard(pitch: Pitch(60), clef: .treble)
private let d4 = NoteCard(pitch: Pitch(62), clef: .treble)
private let e4 = NoteCard(pitch: Pitch(64), clef: .treble)

/// README › Modo cards — rule 3: a right answer moves straight to the next card.
@Test func correctAnswerAdvancesToTheNextCard() {
  var session = QuizSession(cards: [middleC, d4])

  let outcome = session.answer(.c)

  #expect(outcome == .correct)
  #expect(session.currentCard == d4)
  #expect(session.correctCount == 1)
}

/// README › Modo cards — rule 4: a wrong answer reveals the right one and sends
/// the card to the back of the queue.
@Test func wrongAnswerSendsTheCardToTheBackOfTheQueue() {
  var session = QuizSession(cards: [middleC, d4, e4])

  let outcome = session.answer(.g)

  #expect(outcome == .wrong(expected: .letter(.c)))
  #expect(session.currentCard == d4)
  #expect(session.queue.last == middleC)
  #expect(session.mistakeCount == 1)
}

/// README › Modo cards — rule 5: a missed card is postponed, never dropped, so
/// the round only ends once everything has been answered correctly.
@Test func missedCardMustStillBeAnsweredBeforeTheRoundEnds() {
  var session = QuizSession(cards: [middleC, d4])

  _ = session.answer(.g)  // middleC missed, goes to the back
  _ = session.answer(.d)  // d4 answered
  #expect(session.isFinished == false)
  #expect(session.currentCard == middleC)

  let last = session.answer(.c)

  #expect(last == .finished)
  #expect(session.isFinished)
}

/// README › Modo cards — rule 5: clearing the last card finishes the round.
@Test func answeringTheLastCardFinishesTheRound() {
  var session = QuizSession(cards: [middleC])

  let outcome = session.answer(.c)

  #expect(outcome == .finished)
  #expect(session.isFinished)
  #expect(session.currentCard == nil)
}

/// README › Modo cards — rule 6: an accidental does not change the answer.
@Test func sharpsAreAnsweredByTheirLetter() {
  var session = QuizSession(cards: [NoteCard(pitch: Pitch(61), clef: .treble)])

  let outcome = session.answer(.c)

  #expect(outcome == .finished)
}

/// A wrong answer on the only remaining card keeps the round going.
@Test func wrongAnswerOnTheOnlyCardKeepsItInPlay() {
  var session = QuizSession(cards: [middleC])

  let outcome = session.answer(.b)

  #expect(outcome == .wrong(expected: .letter(.c)))
  #expect(session.isFinished == false)
  #expect(session.currentCard == middleC)
}

/// Answering an empty round is harmless.
@Test func answeringAFinishedRoundDoesNothing() {
  var session = QuizSession(cards: [])

  let outcome = session.answer(.c)

  #expect(outcome == .finished)
  #expect(session.correctCount == 0)
}

/// Bass clef cards are named by the same letters, from different positions.
@Test func bassClefCardsUseTheSameLetters() {
  var session = QuizSession(cards: [NoteCard(pitch: Pitch(60), clef: .bass)])

  #expect(session.answer(.c) == .finished)
}

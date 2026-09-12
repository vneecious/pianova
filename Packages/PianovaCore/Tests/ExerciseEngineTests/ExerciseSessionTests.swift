import ScoreModel
import Testing

@testable import ExerciseEngine

private let c4 = Pitch(60)
private let d4 = Pitch(62)
private let e4 = Pitch(64)
private let g4 = Pitch(67)

/// Three single notes: C4, D4, E4.
private func threeNoteExercise() -> Exercise {
  Exercise(items: [ExerciseItem(c4), ExerciseItem(d4), ExerciseItem(e4)])
}

/// README › Modelo de interação — rule 1: the cursor marks exactly one item,
/// and starts on the first one.
@Test func cursorStartsAtFirstItem() {
  let session = ExerciseSession(exercise: threeNoteExercise())

  #expect(session.cursorIndex == 0)
  #expect(session.currentItem == ExerciseItem(c4))
  #expect(session.isFinished == false)
}

/// README › Modelo de interação — rule 2: a correct press advances the cursor
/// immediately, with no confirmation step.
@Test func correctPressAdvancesCursor() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  let outcome = session.press(c4, at: 0)

  #expect(outcome == .advanced)
  #expect(session.cursorIndex == 1)
  #expect(session.currentItem == ExerciseItem(d4))
}

/// README › Modelo de interação — rule 3: a chord item clears only once every
/// required pitch has been pressed.
@Test func chordAdvancesOnlyWhenEveryPitchIsPressed() {
  let chord = ExerciseItem(pitches: [c4, e4, g4])
  var session = ExerciseSession(exercise: Exercise(items: [chord]))

  let first = session.press(c4, at: 0)
  let second = session.press(e4, at: 0.01)
  let third = session.press(g4, at: 0.02)

  #expect(first == .incomplete)
  #expect(second == .incomplete)
  #expect(third == .finished)
  #expect(session.isFinished)
}

/// README › Modelo de interação — rule 3: presses spread wider than the
/// simultaneity window are not the same chord.
@Test func chordDoesNotClearWhenPressesAreTooFarApart() {
  let chord = ExerciseItem(pitches: [c4, e4])
  var session = ExerciseSession(
    exercise: Exercise(items: [chord]),
    simultaneityWindow: 0.08)

  let first = session.press(c4, at: 0)
  let late = session.press(e4, at: 5)

  #expect(first == .incomplete)
  #expect(late == .incomplete)
  #expect(session.cursorIndex == 0)
  #expect(session.isFinished == false)
}

/// README › Modelo de interação — rule 4: a press outside the current item is
/// an error, and the cursor stays put, waiting for the right note.
@Test func wrongPressKeepsTheCursorWhereItIs() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  let correct = session.press(c4, at: 0)
  let mistake = session.press(g4, at: 1)

  #expect(correct == .advanced)
  #expect(mistake == .wrong)
  #expect(session.cursorIndex == 1, "errar não perde o chão já conquistado")
  #expect(session.currentItem == ExerciseItem(d4))
}

/// Wrong presses are counted, so progression can use them.
@Test func wrongPressesAreCounted() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  _ = session.press(g4, at: 0)
  _ = session.press(g4, at: 1)
  _ = session.press(c4, at: 2)

  #expect(session.mistakeCount == 2)
}

/// A clean run counts no mistakes.
@Test func aCleanRunCountsNoMistakes() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  _ = session.press(c4, at: 0)
  _ = session.press(d4, at: 1)
  _ = session.press(e4, at: 2)

  #expect(session.mistakeCount == 0)
}

/// README › Modelo de interação — rule 5: an error on the very first item keeps
/// the cursor there, because there is no previous position.
@Test func cursorStaysAtStartWhenFirstItemIsWrong() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  let mistake = session.press(g4, at: 0)

  #expect(mistake == .wrong)
  #expect(session.cursorIndex == 0)
}

/// README › Modelo de interação — rule 6: an error carries no penalty.
///
/// Playing correctly afterwards advances exactly as it would have before.
@Test func errorCarriesNoPenalty() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  _ = session.press(c4, at: 0)
  let mistake = session.press(g4, at: 1)
  let retry = session.press(d4, at: 2)
  let third = session.press(e4, at: 3)

  #expect(mistake == .wrong)
  #expect(retry == .advanced, "a nota certa depois do erro avança como sempre")
  #expect(third == .finished)
}

/// Clearing the last item ends the exercise and leaves no current item.
@Test func clearingLastItemFinishesExercise() {
  var session = ExerciseSession(exercise: threeNoteExercise())

  _ = session.press(c4, at: 0)
  _ = session.press(d4, at: 1)
  let last = session.press(e4, at: 2)

  #expect(last == .finished)
  #expect(session.isFinished)
  #expect(session.currentItem == nil)
}

/// A partly built chord is discarded when a wrong note arrives, so the retry
/// starts from a clean slate.
@Test func partialChordIsDiscardedAfterWrongPress() {
  let chord = ExerciseItem(pitches: [c4, e4])
  var session = ExerciseSession(
    exercise: Exercise(items: [ExerciseItem(g4), chord]))

  _ = session.press(g4, at: 0)
  let partial = session.press(c4, at: 1)
  let mistake = session.press(d4, at: 1.01)
  let cursorAfterMistake = session.cursorIndex
  let cleanC = session.press(c4, at: 2)
  let cleanE = session.press(e4, at: 2.01)

  #expect(partial == .incomplete)
  #expect(mistake == .wrong)
  #expect(cursorAfterMistake == 1, "o acorde continua sendo o item atual")
  #expect(cleanC == .incomplete)
  #expect(cleanE == .finished, "a nova tentativa parte de lousa limpa")
}

import ScoreModel
import Testing

@testable import PianovaUI

// MARK: - Rule 105: segurar entra em modo de seleção

/// Rule 105 — antes de segurar num compasso, não há nada em estudo.
@MainActor @Test func nothingIsSelectedUntilSomethingIsHeld() {
  let session = StudySession()

  #expect(session.isSelecting == false)
  #expect(session.study.isWholePiece)
}

/// Rule 105 — segurar marca aquele compasso e abre a seleção.
@MainActor @Test func holdingABarBeginsTheSelection() {
  let session = StudySession()
  session.begin(at: 4)

  #expect(session.isSelecting)
  #expect(session.range == PracticeRange(first: 4, last: 4))
}

// MARK: - Rule 106: o trecho é contíguo

/// Rule 106 — marcado o 1 e tocado o 7, estudam-se os sete compassos.
@MainActor @Test func extendingReachesEveryBarInBetween() {
  let session = StudySession()
  session.begin(at: 1)
  session.extend(to: 7)

  #expect(session.range == PracticeRange(first: 1, last: 7))
}

/// Rule 106 — estender de novo move a outra ponta, sem largar a âncora.
///
/// Sem isso, cada toque viraria o começo de um trecho novo e não haveria como
/// ajustar o fim de um trecho já escolhido.
@MainActor @Test func extendingAgainKeepsTheAnchor() {
  let session = StudySession()
  session.begin(at: 3)
  session.extend(to: 9)
  session.extend(to: 5)

  #expect(session.range == PracticeRange(first: 3, last: 5))
}

/// Rule 106 — estender para trás da âncora é igualmente um trecho.
@MainActor @Test func aSelectionCanGrowBackwards() {
  let session = StudySession()
  session.begin(at: 8)
  session.extend(to: 2)

  #expect(session.range == PracticeRange(first: 2, last: 8))
}

/// Rule 107 — sem ter segurado antes, tocar não seleciona nada.
@MainActor @Test func tappingOutsideSelectionSelectsNothing() {
  let session = StudySession()
  session.extend(to: 5)

  #expect(session.isSelecting == false)
}

// MARK: - Rule 112: há sempre a volta para a peça inteira

/// Rule 112 — concluir devolve a peça inteira, com as duas mãos.
@MainActor @Test func finishingGivesTheWholePieceBack() {
  let session = StudySession()
  session.begin(at: 2)
  session.hands = .left
  session.finish()

  #expect(session.isSelecting == false)
  #expect(session.study.isWholePiece, "concluir volta também as duas mãos")
}

/// Rule 112 — concluído, segurar noutro compasso recomeça do zero.
@MainActor @Test func aNewHoldStartsAFreshSelection() {
  let session = StudySession()
  session.begin(at: 2)
  session.extend(to: 6)
  session.begin(at: 9)

  #expect(session.range == PracticeRange(first: 9, last: 9))
}

import ScoreModel
import Testing

@testable import PianovaUI

// MARK: - Rule 105: segurar entra em modo de seleção

/// Rule 105 — antes de segurar num compasso, navega-se a peça inteira.
@MainActor @Test func nothingIsSelectedUntilSomethingIsHeld() {
  let session = StudySession()

  #expect(session.phase == .browsing)
  #expect(session.study.isWholePiece)
}

/// Rule 105 — segurar marca aquele compasso e abre a seleção.
@MainActor @Test func holdingABarBeginsTheSelection() {
  let session = StudySession()
  session.begin(at: 4)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 4, last: 4))
}

// MARK: - Rule 106 e 108: o último toque fecha o trecho e entra no estudo

/// Rule 108 — tocar no último compasso do trecho entra direto no estudo.
///
/// É o gesto que o usuário descreveu: seguro no primeiro, toco no último, e a
/// tela fica só com o que eu escolhi. Sem botão de confirmar no meio.
@MainActor @Test func choosingTheLastBarEntersStudy() {
  let session = StudySession()
  session.begin(at: 1)
  session.choose(7)

  #expect(session.phase == .studying)
  #expect(session.range == PracticeRange(first: 1, last: 7))
}

/// Rule 106 — o trecho é contíguo: do 1 ao 7 vai tudo que há entre eles.
@MainActor @Test func theSelectionIsContiguous() {
  let session = StudySession()
  session.begin(at: 1)
  session.choose(7)

  let range = try! #require(session.range)
  #expect((1...7).allSatisfy(range.judges(bar:)))
}

/// Rule 106 — escolher para trás dá o mesmo trecho.
@MainActor @Test func aSelectionCanGrowBackwards() {
  let session = StudySession()
  session.begin(at: 8)
  session.choose(2)

  #expect(session.range == PracticeRange(first: 2, last: 8))
}

/// Tocar no próprio compasso segurado estuda só ele.
@MainActor @Test func choosingTheSameBarStudiesJustIt() {
  let session = StudySession()
  session.begin(at: 3)
  session.choose(3)

  #expect(session.phase == .studying)
  #expect(session.range == PracticeRange(first: 3, last: 3))
}

/// Rule 107 — sem ter segurado antes, tocar não seleciona nada.
@MainActor @Test func tappingOutsideSelectionSelectsNothing() {
  let session = StudySession()
  session.choose(5)

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

// MARK: - Rule 112: há sempre a volta

/// Rule 112 — cancelar a seleção volta a navegar, sem trecho nenhum.
@MainActor @Test func cancellingLeavesTheSelection() {
  let session = StudySession()
  session.begin(at: 2)
  session.finish()

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

/// Rule 112 — concluir o estudo devolve a peça inteira, com as duas mãos.
@MainActor @Test func finishingGivesTheWholePieceBack() {
  let session = StudySession()
  session.begin(at: 2)
  session.choose(4)
  session.hands = .left
  session.finish()

  #expect(session.phase == .browsing)
  #expect(session.study.isWholePiece, "concluir volta também as duas mãos")
}

/// Depois de concluir, segurar noutro compasso recomeça do zero.
@MainActor @Test func aNewHoldStartsAFreshSelection() {
  let session = StudySession()
  session.begin(at: 2)
  session.choose(6)
  session.finish()
  session.begin(at: 9)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 9, last: 9))
}

/// Segurar de novo no meio de um estudo também recomeça a escolha.
@MainActor @Test func holdingDuringStudyRestartsTheChoice() {
  let session = StudySession()
  session.begin(at: 1)
  session.choose(3)
  session.begin(at: 5)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 5, last: 5))
}

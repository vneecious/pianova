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

// MARK: - Rule 107: ajustar não confirma

/// Rule 107 — tocar noutro compasso estende a seleção e nada mais.
///
/// O toque que ajusta era o mesmo que confirmava, e um gesto de ajuste que
/// age é o que fazia a seleção parecer imprevisível.
@MainActor @Test func tappingAnotherBarOnlyExtends() {
  let session = StudySession()
  session.begin(at: 3)
  session.extend(to: 7)

  #expect(session.phase == .selecting, "estender não entra no estudo")
  #expect(session.range == PracticeRange(first: 3, last: 7))
}

/// Rule 106 — estender para trás dá o mesmo trecho contíguo.
@MainActor @Test func aSelectionCanGrowBackwards() {
  let session = StudySession()
  session.begin(at: 8)
  session.extend(to: 2)

  #expect(session.range == PracticeRange(first: 2, last: 8))
}

/// Rule 108 — tocar dentro do trecho não confirma nada: só o botão confirma.
///
/// Confirmar por toque parecia atalho e era armadilha — todo ajuste ficava a
/// um dedo de virar compromisso.
@MainActor @Test func tappingInsideConfirmsNothing() {
  let session = StudySession()
  session.begin(at: 2)
  session.extend(to: 6)
  session.tap(4)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 2, last: 6))
}

/// Rule 107 — o toque além do trecho estende, sem confirmar.
@MainActor @Test func aTapBeyondTheSelectionExtends() {
  let session = StudySession()
  session.begin(at: 3)
  session.tap(7)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 3, last: 7))
}

/// Rule 107 — tocar fora da pauta desfaz a seleção, como tocar fora do texto.
@MainActor @Test func aTapOffTheStavesDeselects() {
  let session = StudySession()
  session.begin(at: 3)
  session.extend(to: 5)
  session.tap(nil)

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

/// Fora da seleção, o toque não tem gramática nenhuma: nada acontece.
@MainActor @Test func aTapWhileBrowsingDoesNothing() {
  let session = StudySession()
  session.tap(4)

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

/// Rule 107 — arrastar uma alça redimensiona o trecho, para os dois lados.
@MainActor @Test func draggingAHandleResizesTheSelection() {
  let session = StudySession()
  session.begin(at: 3)
  session.extend(to: 9)
  session.resize(PracticeRange(first: 4, last: 6))

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 4, last: 6))
}

/// Rule 107 — sem ter segurado antes, nem toque nem alça fazem nada.
@MainActor @Test func adjustingOutsideSelectionDoesNothing() {
  let session = StudySession()
  session.extend(to: 5)
  session.resize(PracticeRange(first: 1, last: 2))

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

// MARK: - Rule 108: Estudar é a confirmação

/// Rule 108 — confirmar entra no estudo com o trecho como está.
@MainActor @Test func committingEntersStudy() {
  let session = StudySession()
  session.begin(at: 1)
  session.extend(to: 7)
  session.commit()

  #expect(session.phase == .studying)
  #expect(session.range == PracticeRange(first: 1, last: 7))
}

/// Rule 108 — um compasso só também se confirma.
@MainActor @Test func aSingleBarCanBeCommitted() {
  let session = StudySession()
  session.begin(at: 3)
  session.commit()

  #expect(session.phase == .studying)
  #expect(session.range == PracticeRange(first: 3, last: 3))
}

/// Confirmar sem seleção não inventa estudo nenhum.
@MainActor @Test func committingWhileBrowsingDoesNothing() {
  let session = StudySession()
  session.commit()

  #expect(session.phase == .browsing)
}

// MARK: - Rule 113: há sempre a volta

/// Rule 113 — cancelar a seleção volta a navegar, sem trecho nenhum.
@MainActor @Test func cancellingLeavesTheSelection() {
  let session = StudySession()
  session.begin(at: 2)
  session.finish()

  #expect(session.phase == .browsing)
  #expect(session.range == nil)
}

/// Rule 113 — concluir o estudo devolve a peça inteira, com as duas mãos.
@MainActor @Test func finishingGivesTheWholePieceBack() {
  let session = StudySession()
  session.begin(at: 2)
  session.extend(to: 4)
  session.commit()
  session.hands = .left
  session.finish()

  #expect(session.phase == .browsing)
  #expect(session.study.isWholePiece, "concluir volta também as duas mãos")
}

/// Segurar de novo, em qualquer fase, recomeça a escolha do zero.
@MainActor @Test func aNewHoldStartsAFreshSelection() {
  let session = StudySession()
  session.begin(at: 2)
  session.extend(to: 6)
  session.commit()
  session.begin(at: 9)

  #expect(session.phase == .selecting)
  #expect(session.range == PracticeRange(first: 9, last: 9))
}

// MARK: - Rule 111: repetir é coisa de trecho

/// Rule 111 — a peça inteira não repete: terminar é terminar.
///
/// O laço ligado fora do estudo era o que prendia a lição num loop eterno —
/// a peça acabava, recomeçava, e o passo nunca se dava por concluído.
@MainActor @Test func theWholePieceNeverLoops() {
  let session = StudySession()

  #expect(session.loops, "a preferência nasce ligada")
  #expect(session.loopsNow == false, "mas fora do estudo ela não vale")
}

/// Rule 111 — no estudo, o trecho repete sozinho.
@MainActor @Test func aPassageInStudyLoops() {
  let session = StudySession()
  session.begin(at: 2)
  session.commit()

  #expect(session.loopsNow)
}

/// Concluir o estudo desliga a repetição junto.
@MainActor @Test func finishingStopsTheLooping() {
  let session = StudySession()
  session.begin(at: 2)
  session.commit()
  session.finish()

  #expect(session.loopsNow == false)
}

import CoreGraphics
import ScoreModel
import Testing

@testable import PianovaUI

// MARK: - Rule 143: tocar numa nota escolhe o ponto de partida

/// Rule 143 — o toque numa nota leva o foco até a coluna dela.
@Test func tappingANoteFocusesItsColumn() {
  #expect(NoteFocus.afterTap(on: 12, current: 0) == 12)
  #expect(NoteFocus.afterTap(on: 12, current: 5) == 12)
}

/// Rule 143 — tocar na nota já focada devolve o início.
@Test func tappingTheFocusedNoteLetsItGo() {
  #expect(NoteFocus.afterTap(on: 12, current: 12) == 0)
}

/// Rule 143 — o toque só conta perto de uma nota: a margem não escolhe nada.
@Test func aTapOnlyCountsNearANote() {
  let boxes = [(id: "note-1", box: CGRect(x: 100, y: 100, width: 20, height: 16))]

  #expect(TapTarget.nearest(to: CGPoint(x: 115, y: 108), among: boxes) == "note-1")
  #expect(TapTarget.nearest(to: CGPoint(x: 140, y: 108), among: boxes) == "note-1")
  #expect(TapTarget.nearest(to: CGPoint(x: 400, y: 108), among: boxes) == nil)
}

/// Rule 143 — sem trecho em estudo, o julgamento começa na coluna focada:
/// o que vem antes não é pedido.
@Test func practiceBeginsAtTheFocusedColumn() {
  #expect(
    EngravedPlayController.isWithinPractice(column: 3, bar: 1, range: nil, startColumn: 5)
      == false)
  #expect(EngravedPlayController.isWithinPractice(column: 5, bar: 1, range: nil, startColumn: 5))
  #expect(EngravedPlayController.isWithinPractice(column: 9, bar: 2, range: nil, startColumn: 5))
}

/// Rule 143 — um trecho de estudo dispensa o foco: o trecho manda.
@Test func aStudyPassageOverrulesTheFocus() {
  let range = PracticeRange(first: 2, last: 3)

  #expect(
    EngravedPlayController.isWithinPractice(column: 9, bar: 2, range: range, startColumn: 99))
  #expect(
    EngravedPlayController.isWithinPractice(column: 1, bar: 1, range: range, startColumn: 0)
      == false)
}

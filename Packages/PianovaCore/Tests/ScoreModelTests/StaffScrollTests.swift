import CoreGraphics
import Testing

@testable import ScoreModel

/// A long piece in a narrow view: the case the screen actually hits.
private func longPiece(columns: Int = 26, width: CGFloat = 600) -> StaffLayout {
  StaffLayout(staffSpace: 18, width: width, columnCount: columns, scrolls: true)
}

// MARK: - Rule 38: notes keep a readable spacing

/// Rule 38 — twenty-six notes do not get squeezed into the screen width.
@Test func aLongPieceKeepsItsSpacing() {
  let layout = longPiece()

  #expect(layout.spacing >= StaffLayout.minimumSpacing * layout.staffSpace)
  #expect(layout.contentWidth > layout.noteAreaWidth, "a peça deveria transbordar a janela")
}

/// Rule 38 — the squeezing this replaced really was unreadable.
///
/// The same piece laid out to fit gives each note a fraction of a staff space,
/// which is where the note heads started overlapping.
@Test func fittingToWidthIsWhatWasUnreadable() {
  let fitted = StaffLayout(staffSpace: 18, width: 600, columnCount: 26)

  #expect(fitted.spacing < StaffLayout.minimumSpacing * 18)
}

/// A short drill still fills the width, since it needs no scrolling.
@Test func aShortSequenceStillFillsTheWidth() {
  let layout = StaffLayout(staffSpace: 18, width: 600, columnCount: 6, scrolls: true)

  #expect(layout.contentWidth <= layout.noteAreaWidth + 0.001)
  #expect(layout.offset(focusing: 3) == 0, "não deveria rolar o que já cabe")
}

// MARK: - Rules 39 and 41: where the window sits

/// Rule 39 — the cursor is held left of centre, so most of what shows is ahead.
@Test func theCursorSitsLeftOfCentre() {
  #expect(StaffLayout.cursorAnchor < 0.5)
  #expect(StaffLayout.cursorAnchor > 0)
}

/// Rule 39 — a note in the middle of the piece is brought to the anchor.
@Test func aMiddleNoteIsBroughtToTheAnchor() {
  let layout = longPiece()
  let column = 13

  let onScreen = layout.spacing * (CGFloat(column) + 0.5) - layout.offset(focusing: column)

  #expect(abs(onScreen - layout.noteAreaWidth * StaffLayout.cursorAnchor) < 0.001)
}

/// Rule 41 — the music never scrolls before its first note.
@Test func scrollingStopsAtTheStart() {
  let layout = longPiece()

  #expect(layout.offset(focusing: 0) == 0)
  #expect(layout.offset(focusing: -5) == 0, "índice negativo não pode puxar para trás")
}

/// Rule 41 — and never past the point where the last note is in view.
@Test func scrollingStopsAtTheEnd() {
  let layout = longPiece()
  let furthest = layout.contentWidth - layout.noteAreaWidth

  #expect(layout.offset(focusing: 25) <= furthest + 0.001)
  #expect(layout.offset(focusing: 999) <= furthest + 0.001, "não pode passar do fim")
}

/// The window only ever moves forwards as the cursor advances.
@Test func theWindowNeverGoesBackwardsWhilePlayingForwards() {
  let layout = longPiece()

  var previous: CGFloat = -1
  for column in 0...26 {
    let offset = layout.offset(focusing: column)
    #expect(offset >= previous, "a janela recuou na coluna \(column)")
    previous = offset
  }
}

/// Every column of a long piece can be brought into view.
@Test func everyColumnCanBeReached() {
  let layout = longPiece()

  for column in 0..<26 {
    let onScreen = layout.spacing * (CGFloat(column) + 0.5) - layout.offset(focusing: column)
    #expect(onScreen >= 0, "coluna \(column) fica à esquerda da janela")
    #expect(onScreen <= layout.noteAreaWidth, "coluna \(column) fica à direita da janela")
  }
}

// MARK: - Rule 40: the preamble is not part of the scrolling

/// Rule 40 — the note area starts after the clef and the signatures, so the
/// music has somewhere to scroll under without covering them.
@Test func theNoteAreaStartsAfterThePreamble() {
  let plain = StaffLayout(staffSpace: 18, width: 600, columnCount: 8)
  let signed = StaffLayout(staffSpace: 18, width: 600, columnCount: 8, preamble: 40)

  #expect(signed.noteAreaStart == plain.noteAreaStart + 40)
  #expect(signed.preambleStart < signed.noteAreaStart)
}

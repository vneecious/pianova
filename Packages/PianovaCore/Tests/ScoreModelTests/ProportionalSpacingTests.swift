import CoreGraphics
import Testing

@testable import ScoreModel

/// A bar of mixed figures: a semibreve, then two quavers.
private func mixed(width: CGFloat = 900) -> StaffLayout {
  StaffLayout(
    staffSpace: 18, width: width, columnCount: 3, scrolls: true,
    durations: [Duration(.whole), Duration(.eighth), Duration(.eighth)])
}

// MARK: - Rule 50: space is time

/// Rule 50 — a semibreve takes four times the room of a crotchet.
@Test func aWholeNoteIsFourTimesACrotchet() {
  let layout = StaffLayout(
    staffSpace: 18, width: 900, columnCount: 2, scrolls: true,
    durations: [Duration(.whole), Duration(.quarter)])

  #expect(abs(layout.width(ofColumn: 0) / layout.width(ofColumn: 1) - 4) < 0.001)
}

/// Rule 50 — a quaver takes half the room of a crotchet.
@Test func aQuaverIsHalfACrotchet() {
  let layout = StaffLayout(
    staffSpace: 18, width: 1800, columnCount: 2, scrolls: true,
    durations: [Duration(.quarter), Duration(.eighth)])

  #expect(abs(layout.width(ofColumn: 1) / layout.width(ofColumn: 0) - 0.5) < 0.001)
}

/// Rule 50 — a dotted figure takes half again, like it lasts.
@Test func aDottedFigureTakesHalfAgain() {
  let layout = StaffLayout(
    staffSpace: 18, width: 1800, columnCount: 2, scrolls: true,
    durations: [Duration(.half), Duration(.half, dotted: true)])

  #expect(abs(layout.width(ofColumn: 1) / layout.width(ofColumn: 0) - 1.5) < 0.001)
}

/// Rule 51 — proportional never means illegible.
@Test func shortNotesKeepAMinimumWidth() {
  let layout = mixed()

  #expect(layout.width(ofColumn: 1) > 0)
  #expect(layout.width(ofColumn: 1) >= StaffLayout.minimumSpacing * 18 * 0.5)
}

/// Columns follow one another with no gap and no overlap.
@Test func columnsTileWithoutGaps() {
  let layout = mixed()

  for column in 0..<3 {
    let expected = layout.start(ofColumn: column) + layout.width(ofColumn: column)
    #expect(abs(layout.start(ofColumn: column + 1) - expected) < 0.001)
  }

  #expect(abs(layout.contentWidth - layout.start(ofColumn: 3)) < 0.001)
}

/// A note sits in the middle of its own column, however wide that is.
@Test func aNoteIsCentredInItsOwnColumn() {
  let layout = mixed()

  for column in 0..<3 {
    let centre = layout.start(ofColumn: column) + layout.width(ofColumn: column) / 2
    #expect(abs(layout.x(ofColumn: column) - layout.noteAreaStart - centre) < 0.001)
  }
}

/// A drill with no written rhythm keeps equal columns.
@Test func aDrillWithoutRhythmKeepsEqualColumns() {
  let layout = StaffLayout(staffSpace: 18, width: 600, columnCount: 5, scrolls: true)

  #expect(layout.width(ofColumn: 0) == layout.width(ofColumn: 4))
}

// MARK: - Rule 52: the scroll glides

/// Rule 52 — a fractional focus lands between the two whole ones.
@Test func aHalfwayFocusSitsBetweenTheNotes() {
  let layout = StaffLayout(
    staffSpace: 18, width: 400, columnCount: 20, scrolls: true,
    durations: Array(repeating: Duration(.quarter), count: 20))

  let here = layout.offset(focusing: 8.0)
  let there = layout.offset(focusing: 9.0)
  let between = layout.offset(focusing: 8.5)

  #expect(between > here)
  #expect(between < there)
  #expect(abs(between - (here + there) / 2) < 0.001)
}

/// Rule 52 — the fractional and whole forms agree at whole numbers.
@Test func theFractionalOffsetAgreesAtWholeNumbers() {
  let layout = StaffLayout(
    staffSpace: 18, width: 400, columnCount: 20, scrolls: true,
    durations: Array(repeating: Duration(.quarter), count: 20))

  for column in 0...19 {
    #expect(abs(layout.offset(focusing: Double(column)) - layout.offset(focusing: column)) < 0.001)
  }
}

/// The glide is still clamped at the ends.
@Test func theGlideStopsAtTheEnds() {
  let layout = StaffLayout(
    staffSpace: 18, width: 400, columnCount: 20, scrolls: true,
    durations: Array(repeating: Duration(.quarter), count: 20))

  #expect(layout.offset(focusing: -0.5) == 0)
  #expect(layout.offset(focusing: 99.5) <= layout.contentWidth - layout.noteAreaWidth + 0.001)
}

/// The playhead crosses a long note slowly and a short one quickly, because
/// both take exactly as much space as they take time.
@Test func theGuideLineMovesAtTheSameScaleAsTheNotes() {
  let layout = mixed()

  let acrossWhole =
    layout.playheadX(column: 0, progress: 1) - layout.playheadX(column: 0, progress: 0)
  let acrossQuaver =
    layout.playheadX(column: 1, progress: 1) - layout.playheadX(column: 1, progress: 0)

  #expect(acrossWhole > acrossQuaver * 4, "a semibreve deveria levar muito mais espaço")
}

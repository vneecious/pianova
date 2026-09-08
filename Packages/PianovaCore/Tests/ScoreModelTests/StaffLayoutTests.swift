import CoreGraphics
import Testing

@testable import ScoreModel

private let layout = StaffLayout(staffSpace: 20, width: 800, columnCount: 4)

/// Notes start past the clef, never at the left edge.
///
/// This is exactly what a playhead drawn from the edge gets wrong.
@Test func notesStartPastTheClef() {
  #expect(layout.noteAreaStart > layout.clefX)
  #expect(layout.x(ofColumn: 0) > layout.noteAreaStart)
}

/// Columns are evenly spaced.
@Test func columnsAreEvenlySpaced() {
  let gaps = (0..<3).map { layout.x(ofColumn: $0 + 1) - layout.x(ofColumn: $0) }

  #expect(gaps.allSatisfy { abs($0 - layout.spacing) < 0.001 })
}

/// Every column fits inside the staff.
@Test func everyColumnFitsInsideTheStaff() {
  for column in 0..<layout.columnCount {
    #expect(layout.x(ofColumn: column) > 0)
    #expect(layout.x(ofColumn: column) < layout.width)
  }
}

/// At the start of a column the playhead is exactly on that note head.
///
/// The whole point: the line and the note it points at are the same place.
@Test func thePlayheadSitsOnTheNoteItPointsAt() {
  for column in 0..<layout.columnCount {
    #expect(
      abs(layout.playheadX(column: column, progress: 0) - layout.x(ofColumn: column)) < 0.001)
  }
}

/// Halfway through a column the playhead is halfway to the next note.
@Test func thePlayheadInterpolatesBetweenNotes() {
  let middle = layout.playheadX(column: 0, progress: 0.5)

  #expect(middle > layout.x(ofColumn: 0))
  #expect(middle < layout.x(ofColumn: 1))
  #expect(abs(middle - (layout.x(ofColumn: 0) + layout.spacing / 2)) < 0.001)
}

/// Fully through a column is the next note's position.
@Test func fullProgressReachesTheNextNote() {
  #expect(abs(layout.playheadX(column: 0, progress: 1) - layout.x(ofColumn: 1)) < 0.001)
}

/// The playhead never runs off either end of the staff.
@Test func thePlayheadIsClamped() {
  let end = layout.x(ofColumn: layout.columnCount)

  #expect(layout.playheadX(column: -5, progress: -2) == layout.x(ofColumn: 0))
  #expect(layout.playheadX(column: 99, progress: 5) == end)
  #expect(layout.playheadX(column: layout.columnCount - 1, progress: 1) == end)
}

/// A staff with no notes still has a sane note area.
@Test func anEmptyStaffStillHasANoteArea() {
  let empty = StaffLayout(staffSpace: 20, width: 800, columnCount: 0)

  #expect(empty.spacing == 0)
  #expect(empty.playheadX(column: 0, progress: 0) == empty.noteAreaStart)
}

/// A narrow staff does not produce negative space.
@Test func aNarrowStaffDoesNotGoNegative() {
  let narrow = StaffLayout(staffSpace: 20, width: 40, columnCount: 4)

  #expect(narrow.noteAreaWidth > 0)
  #expect(narrow.spacing > 0)
}

import CoreGraphics

/// Where the columns of a staff sit horizontally.
///
/// One source of truth for the across-the-page maths. A playhead drawn from its
/// own arithmetic will never line up with the note heads; drawing both from
/// here is what makes them agree.
public struct StaffLayout: Equatable, Sendable {
  /// Distance between two staff lines, in points.
  public let staffSpace: CGFloat

  /// Full width available to the staff.
  public let width: CGFloat

  /// How many columns of notes are drawn.
  public let columnCount: Int

  /// Creates a layout.
  /// - Parameters:
  ///   - staffSpace: Distance between two staff lines, in points.
  ///   - width: Full width available.
  ///   - columnCount: How many columns of notes are drawn.
  public init(staffSpace: CGFloat, width: CGFloat, columnCount: Int) {
    self.staffSpace = staffSpace
    self.width = width
    self.columnCount = max(columnCount, 0)
  }

  /// Where the clef is drawn.
  public var clefX: CGFloat { staffSpace * 0.6 }

  /// Left edge of the note area, past the clef.
  public var noteAreaStart: CGFloat { clefX + staffSpace * 4 }

  /// Width available to the notes.
  public var noteAreaWidth: CGFloat {
    max(width - noteAreaStart - staffSpace * 2, staffSpace)
  }

  /// Horizontal distance between two columns.
  public var spacing: CGFloat {
    columnCount > 0 ? noteAreaWidth / CGFloat(columnCount) : 0
  }

  /// Centre of one column.
  /// - Parameter column: Which column, counting from zero.
  /// - Returns: Its centre, in points from the left edge.
  public func x(ofColumn column: Int) -> CGFloat {
    noteAreaStart + spacing * (CGFloat(column) + 0.5)
  }

  /// Where a playhead sits when it is partway between two columns.
  ///
  /// Interpolating between column centres — rather than sweeping the whole
  /// width — is what keeps the line and the note heads in step.
  /// - Parameters:
  ///   - column: The column just reached.
  ///   - progress: How far towards the next one, from 0 to 1.
  /// - Returns: The playhead position, in points from the left edge.
  public func playheadX(column: Int, progress: Double) -> CGFloat {
    guard columnCount > 0 else { return noteAreaStart }

    let clampedColumn = min(max(column, 0), columnCount)
    let clampedProgress = min(max(progress, 0), 1)
    let position = x(ofColumn: clampedColumn) + spacing * CGFloat(clampedProgress)

    // Clamping the column and the progress separately is not enough: together
    // they can still push the line past the end of the staff.
    return min(position, x(ofColumn: columnCount))
  }
}

/// Where the moving guide line has reached.
///
/// Kept as a column and a fraction rather than a plain x: the staff already
/// knows how to turn columns into points, and a line drawn from its own
/// arithmetic never lines up with the note heads.
public struct PlayheadPosition: Equatable, Sendable {
  /// The column just reached.
  public let column: Int

  /// How far towards the next one, from 0 to 1.
  public let progress: Double

  /// Creates a position.
  /// - Parameters:
  ///   - column: The column just reached.
  ///   - progress: How far towards the next one, from 0 to 1.
  public init(column: Int, progress: Double) {
    self.column = column
    self.progress = progress
  }

  /// The same position seen from a system that starts partway through.
  /// - Parameter range: The columns that system holds.
  /// - Returns: The position in that system's own columns, or `nil` if the line
  ///   has not reached it or has already left.
  public func within(_ range: Range<Int>) -> PlayheadPosition? {
    guard range.contains(column) else { return nil }
    return PlayheadPosition(column: column - range.lowerBound, progress: progress)
  }
}

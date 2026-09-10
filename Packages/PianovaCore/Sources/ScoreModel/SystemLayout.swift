import CoreGraphics

/// Breaks a piece into systems: the stacked lines a printed score is read from.
///
/// A whole piece on one line that scrolls sideways is unreadable once it has a
/// few hundred notes, and it is not how anyone reads music. Paper breaks into
/// systems, and the break is what rests the eye and trains the real movement of
/// reading — left to right, then down.
public enum SystemLayout {
  /// Splits columns into systems that each fit the width available.
  ///
  /// Breaks land on bar lines. Breaking mid-bar is not a stylistic preference:
  /// a bar split across two lines cannot be counted, which is the one thing a
  /// beginner is there to do.
  /// - Parameters:
  ///   - widths: How wide each column wants to be, in points.
  ///   - barlinesAfter: Column indices a bar line follows.
  ///   - available: Width one system may occupy.
  /// - Returns: One range of column indices per system, in order.
  public static func systems(
    widths: [CGFloat],
    barlinesAfter: Set<Int>,
    available: CGFloat
  ) -> [Range<Int>] {
    guard !widths.isEmpty else { return [] }
    guard available > 0 else { return [0..<widths.count] }

    var systems: [Range<Int>] = []
    var start = 0

    while start < widths.count {
      var used: CGFloat = 0
      var end = start
      var lastBreak: Int?

      while end < widths.count {
        let next = used + widths[end]
        // The first column of a system always goes in, however wide it is:
        // otherwise a single very long note would make no progress at all.
        if next > available && end > start { break }

        used = next
        end += 1
        if barlinesAfter.contains(end - 1) { lastBreak = end }
      }

      // Prefer the last bar line that fits; fall back to filling the line when
      // no bar ends inside it, which happens with very long bars.
      let cut = (lastBreak ?? end) > start ? (lastBreak ?? end) : start + 1
      systems.append(start..<min(cut, widths.count))
      start = cut
    }

    return systems
  }
}

import CoreGraphics

/// The tap grammar of picking a starting note (rule 143).
///
/// Kept out of the views so it can be tested headlessly: touching SwiftUI
/// view metadata in tests brings the whole runner down.
enum NoteFocus {
  /// Where the focus lands after a tap on a note.
  ///
  /// A new note takes the focus; the focused note itself lets it go, back
  /// to the top of the piece.
  /// - Parameters:
  ///   - column: The column of the tapped note.
  ///   - current: The column currently focused, `0` for none.
  /// - Returns: The column to focus, `0` for the top.
  static func afterTap(on column: Int, current: Int) -> Int {
    column == current ? 0 : column
  }
}

/// Finds what a tap was aimed at, if it was aimed at anything (rule 143).
enum TapTarget {
  /// The identifier nearest to the point, when the point is near enough.
  ///
  /// The reach scales with the target: two and a half times its longer
  /// side, measured from its edge. Beyond that the tap is a tap on the
  /// page, not on a note — the margin never picks a starting point by
  /// accident.
  /// - Parameters:
  ///   - point: Where the tap landed, in page coordinates.
  ///   - boxes: Every tappable shape's identifier and bounding box.
  /// - Returns: The nearest identifier within reach, or `nil`.
  static func nearest(
    to point: CGPoint, among boxes: [(id: String, box: CGRect)]
  ) -> String? {
    var best: (id: String, distance: CGFloat, reach: CGFloat)?

    for (id, box) in boxes {
      guard box.width > 0 || box.height > 0 else { continue }
      let dx = max(box.minX - point.x, 0, point.x - box.maxX)
      let dy = max(box.minY - point.y, 0, point.y - box.maxY)
      let distance = dx * dx + dy * dy

      if distance < (best?.distance ?? .infinity) {
        let reach = 2.5 * max(box.width, box.height)
        best = (id, distance, reach * reach)
      }
    }

    guard let best, best.distance <= best.reach else { return nil }
    return best.id
  }
}

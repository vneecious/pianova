#if canImport(PencilKit)
import CoreGraphics
import PencilKit

/// Reprojects pencil strokes between the store and one engraved page.
///
/// Strokes are stored in page units, each hung on its bar (rule 131). Showing
/// them means mapping every stroke from the bar's box as it was onto the box
/// as it is, then into view points; saving means the reverse.
enum AnchoredAnnotations {
  /// The sentinel bar for strokes hung on one page itself.
  ///
  /// A note scribbled off the staves belongs to no bar; anchored to its page
  /// it scales with the page instead of vanishing. Negative so it never
  /// collides with a real bar — a pickup already answers to 0 — and one
  /// sentinel per page, so a margin note stays on its own page.
  /// - Parameter pageIndex: The page the stroke lives on.
  /// - Returns: The sentinel for that page.
  static func pageBar(_ pageIndex: Int) -> Int { -1 - pageIndex }

  /// Builds one page's drawing from the piece's anchored strokes.
  /// - Parameters:
  ///   - strokes: Every stroke of the piece.
  ///   - frameOfBar: The bar's box on this page, in page units — `nil` for a
  ///     bar living on another page.
  ///   - scale: Page units to view points.
  /// - Returns: PencilKit data for the canvas, in view points.
  static func compose(
    _ strokes: [AnnotationStore.AnchoredStroke],
    frameOfBar: (Int) -> CGRect?,
    scale: CGFloat
  ) -> Data? {
    var placed: [PKStroke] = []

    for anchored in strokes {
      guard let frame = frameOfBar(anchored.bar),
        let drawing = try? PKDrawing(data: anchored.stroke)
      else { continue }

      let map = AnnotationAnchor.transform(from: anchored.anchor, to: frame)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
      placed += drawing.strokes.map { stroke in
        var moved = stroke
        moved.transform = stroke.transform.concatenating(map)
        return moved
      }
    }

    guard !placed.isEmpty else { return nil }
    return PKDrawing(strokes: placed).dataRepresentation()
  }

  /// Splits one page's canvas back into anchored strokes.
  /// - Parameters:
  ///   - data: What PencilKit produced, in view points.
  ///   - scale: Page units to view points — the inverse is applied.
  ///   - barAt: The bar under a page point and its box, or `nil` off the music.
  /// - Returns: The page's strokes, each hung on its bar.
  static func decompose(
    _ data: Data,
    scale: CGFloat,
    barAt: (CGPoint) -> (bar: Int, frame: CGRect)?
  ) -> [AnnotationStore.AnchoredStroke] {
    guard scale > 0, let drawing = try? PKDrawing(data: data) else { return [] }

    return drawing.strokes.map { stroke in
      var onPage = stroke
      onPage.transform = stroke.transform.concatenating(
        CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))

      let bounds = onPage.renderBounds
      let anchor = barAt(CGPoint(x: bounds.midX, y: bounds.midY))

      return AnnotationStore.AnchoredStroke(
        bar: anchor?.bar ?? pageBar(0),
        anchor: anchor?.frame ?? .zero,
        stroke: PKDrawing(strokes: [onPage]).dataRepresentation())
    }
  }
}
#endif

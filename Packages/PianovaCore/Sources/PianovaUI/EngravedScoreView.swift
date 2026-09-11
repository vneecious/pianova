import Engraving
import ScoreModel
import SwiftUI

/// Draws an engraved page, with the notes being played picked out.
///
/// Everything here is `Canvas`: the engraver hands over outlines and this draws
/// them, so there is no web view and no JavaScript between a key being pressed
/// and the screen reacting.
struct EngravedScoreView: View {
  @Environment(\.colorScheme) private var colorScheme

  /// The page to draw.
  let page: EngravedPage

  /// Identifiers to pick out, and how each should read.
  let highlights: [String: ItemState]

  /// Called with the identifier nearest to a tap.
  var onTap: ((String) -> Void)?

  /// A bar to pick out, as an editor marks the one you clicked.
  var selectedMeasure: String?

  /// How wide to draw the page, in points.
  ///
  /// Given rather than measured, because the height has to be known by whatever
  /// lays this out. Deriving it from a fixed reference width instead — which is
  /// what happened before — makes the frame too short for the drawing, and the
  /// music is simply clipped away at the bottom.
  var width: CGFloat

  /// How tall the page is at the width it was given.
  private var height: CGFloat {
    width * page.size.height / max(page.size.width, 1)
  }

  var body: some View {
    let scale = width / max(page.size.width, 1)

    return Canvas { context, _ in
      context.scaleBy(x: scale, y: scale)

      // The selection sits under the music, the way an editor shades the bar
      // you clicked rather than covering it.
      if let selected = selectedMeasure, let box = page.measureFrame(selected) {
        let inset = box.insetBy(dx: -8, dy: -8)
        let shape = Path(roundedRect: inset, cornerRadius: 12)

        // Stronger on a dark page: the same wash that reads clearly on white
        // all but disappears on black, which is where it was being looked at.
        context.fill(
          shape,
          with: .color(ItemState.current.color.opacity(colorScheme == .dark ? 0.28 : 0.15)))
        context.stroke(
          shape,
          with: .color(ItemState.current.color.opacity(0.7)),
          lineWidth: 3)
      }

      for shape in page.shapes {
        let path = Path(shape.path)
        let colour = colour(for: shape)

        if shape.isFilled {
          context.fill(path, with: .color(colour))
        } else {
          context.stroke(path, with: .color(colour), lineWidth: shape.strokeWidth)
        }
      }
    }
    .frame(width: width, height: height)
    .contentShape(Rectangle())
    .onTapGesture { location in
      guard let onTap else { return }
      let point = CGPoint(x: location.x / scale, y: location.y / scale)
      if let id = nearest(to: point) { onTap(id) }
    }
  }

  /// The ink for one shape: its highlight if it has one, otherwise the page's.
  private func colour(for shape: EngravedShape) -> Color {
    // The note first: a stem and a flag have identifiers of their own, and
    // matching on those alone paints a note head and leaves the rest grey.
    if let note = shape.noteID, let state = highlights[note] { return state.color }
    if let id = shape.elementID, let state = highlights[id] { return state.color }

    return Color(PlatformColor.staffInk(colorScheme))
  }

  /// The element whose box is nearest a point, for tapping a passage.
  private func nearest(to point: CGPoint) -> String? {
    var best: (id: String, distance: CGFloat)?

    for shape in page.shapes {
      guard let id = shape.noteID ?? shape.elementID else { continue }
      let box = shape.path.boundingBoxOfPath
      guard box.width > 0 || box.height > 0 else { continue }

      let centre = CGPoint(x: box.midX, y: box.midY)
      let distance = hypot(centre.x - point.x, centre.y - point.y)
      if distance < (best?.distance ?? .greatestFiniteMagnitude) {
        best = (id, distance)
      }
    }

    return best?.id
  }
}

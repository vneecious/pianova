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

  var body: some View {
    GeometryReader { proxy in
      let scale = proxy.size.width / max(page.size.width, 1)

      Canvas { context, _ in
        context.scaleBy(x: scale, y: scale)

        // The selection sits under the music, the way an editor shades the bar
        // you clicked rather than covering it.
        if let selected = selectedMeasure, let box = page.measureFrame(selected) {
          let inset = box.insetBy(dx: -8, dy: -8)
          context.fill(
            Path(roundedRect: inset, cornerRadius: 12),
            with: .color(ItemState.current.color.opacity(0.13)))
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
      .frame(height: page.size.height * scale)
      .contentShape(Rectangle())
      .onTapGesture { location in
        guard let onTap else { return }
        let point = CGPoint(x: location.x / scale, y: location.y / scale)
        if let id = nearest(to: point) { onTap(id) }
      }
    }
    .frame(height: pageHeight)
  }

  /// How tall the page is once fitted to the width.
  ///
  /// Read from the page rather than guessed, so the container reserves exactly
  /// the room the music needs.
  private var pageHeight: CGFloat {
    page.size.height / max(page.size.width, 1) * 1_000
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

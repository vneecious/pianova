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

  /// Called through a hold, from press to lift.
  ///
  /// Reports the point in page coordinates at the press and at every movement
  /// after, with whether the gesture ended. Selection is born under the finger
  /// and grows with it, the way holding text does — lifting is not part of the
  /// job.
  var onHoldDrag: ((CGPoint, Bool) -> Void)?

  /// Called with a tap's point in page coordinates, after `onTap`.
  var onTapAt: ((CGPoint) -> Void)?

  /// Bars to pick out, as an editor marks what you selected.
  var selectedMeasures: Set<String> = []

  /// The selection's end frames, in page coordinates, for the grab handles.
  ///
  /// The way iOS marks a range of anything — text, a recording, a region:
  /// a handle at each end, dragged to adjust. Their presence is also what
  /// says "you are selecting", with no mode label to read.
  var leadingHandle: CGRect?
  var trailingHandle: CGRect?

  /// Called as a handle is dragged: the point in page coordinates, whether it
  /// is the leading handle, and whether the drag just ended.
  var onHandleDrag: ((CGPoint, Bool, Bool) -> Void)?

  /// The staff not being practised, drawn faded.
  ///
  /// Faded and not removed: the other hand is the reference for what this one
  /// has to fit into, and taking it away takes the reason for the passage.
  var quietStaff: Int?

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
      for selected in selectedMeasures {
        guard let box = page.measureFrame(selected) else { continue }
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
    .overlay { handles(scale: scale) }
    .contentShape(Rectangle())
    .onTapGesture { location in
      if let onTap, let id = element(at: location) { onTap(id) }
      onTapAt?(CGPoint(x: location.x / scale, y: location.y / scale))
    }
    // Held, not dragged: the press has to win before any movement, so a finger
    // that starts scrolling still scrolls instead of selecting a bar. Once it
    // wins, every movement reports — the selection lives under the finger.
    .gesture(
      LongPressGesture(minimumDuration: 0.35)
        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
        .onChanged { value in
          guard case .second(true, let drag?) = value else { return }
          onHoldDrag?(CGPoint(x: drag.location.x / scale, y: drag.location.y / scale), false)
        }
        .onEnded { value in
          guard case .second(true, let drag?) = value else { return }
          onHoldDrag?(CGPoint(x: drag.location.x / scale, y: drag.location.y / scale), true)
        }
    )
  }

  /// The grab handles at the selection's ends, draggable across bars.
  @ViewBuilder
  private func handles(scale: CGFloat) -> some View {
    if let leadingHandle {
      handle(over: leadingHandle, scale: scale, isLeading: true)
    }
    if let trailingHandle {
      handle(over: trailingHandle, scale: scale, isLeading: false)
    }
  }

  /// One handle: a stem with a knob, like the text-selection grab points.
  private func handle(over frame: CGRect, scale: CGFloat, isLeading: Bool) -> some View {
    let barHeight = frame.height * scale + 16
    let x = (isLeading ? frame.minX : frame.maxX) * scale
    let y = frame.midY * scale

    return ZStack {
      Capsule()
        .fill(Theme.accent)
        .frame(width: 3, height: barHeight)
      Circle()
        .fill(Theme.accent)
        .frame(width: 11, height: 11)
        .offset(y: (isLeading ? -1 : 1) * (barHeight / 2 + 4))
    }
    // A finger is not a cursor: the visible handle is thin, the touchable
    // area is not.
    .frame(width: 44, height: barHeight + 44)
    .contentShape(Rectangle())
    .position(x: x, y: y)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          onHandleDrag?(
            CGPoint(x: value.location.x / scale, y: value.location.y / scale),
            isLeading, false)
        }
        .onEnded { value in
          onHandleDrag?(
            CGPoint(x: value.location.x / scale, y: value.location.y / scale),
            isLeading, true)
        }
    )
  }

  /// The ink for one shape: its highlight if it has one, otherwise the page's.
  private func colour(for shape: EngravedShape) -> Color {
    // The note first: a stem and a flag have identifiers of their own, and
    // matching on those alone paints a note head and leaves the rest grey.
    if let note = shape.noteID, let state = highlights[note] { return state.color }
    if let id = shape.elementID, let state = highlights[id] { return state.color }

    let ink = Color(PlatformColor.staffInk(colorScheme))
    guard let quiet = quietStaff, shape.staffNumber == quiet else { return ink }

    return ink.opacity(0.22)
  }

  /// The element under a point on screen, in the page's own coordinates.
  private func element(at location: CGPoint) -> String? {
    let scale = width / max(page.size.width, 1)
    return nearest(to: CGPoint(x: location.x / scale, y: location.y / scale))
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

import Engraving
import ScoreModel
import SwiftUI

/// Draws an engraved page: the ink as a cached image, the life as paths.
///
/// The ink — thousands of paths — never changes while playing; what changes is
/// a handful of highlights, the selection, the handles. So the ink is a tinted
/// bitmap rendered once, and the canvas on top draws only what moved. Before
/// this split, every key press redrew the whole page, and on a long piece that
/// was the freeze.
struct EngravedScoreView: View {
  @Environment(\.colorScheme) private var colorScheme

  /// The page to draw.
  let page: EngravedPage

  /// The page's ink, rendered once — `nil` while it is still being drawn.
  var masks: InkRasterizer.Masks?

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

  /// The staff not being practised, whose ink is drawn faded.
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

    return ZStack(alignment: .topLeading) {
      inkLayer
      livingLayer(scale: scale)
    }
    .frame(width: width, height: height)
    .overlay { touches(scale: scale) }
    .overlay { handles(scale: scale) }
  }

  /// The gestures, read the way the system reads them.
  ///
  /// On the iPad the recognizer is the one text selection uses: the hold fires
  /// the moment it completes, where it happened, finger still down — and loses
  /// cleanly to the scroll when the finger scrolls. The Mac keeps SwiftUI's
  /// own gestures, which a pointer is patient enough for.
  @ViewBuilder
  private func touches(scale: CGFloat) -> some View {
    #if canImport(UIKit)
    TouchSurface(
      onTap: { location in
        if let onTap, let id = nearest(to: pagePoint(location, scale: scale)) { onTap(id) }
        onTapAt?(pagePoint(location, scale: scale))
      },
      onHold: { location, phase in
        onHoldDrag?(pagePoint(location, scale: scale), phase == .ended)
      },
      canHold: { location in !isNearAHandle(location, scale: scale) })
    #else
    Color.clear
      .contentShape(Rectangle())
      .onTapGesture { location in
        if let onTap, let id = nearest(to: pagePoint(location, scale: scale)) { onTap(id) }
        onTapAt?(pagePoint(location, scale: scale))
      }
      .gesture(
        LongPressGesture(minimumDuration: 0.3)
          .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
          .onChanged { value in
            guard case .second(true, .some(let drag)) = value else { return }
            onHoldDrag?(pagePoint(drag.location, scale: scale), false)
          }
          .onEnded { value in
            guard case .second(true, .some(let drag)) = value else { return }
            onHoldDrag?(pagePoint(drag.location, scale: scale), true)
          }
      )
    #endif
  }

  /// The ink itself: masks tinted in the page's color, rendered once.
  ///
  /// Equatable and compared by key, so a drag that changes the selection does
  /// not touch this subtree: rebuilding the mask composite re-uploads a
  /// texture the size of the page, per frame, and that was the drag's jank.
  private var inkLayer: some View {
    InkLayer(
      key: "\(page.id)|\(quietStaff ?? 0)",
      masks: masks,
      ink: Color(PlatformColor.staffInk(colorScheme)),
      width: width,
      height: height
    )
    .equatable()
  }

  /// Everything that moves: selection washes and highlighted notes.
  ///
  /// A handful of paths, so redrawing on every key press costs nothing — which
  /// is the entire point of the split.
  private func livingLayer(scale: CGFloat) -> some View {
    Canvas { context, _ in
      context.scaleBy(x: scale, y: scale)

      // The selection sits under the music, the way an editor shades the bar
      // you clicked rather than covering it.
      for selected in selectedMeasures {
        guard let box = page.measureFrames[selected] else { continue }
        let inset = box.insetBy(dx: -8, dy: -8)
        let shape = Path(roundedRect: inset, cornerRadius: 12)

        // Stronger on a dark page: the same wash that reads clearly on white
        // paper disappears into black.
        context.fill(
          shape,
          with: .color(ItemState.current.color.opacity(colorScheme == .dark ? 0.28 : 0.15)))
        context.stroke(
          shape,
          with: .color(ItemState.current.color.opacity(0.7)),
          lineWidth: 3)
      }

      for (id, state) in highlights {
        for index in page.ownersIndex[id] ?? [] {
          let shape = page.shapes[index]
          let path = Path(shape.path)

          if shape.isFilled {
            context.fill(path, with: .color(state.color))
          } else {
            context.stroke(path, with: .color(state.color), lineWidth: shape.strokeWidth)
          }
        }
      }
    }
    .frame(width: width, height: height)
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
          onHandleDrag?(pagePoint(value.location, scale: scale), isLeading, false)
        }
        .onEnded { value in
          onHandleDrag?(pagePoint(value.location, scale: scale), isLeading, true)
        }
    )
  }

  /// Whether a point sits on one of the selection handles.
  private func isNearAHandle(_ location: CGPoint, scale: CGFloat) -> Bool {
    let reach: CGFloat = 34

    for (frame, leading) in [(leadingHandle, true), (trailingHandle, false)] {
      guard let frame else { continue }
      let x = (leading ? frame.minX : frame.maxX) * scale
      let y = frame.midY * scale
      let half = (frame.height * scale + 16) / 2 + 22

      if abs(location.x - x) < reach && abs(location.y - y) < half { return true }
    }

    return false
  }

  /// A point on screen taken back into the page's own coordinates.
  private func pagePoint(_ location: CGPoint, scale: CGFloat) -> CGPoint {
    CGPoint(x: location.x / scale, y: location.y / scale)
  }

  /// The element whose box is nearest a point, for tapping a note.
  private func nearest(to point: CGPoint) -> String? {
    var best: (id: String, distance: CGFloat)?

    for shape in page.shapes {
      guard let id = shape.noteID ?? shape.elementID else { continue }
      let box = shape.path.boundingBoxOfPath
      guard box.width > 0 || box.height > 0 else { continue }

      let dx = max(box.minX - point.x, 0, point.x - box.maxX)
      let dy = max(box.minY - point.y, 0, point.y - box.maxY)
      let distance = dx * dx + dy * dy

      if distance < (best?.distance ?? .infinity) {
        best = (id, distance)
      }
    }

    return best?.id
  }
}

/// The tinted ink masks, isolated so nothing else re-renders them.
private struct InkLayer: View, Equatable {
  let key: String
  let masks: InkRasterizer.Masks?
  let ink: Color
  let width: CGFloat
  let height: CGFloat

  nonisolated static func == (left: InkLayer, right: InkLayer) -> Bool {
    left.key == right.key && left.width == right.width && left.ink == right.ink
      && (left.masks == nil) == (right.masks == nil)
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let masks {
        if let loud = masks.loud {
          ink.mask(alignment: .topLeading) { maskImage(loud) }
        }
        if let quiet = masks.quiet {
          ink.opacity(0.22).mask(alignment: .topLeading) { maskImage(quiet) }
        }
      }
    }
  }

  private func maskImage(_ image: CGImage) -> some View {
    Image(decorative: image, scale: 1)
      .resizable()
      .frame(width: width, height: height)
  }
}

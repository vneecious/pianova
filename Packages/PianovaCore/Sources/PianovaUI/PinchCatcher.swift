#if canImport(UIKit)
import SwiftUI
import UIKit

/// A real pinch, read the way GoodNotes reads it.
///
/// SwiftUI's magnification says how much but never where, and ignores the
/// two-finger pan that every pinch carries — which is why the lens felt
/// nothing like a page under the fingers. The recognizer rides the window,
/// like the page's other gestures: an ancestor receives the touches of every
/// view under it, canvas included, and this surface gates by its own bounds.
struct PinchCatcher: UIViewRepresentable {
  /// Called through the pinch: the scale, where it began, where the fingers
  /// are now — both in this view's coordinates — and whether it just ended.
  var onPinch: (CGFloat, CGPoint, CGPoint, Bool) -> Void

  func makeUIView(context: Context) -> TouchSurface.SurfaceView {
    let view = TouchSurface.SurfaceView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false

    let pinch = UIPinchGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.pinched))
    pinch.delegate = context.coordinator

    view.windowRecognizers = [pinch]
    context.coordinator.surface = view
    return view
  }

  func updateUIView(_ view: TouchSurface.SurfaceView, context: Context) {
    context.coordinator.onPinch = onPinch
    context.coordinator.surface = view
  }

  static func dismantleUIView(_ view: TouchSurface.SurfaceView, coordinator: Coordinator) {
    view.removeWindowRecognizers()
  }

  func makeCoordinator() -> Coordinator { Coordinator(onPinch: onPinch) }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onPinch: (CGFloat, CGPoint, CGPoint, Bool) -> Void
    weak var surface: TouchSurface.SurfaceView?
    private var start: CGPoint = .zero

    init(onPinch: @escaping (CGFloat, CGPoint, CGPoint, Bool) -> Void) {
      self.onPinch = onPinch
    }

    /// Fingers only, over this surface — the pencil never pinches.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
      guard touch.type != .pencil, let surface, surface.window != nil else { return false }
      return surface.bounds.contains(touch.location(in: surface))
    }

    /// The scroll pans with one finger while this zooms with two.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
      true
    }

    @objc func pinched(_ recognizer: UIPinchGestureRecognizer) {
      guard let surface else { return }
      let centre = recognizer.location(in: surface)

      switch recognizer.state {
      case .began:
        start = centre
        onPinch(recognizer.scale, start, centre, false)
      case .changed:
        onPinch(recognizer.scale, start, centre, false)
      case .ended, .cancelled, .failed:
        onPinch(recognizer.scale, start, centre, true)
      default:
        break
      }
    }
  }
}
#endif

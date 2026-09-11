#if canImport(UIKit)
import SwiftUI
import UIKit

/// The moments of a press-and-drag, as UIKit reports them.
enum HoldPhase {
  /// The press completed — finger still down.
  case began
  /// The finger moved while held.
  case moved
  /// The finger lifted, or the system took the touch away.
  case ended
}

/// A transparent surface that reads taps and holds the way the system does.
///
/// SwiftUI's long press cannot say where it happened, and sequencing it with a
/// drag reports nothing until the finger moves or lifts — which is why the
/// selection kept arriving late or not at all. `UILongPressGestureRecognizer`
/// is the recognizer text selection itself uses: it fires the moment the press
/// completes, with its location, keeps reporting as the finger moves, and
/// loses cleanly to the scroll view when the finger scrolls instead.
///
/// The recognizers ride the **window**, not this view: the pencil's canvas
/// sits above the page and hit-testing hands it every touch, so recognizers
/// attached here never fired — the selection died the day the pencil arrived.
/// A recognizer on an ancestor receives the touches of every view under it;
/// the window is the one sure ancestor. Each surface gates by its own bounds,
/// ignores the pencil — that one belongs to the canvas — and stays clear of
/// the selection handles, which drag with gestures of their own.
struct TouchSurface: UIViewRepresentable {
  /// Called with a tap's location, in this view's coordinates.
  var onTap: (CGPoint) -> Void

  /// Called through a hold: at the press, at every movement, at the lift.
  var onHold: (CGPoint, HoldPhase) -> Void

  /// Whether a gesture may begin here.
  ///
  /// The selection handles live above this surface with drags of their own,
  /// and a hold that began under a handle would tear the selection out from
  /// under the finger adjusting it.
  var canHold: (CGPoint) -> Bool = { _ in true }

  func makeUIView(context: Context) -> SurfaceView {
    let view = SurfaceView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false

    let tap = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.tapped))
    tap.cancelsTouchesInView = false
    tap.delegate = context.coordinator

    let hold = UILongPressGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.held))
    hold.minimumPressDuration = 0.3
    hold.delegate = context.coordinator

    view.windowRecognizers = [tap, hold]
    context.coordinator.surface = view
    return view
  }

  func updateUIView(_ view: SurfaceView, context: Context) {
    context.coordinator.onTap = onTap
    context.coordinator.onHold = onHold
    context.coordinator.canHold = canHold
    context.coordinator.surface = view
  }

  static func dismantleUIView(_ view: SurfaceView, coordinator: Coordinator) {
    view.removeWindowRecognizers()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onTap: onTap, onHold: onHold)
  }

  /// The page-sized view the gestures are measured against.
  ///
  /// It owns the recognizers but parks them on the window while it is on
  /// screen — see the type note above for why.
  final class SurfaceView: UIView {
    var windowRecognizers: [UIGestureRecognizer] = []

    override func didMoveToWindow() {
      super.didMoveToWindow()

      guard let window else {
        removeWindowRecognizers()
        return
      }
      for recognizer in windowRecognizers where recognizer.view !== window {
        recognizer.view?.removeGestureRecognizer(recognizer)
        window.addGestureRecognizer(recognizer)
      }
    }

    func removeWindowRecognizers() {
      for recognizer in windowRecognizers {
        recognizer.view?.removeGestureRecognizer(recognizer)
      }
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onTap: (CGPoint) -> Void
    var onHold: (CGPoint, HoldPhase) -> Void
    var canHold: (CGPoint) -> Bool = { _ in true }
    weak var surface: SurfaceView?

    init(onTap: @escaping (CGPoint) -> Void, onHold: @escaping (CGPoint, HoldPhase) -> Void) {
      self.onTap = onTap
      self.onHold = onHold
    }

    /// Only finger touches over this page, away from the handles.
    ///
    /// The pencil belongs to the annotation canvas; touches outside the page
    /// belong to whatever they landed on; touches near a handle belong to the
    /// handle's own drag.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
      guard touch.type != .pencil, let surface, surface.window != nil else { return false }
      let point = touch.location(in: surface)
      return surface.bounds.contains(point) && canHold(point)
    }

    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
      guard let surface else { return }
      onTap(recognizer.location(in: surface))
    }

    @objc func held(_ recognizer: UILongPressGestureRecognizer) {
      guard let surface else { return }
      let point = recognizer.location(in: surface)

      switch recognizer.state {
      case .began: onHold(point, .began)
      case .changed: onHold(point, .moved)
      case .ended, .cancelled, .failed: onHold(point, .ended)
      default: break
      }
    }
  }
}
#endif

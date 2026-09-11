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
struct TouchSurface: UIViewRepresentable {
  /// Called with a tap's location, in this view's coordinates.
  var onTap: (CGPoint) -> Void

  /// Called through a hold: at the press, at every movement, at the lift.
  var onHold: (CGPoint, HoldPhase) -> Void

  /// Whether a hold may begin here.
  ///
  /// The selection handles live above this surface with drags of their own,
  /// and a hold that began under a handle would tear the selection out from
  /// under the finger adjusting it.
  var canHold: (CGPoint) -> Bool = { _ in true }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear

    let tap = UITapGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.tapped))
    let hold = UILongPressGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.held))
    hold.minimumPressDuration = 0.3
    hold.delegate = context.coordinator

    view.addGestureRecognizer(tap)
    view.addGestureRecognizer(hold)
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    context.coordinator.onTap = onTap
    context.coordinator.onHold = onHold
    context.coordinator.canHold = canHold
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onTap: onTap, onHold: onHold)
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onTap: (CGPoint) -> Void
    var onHold: (CGPoint, HoldPhase) -> Void
    var canHold: (CGPoint) -> Bool = { _ in true }

    init(onTap: @escaping (CGPoint) -> Void, onHold: @escaping (CGPoint, HoldPhase) -> Void) {
      self.onTap = onTap
      self.onHold = onHold
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      recognizer is UITapGestureRecognizer || canHold(recognizer.location(in: recognizer.view))
    }

    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
      onTap(recognizer.location(in: recognizer.view))
    }

    @objc func held(_ recognizer: UILongPressGestureRecognizer) {
      let point = recognizer.location(in: recognizer.view)

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

#if canImport(UIKit)
import SwiftUI
import UIKit

/// Asks the zoomable scroll to go somewhere, from SwiftUI land.
///
/// A reference on purpose: the controller writes a request, the UIKit side
/// executes it, and none of it re-evaluates any body.
final class ZoomScrollHandle {
  /// The pending destination, in unzoomed content coordinates.
  var request: ((CGRect, Bool) -> Void)?

  /// Scrolls so a content rectangle's top is at the viewport's top.
  /// - Parameters:
  ///   - rect: Where to go, in unzoomed content coordinates.
  ///   - animated: Whether to glide.
  func scroll(to rect: CGRect, animated: Bool) {
    request?(rect, animated)
  }
}

/// The page under real hands: native scrolling and native zooming.
///
/// SwiftUI's scroll cannot zoom and its magnification cannot say where —
/// every emulation re-framed the page after the fingers left. This is the
/// real thing (rule 115): the zoom IS the scroll view's, so letting go
/// keeps the exact scale and the exact spot, with the native feel — pan
/// with momentum, rubber bands, two-finger everything.
struct ZoomableScroll<Content: View>: UIViewControllerRepresentable {
  /// The page stack to scroll and zoom.
  @ViewBuilder var content: Content

  /// The controller's way of scrolling to a system.
  let handle: ZoomScrollHandle

  func makeUIViewController(context: Context) -> Controller<Content> {
    let controller = Controller(rootView: content)
    handle.request = { [weak controller] rect, animated in
      controller?.scroll(to: rect, animated: animated)
    }
    return controller
  }

  func updateUIViewController(_ controller: Controller<Content>, context: Context) {
    controller.hosting.rootView = content
    handle.request = { [weak controller] rect, animated in
      controller?.scroll(to: rect, animated: animated)
    }
  }

  final class Controller<Root: View>: UIViewController, UIScrollViewDelegate {
    let scroll = UIScrollView()
    let hosting: UIHostingController<Root>

    init(rootView: Root) {
      hosting = UIHostingController(rootView: rootView)
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func viewDidLoad() {
      super.viewDidLoad()

      scroll.delegate = self
      scroll.minimumZoomScale = 1
      scroll.maximumZoomScale = 3
      scroll.bouncesZoom = true
      scroll.showsHorizontalScrollIndicator = false
      scroll.contentInsetAdjustmentBehavior = .never
      view.addSubview(scroll)
      scroll.translatesAutoresizingMaskIntoConstraints = false

      addChild(hosting)
      hosting.view.backgroundColor = .clear
      hosting.sizingOptions = .intrinsicContentSize
      scroll.addSubview(hosting.view)
      hosting.didMove(toParent: self)
      hosting.view.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        scroll.topAnchor.constraint(equalTo: view.topAnchor),
        scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

        hosting.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
        hosting.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
        hosting.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
        hosting.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),

        // The content is exactly the viewport wide at rest; zooming is what
        // makes it wider, and the scroll view handles that itself.
        hosting.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
      ])
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { hosting.view }

    /// Scrolls a content rectangle's top under the viewport's top.
    func scroll(to rect: CGRect, animated: Bool) {
      let zoom = scroll.zoomScale
      let target = CGPoint(
        x: min(
          max(rect.minX * zoom, 0),
          max(scroll.contentSize.width - scroll.bounds.width, 0)),
        y: min(
          max(rect.minY * zoom, 0),
          max(scroll.contentSize.height - scroll.bounds.height, 0)))
      scroll.setContentOffset(target, animated: animated)
    }
  }
}
#endif

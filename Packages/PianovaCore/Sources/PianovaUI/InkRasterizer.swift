import CoreGraphics
import Engraving
import Foundation

/// Draws a page's ink once, into bitmaps the screen can reuse.
///
/// The page used to be thousands of paths redrawn on every frame — every key
/// press, every tick of the preview, every step of an animation. The ink never
/// changes between those moments; what changes is a handful of highlights. So
/// the ink becomes an image, and the screen paints paths only for what moved.
public enum InkRasterizer {
  /// A page's ink, split by whether the staff is at rest.
  ///
  /// Alpha-only masks rather than colored images: the screen tints them, so a
  /// theme change needs no re-render — and a mask is a quarter the memory.
  public struct Masks: @unchecked Sendable {
    /// The staves being played.
    public let loud: CGImage?
    /// The staff at rest, drawn faded — empty when both hands are on.
    public let quiet: CGImage?
  }

  /// Renders one page's masks.
  ///
  /// Safe off the main thread: everything here is Core Graphics on local
  /// state.
  /// - Parameters:
  ///   - page: The page to draw.
  ///   - pixelWidth: How many pixels across, trading sharpness for memory.
  ///   - quietStaff: The staff at rest, split into its own mask, or `nil`.
  /// - Returns: The masks, as sharp as asked for.
  public static func masks(for page: EngravedPage, pixelWidth: Int, quietStaff: Int?) -> Masks {
    Masks(
      loud: render(page: page, pixelWidth: pixelWidth) { shape in
        quietStaff == nil || shape.staffNumber != quietStaff
      },
      quiet: quietStaff == nil
        ? nil
        : render(page: page, pixelWidth: pixelWidth) { $0.staffNumber == quietStaff })
  }

  /// Draws the shapes that pass a filter into an alpha-only bitmap.
  private static func render(
    page: EngravedPage, pixelWidth: Int, include: (EngravedShape) -> Bool
  ) -> CGImage? {
    let scale = CGFloat(pixelWidth) / max(page.size.width, 1)
    let pixelHeight = Int((page.size.height * scale).rounded(.up))
    guard pixelWidth > 0, pixelHeight > 0,
      let context = CGContext(
        data: nil, width: pixelWidth, height: pixelHeight,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
    else { return nil }

    // The page's coordinates grow downward; the bitmap's grow upward.
    context.translateBy(x: 0, y: CGFloat(pixelHeight))
    context.scaleBy(x: scale, y: -scale)
    context.setFillColor(gray: 0, alpha: 1)
    context.setStrokeColor(gray: 0, alpha: 1)

    var drewAnything = false
    for shape in page.shapes where include(shape) {
      drewAnything = true
      context.addPath(shape.path)

      if shape.isFilled {
        context.fillPath()
      } else {
        context.setLineWidth(shape.strokeWidth)
        context.strokePath()
      }
    }

    return drewAnything ? context.makeImage() : nil
  }
}

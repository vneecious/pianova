import CoreGraphics
import CoreText
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
  ///   - includeTexts: Whether written texts — fingering above all — are drawn.
  /// - Returns: The masks, as sharp as asked for.
  public static func masks(
    for page: EngravedPage, pixelWidth: Int, quietStaff: Int?, includeTexts: Bool = true
  ) -> Masks {
    Masks(
      loud: render(page: page, pixelWidth: pixelWidth, includeTexts: includeTexts) { staff in
        quietStaff == nil || staff != quietStaff
      },
      quiet: quietStaff == nil
        ? nil
        : render(page: page, pixelWidth: pixelWidth, includeTexts: includeTexts) {
          $0 == quietStaff
        })
  }

  /// Draws the shapes and texts whose staff passes a filter, alpha-only.
  private static func render(
    page: EngravedPage, pixelWidth: Int, includeTexts: Bool, include: (Int?) -> Bool
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
    for shape in page.shapes where include(shape.staffNumber) {
      drewAnything = true
      context.addPath(shape.path)

      if shape.isFilled {
        context.fillPath()
      } else {
        context.setLineWidth(shape.strokeWidth)
        // The octave line is dashed; drawn solid it reads as something else.
        context.setLineDash(phase: 0, lengths: shape.dashes)
        context.strokePath()
        if !shape.dashes.isEmpty { context.setLineDash(phase: 0, lengths: []) }
      }
    }

    // Text runs — fingering numbers, tempo words. The engraver writes them as
    // SVG text, and until the parser learned to read it every number was
    // dropped in silence.
    for run in page.texts where includeTexts && include(run.staffNumber) {
      drewAnything = true
      draw(run, in: context)
    }

    return drewAnything ? context.makeImage() : nil
  }

  /// Draws one run of text at its place on the page.
  private static func draw(_ run: EngravedText, in context: CGContext) {
    // Music-font runs — dynamics, the pedal sign — are SMuFL glyphs; a text
    // face would draw them as tofu. Bravura is already in the app for the
    // staff's own glyphs.
    let family = run.isMusicFont ? "Bravura" : "Times New Roman"
    let font = CTFontCreateWithName(family as CFString, run.fontSize, nil)
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(
        string: run.text,
        attributes: [
          kCTFontAttributeName as NSAttributedString.Key: font,
          kCTForegroundColorFromContextAttributeName as NSAttributedString.Key: true,
        ]))

    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    let startX = run.isCentered ? run.position.x - width / 2 : run.position.x

    // The page's coordinates grow downward and text draws upward, so each run
    // is drawn in its own small un-flipped world.
    context.saveGState()
    context.translateBy(x: startX, y: run.position.y)
    context.scaleBy(x: 1, y: -1)
    context.textPosition = .zero
    CTLineDraw(line, context)
    context.restoreGState()
  }
}

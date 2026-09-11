import CoreGraphics
import Foundation
import Testing

@testable import Engraving

/// A page as an engraver really emits it: glyphs defined once and placed by
/// reference, straight segments for stems, and an id on every note.
private let sample = """
  <svg width="2100px" height="2970px">
    <svg class="definition-scale" viewBox="0 0 21000 29700">
      <defs>
        <g id="E0A4-x">
          <path transform="scale(1,-1)" d="M0 0 L100 0 L100 60 L0 60 Z"/>
        </g>
      </defs>
      <g id="measure-1" class="measure">
        <g id="note-1" class="note">
          <g class="notehead">
            <use xlink:href="#E0A4-x" transform="translate(1000, 500) scale(0.5, 0.5)"/>
          </g>
          <g id="stem-1" class="stem">
            <path d="M1050 500 L1050 200" stroke-width="18"/>
          </g>
        </g>
      </g>
    </svg>
  </svg>
  """

private func parsedPage() -> EngravedPage? { EngravedPageParser.page(from: sample) }

/// The page reports the coordinate system the music was drawn in.
@Test func theViewBoxIsRead() throws {
  let page = try #require(parsedPage())

  #expect(page.size == CGSize(width: 21000, height: 29700))
}

/// A `<use>` becomes a real outline, placed where the transform put it.
///
/// Without resolving the reference the whole page would be stems and bar lines
/// with no note heads at all.
@Test func aReferencedGlyphIsPlaced() throws {
  let page = try #require(parsedPage())
  let heads = page.shapes.filter { $0.kind == "notehead" }

  #expect(heads.count == 1)
  let box = try #require(heads.first).path.boundingBoxOfPath
  #expect(box.minX == 1000, "translate deveria posicionar o glifo")
  #expect(box.width == 50, "scale(0.5) deveria reduzir pela metade")
}

/// A stem is stroked, a note head is filled.
@Test func strokesAndFillsAreToldApart() throws {
  let page = try #require(parsedPage())

  let stem = try #require(page.shapes.first { $0.kind == "stem" })
  #expect(stem.isFilled == false)
  #expect(stem.strokeWidth > 0)

  let head = try #require(page.shapes.first { $0.kind == "notehead" })
  #expect(head.isFilled)
}

/// Every shape carries the identifier of the element it belongs to.
///
/// This is the handle the cursor holds: the timemap says which ids sound when,
/// and highlighting is finding those ids on the page.
@Test func shapesCarryTheirElementIdentifier() throws {
  let page = try #require(parsedPage())

  #expect(page.shapes.contains { $0.elementID == "note-1" })
  #expect(page.shapes.contains { $0.elementID == "stem-1" })
}

/// An element can be located, which is what scrolling to it needs.
@Test func anElementCanBeFound() throws {
  let page = try #require(parsedPage())
  let frame = try #require(page.frame(of: "note-1"))

  #expect(frame.width > 0)
  #expect(frame.minX >= 1000 - 1)
  #expect(page.frame(of: "não-existe") == nil)
}

/// Rubbish is refused rather than drawn as an empty page.
@Test func rubbishIsRefused() {
  #expect(EngravedPageParser.page(from: "isto não é svg") == nil)
}

/// Transforms compose in the order SVG says they do.
@Test func transformsCompose() {
  let moved = SVGTransform.parse("translate(10, 20)")
  #expect(moved.tx == 10 && moved.ty == 20)

  let scaled = SVGTransform.parse("scale(2)")
  #expect(scaled.a == 2 && scaled.d == 2, "um argumento escala os dois eixos")

  // Translate then scale: the translation is scaled too, as SVG applies them
  // right to left.
  let both = SVGTransform.parse("translate(10, 0) scale(2, 2)")
  #expect(both.tx == 10)
  #expect(both.a == 2)
}

/// A missing or unreadable transform is the identity, not a crash.
@Test func anAbsentTransformIsTheIdentity() {
  #expect(SVGTransform.parse(nil) == .identity)
  #expect(SVGTransform.parse("rotate(45)") == .identity, "o que eu não leio, eu ignoro")
}

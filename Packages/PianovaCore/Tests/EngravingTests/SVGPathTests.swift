import CoreGraphics
import Testing

@testable import Engraving

/// Where a parsed path actually goes, which is what a drawing has to get right.
private func bounds(_ data: String) -> CGRect {
  SVGPath.parse(data).boundingBoxOfPath
}

/// A straight segment, the shape of every stem and staff line.
@Test func aLineGoesWhereItSays() {
  let box = bounds("M2785 1412 L2785 810")

  #expect(box.minX == 2785)
  #expect(box.minY == 810)
  #expect(box.height == 602)
}

/// Lower case means relative, and getting that backwards moves half a page.
@Test func lowerCaseIsRelative() {
  #expect(bounds("M10 10 l20 30").maxX == 30)
  #expect(bounds("M10 10 L20 30").maxX == 20)
}

/// Horizontal and vertical shorthands keep the other coordinate.
@Test func shorthandsKeepTheOtherAxis() {
  let horizontal = bounds("M10 20 H50")
  #expect(horizontal.maxX == 50)
  #expect(horizontal.height == 0)

  let vertical = bounds("M10 20 V60")
  #expect(vertical.maxY == 60)
  #expect(vertical.width == 0)
}

/// A repeated coordinate pair after a move is a line, not another move.
///
/// Reading it as a move leaves the shape as scattered dots with no outline.
@Test func repeatedPairsAfterAMoveAreLines() {
  let path = SVGPath.parse("M0 0 10 0 10 10 0 10 Z")

  #expect(path.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 10, height: 10))
  #expect(!path.isEmpty)
}

/// Curves are what note heads and clefs are made of.
@Test func curvesAreFollowed() {
  let box = bounds("M0 0 C0 -50 100 -50 100 0")

  #expect(box.minX == 0)
  #expect(box.maxX == 100)
  #expect(box.minY < 0, "a curva deveria subir acima da linha de base")
}

/// The smooth form mirrors the previous control point.
@Test func smoothCurvesMirrorTheControlPoint() {
  let mirrored = bounds("M0 0 C0 -40 40 -40 40 0 S80 40 80 0")
  let flat = bounds("M0 0 L80 0")

  #expect(mirrored.maxX == 80)
  #expect(mirrored.height > flat.height, "a curva suave não deveria ser reta")
}

/// Closing returns to the start of the subpath.
@Test func closingReturnsToTheStart() {
  let path = SVGPath.parse("M10 10 L50 10 L50 50 Z")

  #expect(path.boundingBoxOfPath == CGRect(x: 10, y: 10, width: 40, height: 40))
}

/// Numbers run together without separators, which real files do constantly.
@Test func numbersRunTogether() {
  #expect(bounds("M0 0l10-20").maxX == 10)
  #expect(bounds("M0 0l10-20").minY == -20)
}

/// Scientific notation appears in generated files and must not stop the parse.
@Test func scientificNotationIsRead() {
  #expect(bounds("M0 0 L1e2 0").maxX == 100)
}

/// Nothing in, nothing out — and no crash.
@Test func emptyDataIsHarmless() {
  #expect(SVGPath.parse("").isEmpty)
  #expect(SVGPath.parse("   ").isEmpty)
}

/// An unknown command does not spin forever.
///
/// Without consuming something, the scanner would sit on the same numbers for
/// ever and hang the app rather than draw a slightly wrong page.
@Test func anUnknownCommandTerminates() {
  #expect(SVGPath.parse("M0 0 X5 5 L10 10").isEmpty == false)
}

/// A real Verovio glyph outline parses to something with area.
@Test func aRealGlyphOutlineParses() {
  // The opening of the treble clef, taken from a rendered page.
  let clef =
    "M441 -245c-23 -4 -48 -6 -76 -6c-59 0 -102 7 -130 20c-88 42 -150 93 -187 154"
    + "c-26 44 -43 103 -48 176c0 6 -1 13 -1 19c0 54 15 111 45 170z"

  let box = bounds(clef)
  #expect(box.width > 100)
  #expect(box.height > 100)
}

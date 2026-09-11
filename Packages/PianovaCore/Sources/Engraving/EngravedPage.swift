import CoreGraphics
import Foundation

/// One drawable piece of an engraved page.
public struct EngravedShape: Equatable {
  /// The outline, already placed on the page.
  public let path: CGPath

  /// Whether it is filled.
  ///
  /// A stem is stroked; a note head is filled.
  public let isFilled: Bool

  /// Line weight, when it is stroked.
  public let strokeWidth: CGFloat

  /// Identifier of the nearest element that has one.
  ///
  /// This is the handle the cursor holds: the engraver gives every note an id,
  /// and the timemap says which ids sound when.
  public let elementID: String?

  /// What the engraver called it — `note`, `stem`, `barLine`, and so on.
  public let kind: String?

  /// Identifier of the note this belongs to, if any.
  ///
  /// Separate from ``elementID`` because a stem and a flag carry identifiers of
  /// their own: highlighting by element alone paints the note head and leaves
  /// the rest of the note in the old colour.
  public let noteID: String?

  /// Identifier of the bar this sits in.
  public let measureID: String?

  /// Identifier of the system this sits in.
  ///
  /// What the page scrolls by. Following the note instead makes the page rise
  /// and fall with every change of hand, because the left hand sits at the foot
  /// of a system and the right at its top.
  public let systemID: String?
}

/// A page of engraved music, ready to draw.
public struct EngravedPage: Equatable {
  /// The page's own coordinate system, from its `viewBox`.
  public let size: CGSize

  /// Everything on it, in drawing order.
  public let shapes: [EngravedShape]

  /// Where a given element sits, for scrolling to it or drawing over it.
  /// - Parameter id: The element identifier.
  /// - Returns: Its bounding box, or `nil` if it is not on this page.
  /// The systems on this page, top to bottom, with where each sits.
  public var systems: [(id: String, frame: CGRect)] {
    var boxes: [String: CGRect] = [:]

    for shape in shapes {
      guard let system = shape.systemID else { continue }
      let box = shape.path.boundingBoxOfPath
      boxes[system] = boxes[system].map { $0.union(box) } ?? box
    }

    return boxes.map { (id: $0.key, frame: $0.value) }.sorted { $0.frame.minY < $1.frame.minY }
  }

  /// Which bar a given element was drawn in.
  /// - Parameter id: A note or element identifier.
  /// - Returns: The bar's identifier, or `nil` if it is not on this page.
  public func measure(containing id: String) -> String? {
    shapes.first { $0.noteID == id || $0.elementID == id }?.measureID
  }

  /// Where a bar sits, for drawing a selection over it.
  /// - Parameter id: The bar's identifier.
  /// - Returns: Its bounding box, or `nil` if it is not on this page.
  public func measureFrame(_ id: String) -> CGRect? {
    let boxes = shapes.filter { $0.measureID == id }.map { $0.path.boundingBoxOfPath }
    guard let first = boxes.first else { return nil }
    return boxes.dropFirst().reduce(first) { $0.union($1) }
  }

  /// Which system a given element was drawn in.
  /// - Parameter id: A note or element identifier.
  /// - Returns: The system's identifier, or `nil` if it is not on this page.
  public func system(containing id: String) -> String? {
    shapes.first { $0.noteID == id || $0.elementID == id }?.systemID
  }

  /// Where a given element sits, for scrolling to it or drawing over it.
  /// - Parameter id: A note or element identifier.
  /// - Returns: Its bounding box, or `nil` if it is not on this page.
  public func frame(of id: String) -> CGRect? {
    let boxes = shapes.filter { $0.noteID == id || $0.elementID == id }
      .map { $0.path.boundingBoxOfPath }
    guard let first = boxes.first else { return nil }
    return boxes.dropFirst().reduce(first) { $0.union($1) }
  }
}

/// Reads an engraver's SVG into shapes that can be drawn natively.
///
/// No `WKWebView` anywhere: the page is parsed once and drawn with the same
/// primitives as the rest of the app, so there is no JavaScript in the path
/// between a key being pressed and the screen reacting.
public final class EngravedPageParser: NSObject, XMLParserDelegate {
  private var symbols: [String: CGPath] = [:]
  private var shapes: [EngravedShape] = []
  private var size = CGSize(width: 1, height: 1)

  private var transforms: [CGAffineTransform] = [.identity]
  private var ids: [String?] = [nil]
  private var kinds: [String?] = [nil]
  private var notes: [String?] = [nil]
  private var systemStack: [String?] = [nil]
  private var measures: [String?] = [nil]

  private var definingSymbol: String?
  private var symbolPath = CGMutablePath()

  /// Reads a page.
  /// - Parameter svg: The engraver's output.
  /// - Returns: The page, or `nil` if it could not be read.
  public static func page(from svg: String) -> EngravedPage? {
    let parser = EngravedPageParser()
    guard let data = svg.data(using: .utf8) else { return nil }

    let xml = XMLParser(data: data)
    xml.delegate = parser
    guard xml.parse() else { return nil }

    return EngravedPage(size: parser.size, shapes: parser.shapes)
  }

  private var current: CGAffineTransform { transforms.last ?? .identity }

  /// Handles an opening element.
  ///
  /// Part of `XMLParserDelegate`; not called directly.
  public func parser(
    _ parser: XMLParser,
    didStartElement name: String,
    namespaceURI: String?,
    qualifiedName: String?,
    attributes: [String: String]
  ) {
    // The inner `definition-scale` carries the viewBox the music is drawn in.
    if name == "svg", let box = attributes["viewBox"] {
      let numbers = box.split(separator: " ").compactMap { Double($0) }
      if numbers.count == 4 { size = CGSize(width: numbers[2], height: numbers[3]) }
    }

    let transform = SVGTransform.parse(attributes["transform"]).concatenating(current)
    transforms.append(transform)
    ids.append(attributes["id"] ?? ids.last ?? nil)
    kinds.append(attributes["class"] ?? kinds.last ?? nil)

    // Everything inside a `note` belongs to that note, whatever identifiers it
    // carries of its own.
    let classes = (attributes["class"] ?? "").split(separator: " ")
    let isNote = classes.contains("note")
    notes.append(isNote ? (attributes["id"] ?? notes.last ?? nil) : (notes.last ?? nil))

    let isSystem = classes.contains("system")
    systemStack.append(
      isSystem ? (attributes["id"] ?? systemStack.last ?? nil) : (systemStack.last ?? nil))

    let isMeasure = classes.contains("measure")
    measures.append(
      isMeasure ? (attributes["id"] ?? measures.last ?? nil) : (measures.last ?? nil))

    switch name {
    case "g":
      // A `<g>` inside `<defs>` is a glyph waiting to be reused.
      if let id = attributes["id"], definingSymbol == nil, isInsideDefs {
        definingSymbol = id
        symbolPath = CGMutablePath()
      }

    case "path":
      guard let data = attributes["d"] else { break }
      let path = SVGPath.parse(data)
      let placed = path.copy(using: [transform]) ?? path

      if definingSymbol != nil {
        symbolPath.addPath(path, transform: SVGTransform.parse(attributes["transform"]))
      } else {
        let width = attributes["stroke-width"].flatMap(Double.init) ?? 0
        shapes.append(
          EngravedShape(
            path: placed,
            isFilled: width == 0,
            strokeWidth: CGFloat(width) * scaleOf(transform),
            elementID: ids.last ?? nil,
            kind: kinds.last ?? nil,
            noteID: notes.last ?? nil,
            measureID: measures.last ?? nil,
            systemID: systemStack.last ?? nil))
      }

    case "use":
      let reference = (attributes["xlink:href"] ?? attributes["href"] ?? "")
        .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
      guard let glyph = symbols[reference] else { break }

      let placed = glyph.copy(using: [transform]) ?? glyph
      shapes.append(
        EngravedShape(
          path: placed, isFilled: true, strokeWidth: 0,
          elementID: ids.last ?? nil, kind: kinds.last ?? nil,
          noteID: notes.last ?? nil, measureID: measures.last ?? nil,
          systemID: systemStack.last ?? nil))

    case "defs":
      isInsideDefs = true

    default:
      break
    }
  }

  /// Handles a closing element.
  ///
  /// Part of `XMLParserDelegate`; not called directly.
  public func parser(
    _ parser: XMLParser,
    didEndElement name: String,
    namespaceURI: String?,
    qualifiedName: String?
  ) {
    if name == "defs" { isInsideDefs = false }

    if name == "g", let symbol = definingSymbol {
      symbols[symbol] = symbolPath
      definingSymbol = nil
    }

    if transforms.count > 1 { transforms.removeLast() }
    if ids.count > 1 { ids.removeLast() }
    if kinds.count > 1 { kinds.removeLast() }
    if notes.count > 1 { notes.removeLast() }
    if systemStack.count > 1 { systemStack.removeLast() }
    if measures.count > 1 { measures.removeLast() }
  }

  private var isInsideDefs = false

  /// How much a transform scales, so a stroke width scales with it.
  private func scaleOf(_ transform: CGAffineTransform) -> CGFloat {
    (transform.a * transform.a + transform.b * transform.b).squareRoot()
  }
}

/// Reads the handful of SVG transforms an engraver emits.
public enum SVGTransform {
  /// Parses a `transform` attribute.
  /// - Parameter text: The attribute, or `nil`.
  /// - Returns: The transform it describes, or the identity.
  public static func parse(_ text: String?) -> CGAffineTransform {
    guard let text else { return .identity }

    var result = CGAffineTransform.identity
    let pattern = #"(\w+)\s*\(([^)]*)\)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

    let range = NSRange(text.startIndex..., in: text)
    for match in regex.matches(in: text, range: range) {
      guard let nameRange = Range(match.range(at: 1), in: text),
        let argsRange = Range(match.range(at: 2), in: text)
      else { continue }

      let name = String(text[nameRange])
      let pieces: [Substring] = text[argsRange]
        .split(whereSeparator: {
          $0 == "," || $0 == " "
        })
      let numbers: [Double] = pieces.compactMap { Double($0) }
      let values: [CGFloat] = numbers.map { CGFloat($0) }

      switch name {
      case "translate" where values.count >= 1:
        result = CGAffineTransform(
          translationX: values[0], y: values.count > 1 ? values[1] : 0
        )
        .concatenating(result)
      case "scale" where values.count >= 1:
        result = CGAffineTransform(
          scaleX: values[0], y: values.count > 1 ? values[1] : values[0]
        )
        .concatenating(result)
      case "matrix" where values.count == 6:
        result = CGAffineTransform(
          a: values[0], b: values[1], c: values[2],
          d: values[3], tx: values[4], ty: values[5]
        )
        .concatenating(result)
      default:
        break
      }
    }

    return result
  }
}

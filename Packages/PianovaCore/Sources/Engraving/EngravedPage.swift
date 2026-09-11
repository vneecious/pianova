import CoreGraphics
import Foundation

/// One drawable piece of an engraved page.
///
/// `@unchecked` because of the `CGPath`: it is immutable once parsed, which is
/// what makes sharing it across threads safe — the compiler just cannot see
/// that.
public struct EngravedShape: Equatable, @unchecked Sendable {
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

  /// Which staff this was drawn on, counting from one.
  ///
  /// What lets one hand be dimmed while the other is worked at: the hand not
  /// being practised is still the reference for what the other has to fit into,
  /// so it is faded rather than taken away.
  public let staffNumber: Int?

  /// Identifier of the system this sits in.
  ///
  /// What the page scrolls by. Following the note instead makes the page rise
  /// and fall with every change of hand, because the left hand sits at the foot
  /// of a system and the right at its top.
  public let systemID: String?
}

/// A run of text on the page — a fingering number, a tempo word.
///
/// The engraver writes these as SVG text, and for a long time the parser read
/// only paths: every letter and number was dropped in silence. Fingering was
/// the first thing anyone missed.
public struct EngravedText: Equatable, Sendable {
  /// The characters themselves.
  public let text: String

  /// Where the baseline starts (or centers, per ``isCentered``).
  public let position: CGPoint

  /// Height of the type, in page units.
  public let fontSize: CGFloat

  /// Whether ``position`` is the middle of the run rather than its start.
  public let isCentered: Bool

  /// Whether the run uses the music font — SMuFL glyphs, not letters.
  ///
  /// A dynamic's *p* and the pedal sign are characters in a music font;
  /// drawn with a text face they come out as tofu or as plain letters, which
  /// is exactly the wrong look for them.
  public let isMusicFont: Bool

  /// Which staff it belongs to, for fading with the hand at rest.
  public let staffNumber: Int?

  /// Creates a run of text.
  /// - Parameters:
  ///   - text: The characters.
  ///   - position: Where it sits, in page coordinates.
  ///   - fontSize: Height of the type, in page units.
  ///   - isCentered: Whether the position names the middle of the run.
  ///   - isMusicFont: Whether the run uses the music font.
  ///   - staffNumber: The staff it belongs to, if any.
  public init(
    text: String, position: CGPoint, fontSize: CGFloat, isCentered: Bool,
    isMusicFont: Bool = false, staffNumber: Int?
  ) {
    self.text = text
    self.position = position
    self.fontSize = fontSize
    self.isCentered = isCentered
    self.isMusicFont = isMusicFont
    self.staffNumber = staffNumber
  }
}

/// A page of engraved music, ready to draw.
///
/// Every lookup is a table built once when the page is read. They used to be
/// scans over every shape, and a page has thousands — done per frame, that is
/// what a frozen screen is made of.
public struct EngravedPage: Equatable, @unchecked Sendable {
  /// Tells this parse apart from any other, for caching what is drawn from it.
  public let id: String

  /// The page's own coordinate system, from its `viewBox`.
  public let size: CGSize

  /// Everything on it, in drawing order.
  public let shapes: [EngravedShape]

  /// The systems on this page, top to bottom, with where each sits.
  public let systems: [(id: String, frame: CGRect)]

  /// How tall a system is here, taking the tallest as the measure.
  ///
  /// Used to work out how much has to fit on screen: reading ahead means the
  /// next line being visible, and that is impossible if one line fills the view.
  public let systemHeight: CGFloat

  /// Which shapes belong to each note or element identifier.
  public let ownersIndex: [String: [Int]]

  /// Where each bar sits, for selections and hit-testing.
  public let measureFrames: [String: CGRect]

  /// Every run of text on the page, fingering included.
  public let texts: [EngravedText]

  /// Reads a page from its shapes, building every lookup once.
  /// - Parameters:
  ///   - size: The page's own coordinate system.
  ///   - shapes: Everything on it, in drawing order.
  ///   - texts: The text runs on it.
  public init(size: CGSize, shapes: [EngravedShape], texts: [EngravedText] = []) {
    self.id = UUID().uuidString
    self.size = size
    self.shapes = shapes
    self.texts = texts

    var owners: [String: [Int]] = [:]
    var measures: [String: CGRect] = [:]
    var systemBoxes: [String: CGRect] = [:]

    for (index, shape) in shapes.enumerated() {
      let box = shape.path.boundingBoxOfPath

      if let note = shape.noteID { owners[note, default: []].append(index) }
      if let element = shape.elementID, element != shape.noteID {
        owners[element, default: []].append(index)
      }
      if let measure = shape.measureID {
        measures[measure] = measures[measure].map { $0.union(box) } ?? box
      }
      if let system = shape.systemID {
        systemBoxes[system] = systemBoxes[system].map { $0.union(box) } ?? box
      }
    }

    self.ownersIndex = owners
    self.measureFrames = measures
    self.systems =
      systemBoxes
      .map { (id: $0.key, frame: $0.value) }
      .sorted { $0.frame.minY < $1.frame.minY }
    self.systemHeight = systems.map(\.frame.height).max() ?? size.height
  }

  /// Two parses are the same page only if they are the same parse.
  public static func == (left: EngravedPage, right: EngravedPage) -> Bool {
    left.id == right.id
  }

  /// Which bar a given element was drawn in.
  /// - Parameter id: A note or element identifier.
  /// - Returns: The bar's identifier, or `nil` if it is not on this page.
  public func measure(containing id: String) -> String? {
    ownersIndex[id]?.first.map { shapes[$0] }?.measureID
  }

  /// Where a bar sits, for drawing a selection over it.
  /// - Parameter id: The bar's identifier.
  /// - Returns: Its bounding box, or `nil` if it is not on this page.
  public func measureFrame(_ id: String) -> CGRect? {
    measureFrames[id]
  }

  /// Which system a given element was drawn in.
  /// - Parameter id: A note or element identifier.
  /// - Returns: The system's identifier, or `nil` if it is not on this page.
  public func system(containing id: String) -> String? {
    ownersIndex[id]?.first.map { shapes[$0] }?.systemID
  }

  /// Where a given element sits, for scrolling to it or drawing over it.
  /// - Parameter id: A note or element identifier.
  /// - Returns: Its bounding box, or `nil` if it is not on this page.
  public func frame(of id: String) -> CGRect? {
    let boxes = (ownersIndex[id] ?? []).map { shapes[$0].path.boundingBoxOfPath }
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
  private var staves: [Int?] = [nil]

  /// How many staves each measure has opened, keyed by the measure's id.
  private var stavesSeen: [String: Int] = [:]

  private var definingSymbol: String?
  private var symbolPath = CGMutablePath()

  /// Text runs collected as the page is read.
  private var texts: [EngravedText] = []

  /// The text element being read right now, if any.
  private var textDepth = 0
  private var textBuffer = ""
  private var textPosition = CGPoint.zero
  private var textSize = 0.0
  private var textCentered = false
  private var textMusicFont = false
  private var textTransform = CGAffineTransform.identity
  private var textStaff: Int?

  /// Reads a page.
  /// - Parameter svg: The engraver's output.
  /// - Returns: The page, or `nil` if it could not be read.
  public static func page(from svg: String) -> EngravedPage? {
    let parser = EngravedPageParser()
    guard let data = svg.data(using: .utf8) else { return nil }

    let xml = XMLParser(data: data)
    xml.delegate = parser
    guard xml.parse() else { return nil }

    return EngravedPage(size: parser.size, shapes: parser.shapes, texts: parser.texts)
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

    // Staves are numbered by the order they open inside their measure, first
    // and second. Verovio writes no staff number into the SVG — no `n`
    // anywhere — and guessing one with a fallback marked the whole page as
    // staff 1, which is what made "left hand" fade the entire piece.
    let isStaff = classes.contains("staff")
    if isStaff {
      let measure = (measures.last ?? nil) ?? ""
      stavesSeen[measure, default: 0] += 1
      staves.append(stavesSeen[measure])
    } else {
      staves.append(staves.last ?? nil)
    }

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
            staffNumber: staves.last ?? nil,
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
          staffNumber: staves.last ?? nil, systemID: systemStack.last ?? nil))

    case "defs":
      isInsideDefs = true

    case "text", "tspan":
      if name == "text" {
        textDepth += 1
        if textDepth == 1 {
          textBuffer = ""
          textPosition = .zero
          textSize = 0
          textCentered = false
          textMusicFont = false
          textTransform = transform
          textStaff = staves.last ?? nil
        }
      }
      // Position and size may sit on the text or on any tspan inside it.
      if let x = attributes["x"].flatMap(Double.init) { textPosition.x = x }
      if let y = attributes["y"].flatMap(Double.init) { textPosition.y = y }
      if let raw = attributes["font-size"],
        let size = Double(raw.prefix { $0.isNumber || $0 == "." }), size > 0
      {
        textSize = size
      }
      if attributes["text-anchor"] == "middle" { textCentered = true }
      if let family = attributes["font-family"],
        family.contains("Leipzig") || family.contains("Verovio") || family.contains("Bravura")
      {
        textMusicFont = true
      }

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

    if name == "text" {
      textDepth -= 1
      let run = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

      if textDepth == 0, !run.isEmpty, textSize > 0 {
        texts.append(
          EngravedText(
            text: run,
            position: textPosition.applying(textTransform),
            fontSize: textSize,
            isCentered: textCentered,
            isMusicFont: textMusicFont,
            staffNumber: textStaff))
      }
    }

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
    if staves.count > 1 { staves.removeLast() }
  }

  private var isInsideDefs = false

  /// Collects the characters of the text element being read.
  ///
  /// Part of `XMLParserDelegate`; not called directly.
  public func parser(_ parser: XMLParser, foundCharacters string: String) {
    if textDepth > 0 { textBuffer += string }
  }

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

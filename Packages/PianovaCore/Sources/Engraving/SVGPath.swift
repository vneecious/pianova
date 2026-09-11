import CoreGraphics
import Foundation

/// Turns SVG path data into a drawable path.
///
/// Everything an engraver emits is a path: note heads and clefs are outlines in
/// the file's own `<defs>`, and stems, staff lines and beams are straight
/// segments. So one parser draws the whole page, and no font metrics have to
/// agree with anything.
public enum SVGPath {
  /// Parses the `d` attribute of an SVG path.
  /// - Parameter data: The path data, as written in the file.
  /// - Returns: The path it describes.
  public static func parse(_ data: String) -> CGMutablePath {
    let path = CGMutablePath()
    var scanner = Scanner(data)

    var point = CGPoint.zero
    var start = CGPoint.zero
    // Where the last curve's second control point was, for the smooth forms.
    var lastControl: CGPoint?
    var command: Character = "M"

    while let next = scanner.nextCommandOrNumber() {
      if let letter = next.command {
        command = letter
        if letter == "z" || letter == "Z" {
          path.closeSubpath()
          point = start
          lastControl = nil
          continue
        }
      } else {
        // A repeated command: `M 0 0 10 10` means move then line.
        scanner.pushBack(next)
        if command == "M" { command = "L" }
        if command == "m" { command = "l" }
      }

      let relative = command.isLowercase
      func read() -> CGFloat { CGFloat(scanner.nextNumber() ?? 0) }
      func readPoint() -> CGPoint {
        let x = read()
        let y = read()
        return relative ? CGPoint(x: point.x + x, y: point.y + y) : CGPoint(x: x, y: y)
      }

      switch Character(command.lowercased()) {
      case "m":
        point = readPoint()
        start = point
        path.move(to: point)
        lastControl = nil

      case "l":
        point = readPoint()
        path.addLine(to: point)
        lastControl = nil

      case "h":
        let x = read()
        point = CGPoint(x: relative ? point.x + x : x, y: point.y)
        path.addLine(to: point)
        lastControl = nil

      case "v":
        let y = read()
        point = CGPoint(x: point.x, y: relative ? point.y + y : y)
        path.addLine(to: point)
        lastControl = nil

      case "c":
        let one = readPoint()
        let two = readPoint()
        let end = readPoint()
        path.addCurve(to: end, control1: one, control2: two)
        point = end
        lastControl = two

      case "s":
        // The first control point mirrors the previous one, which is what
        // makes a smooth curve smooth.
        let mirrored =
          lastControl.map {
            CGPoint(x: 2 * point.x - $0.x, y: 2 * point.y - $0.y)
          } ?? point
        let two = readPoint()
        let end = readPoint()
        path.addCurve(to: end, control1: mirrored, control2: two)
        point = end
        lastControl = two

      case "q":
        let control = readPoint()
        let end = readPoint()
        path.addQuadCurve(to: end, control: control)
        point = end
        lastControl = control

      case "t":
        let mirrored =
          lastControl.map {
            CGPoint(x: 2 * point.x - $0.x, y: 2 * point.y - $0.y)
          } ?? point
        let end = readPoint()
        path.addQuadCurve(to: end, control: mirrored)
        point = end
        lastControl = mirrored

      default:
        // An unknown command would otherwise spin forever on its own numbers.
        _ = scanner.nextNumber()
        lastControl = nil
      }
    }

    return path
  }

  /// One token of path data: a letter, or a number.
  struct Token {
    let command: Character?
    let number: Double?
  }

  /// Walks path data without allocating a token array for a whole page.
  struct Scanner {
    private let characters: [Character]
    private var index: Int
    private var pushedBack: Token?

    init(_ text: String) {
      characters = Array(text)
      index = 0
    }

    mutating func pushBack(_ token: Token) {
      pushedBack = token
    }

    mutating func nextCommandOrNumber() -> Token? {
      if let held = pushedBack {
        pushedBack = nil
        return held
      }

      skipSeparators()
      guard index < characters.count else { return nil }

      let character = characters[index]
      if character.isLetter {
        index += 1
        return Token(command: character, number: nil)
      }

      return nextNumber().map { Token(command: nil, number: $0) }
    }

    mutating func nextNumber() -> Double? {
      if let held = pushedBack, let number = held.number {
        pushedBack = nil
        return number
      }

      skipSeparators()
      var text = ""

      if index < characters.count, characters[index] == "-" || characters[index] == "+" {
        text.append(characters[index])
        index += 1
      }
      while index < characters.count,
        characters[index].isNumber || characters[index] == "." || characters[index] == "e"
          || ((characters[index] == "-" || characters[index] == "+") && text.last == "e")
      {
        text.append(characters[index])
        index += 1
      }

      return Double(text)
    }

    private mutating func skipSeparators() {
      while index < characters.count,
        characters[index] == " " || characters[index] == "," || characters[index] == "\n"
          || characters[index] == "\t" || characters[index] == "\r"
      {
        index += 1
      }
    }
  }
}

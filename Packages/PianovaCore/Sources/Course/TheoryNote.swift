import ScoreModel

/// A music symbol shown with a caption, to illustrate a teaching page.
public struct GlyphLabel: Equatable, Sendable {
  /// The SMuFL code point.
  public let glyph: String

  /// What it is called.
  public let caption: String

  /// What it is worth, or an empty string when the symbol needs no gloss.
  public let detail: String

  /// Creates a labelled symbol.
  /// - Parameters:
  ///   - glyph: The SMuFL code point.
  ///   - caption: What it is called.
  ///   - detail: What it is worth, or empty.
  public init(glyph: String, caption: String, detail: String = "") {
    self.glyph = glyph
    self.caption = caption
    self.detail = detail
  }
}

/// A short passage of staff shown as an example on a teaching page.
public struct StaffExample: Equatable, Sendable {
  /// The clef to draw it in.
  public let clef: Clef

  /// The notes to show.
  public let pitches: [Pitch]

  /// One line explaining what to look at.
  public let caption: String

  /// Creates an example.
  /// - Parameters:
  ///   - clef: The clef to draw it in.
  ///   - pitches: The notes to show.
  ///   - caption: One line explaining what to look at.
  public init(clef: Clef, pitches: [Pitch], caption: String) {
    self.clef = clef
    self.pitches = pitches
    self.caption = caption
  }
}

/// A key singled out on a keyboard diagram.
public struct KeyMark: Equatable, Sendable {
  /// How loudly the key is called out.
  public enum Emphasis: Equatable, Sendable {
    /// The key the page is about.
    case primary
    /// Context: shown, named, but not the subject.
    case secondary
  }

  /// The key to mark.
  public let pitch: Pitch

  /// What to write on it, or empty to only tint it.
  public let label: String

  /// How loudly to call it out.
  public let emphasis: Emphasis

  /// Creates a mark.
  /// - Parameters:
  ///   - pitch: The key to mark.
  ///   - label: What to write on it, or empty.
  ///   - emphasis: How loudly to call it out.
  public init(_ pitch: Pitch, label: String = "", emphasis: Emphasis = .primary) {
    self.pitch = pitch
    self.label = label
    self.emphasis = emphasis
  }
}

/// A span drawn above a keyboard diagram, naming a group of keys.
///
/// This is how the groups of two and three black keys get pointed at, which is
/// the single most useful thing a keyboard picture can do for a beginner.
public struct KeyBracket: Equatable, Sendable {
  /// The keys the bracket covers, inclusive.
  public let range: ClosedRange<UInt8>

  /// What the group is called.
  public let label: String

  /// Creates a bracket.
  /// - Parameters:
  ///   - range: The keys it covers.
  ///   - label: What the group is called.
  public init(_ range: ClosedRange<UInt8>, label: String) {
    self.range = range
    self.label = label
  }
}

/// A stretch of keyboard drawn as a picture, with keys called out.
public struct KeyboardDiagram: Equatable, Sendable {
  /// The keys to draw, inclusive.
  public let range: ClosedRange<UInt8>

  /// Keys singled out.
  public let marks: [KeyMark]

  /// Groups named above the keys.
  public let brackets: [KeyBracket]

  /// One line explaining what to look at.
  public let caption: String

  /// Creates a keyboard diagram.
  /// - Parameters:
  ///   - range: The keys to draw.
  ///   - marks: Keys singled out.
  ///   - brackets: Groups named above the keys.
  ///   - caption: One line explaining what to look at.
  public init(
    range: ClosedRange<UInt8>,
    marks: [KeyMark] = [],
    brackets: [KeyBracket] = [],
    caption: String
  ) {
    self.range = range
    self.marks = marks
    self.brackets = brackets
    self.caption = caption
  }

  /// Whether everything called out really sits inside the drawn keys.
  public var isSelfContained: Bool {
    marks.allSatisfy { range.contains($0.pitch.midiNoteNumber) }
      && brackets.allSatisfy {
        range.contains($0.range.lowerBound) && range.contains($0.range.upperBound)
      }
  }
}

/// The two hands with their fingers numbered.
///
/// The numbering is mirrored — both thumbs are finger 1 and they face each
/// other — and a picture settles that in one look where a paragraph does not.
public struct HandDiagram: Equatable, Sendable {
  /// Which hands to draw, left to right as they sit at the keyboard.
  public let hands: [Hand]

  /// One line explaining what to look at.
  public let caption: String

  /// Creates a hand diagram.
  /// - Parameters:
  ///   - hands: Which hands to draw.
  ///   - caption: One line explaining what to look at.
  public init(hands: [Hand] = [.left, .right], caption: String) {
    self.hands = hands
    self.caption = caption
  }
}

/// The halving of note values, drawn as a tree.
///
/// One semibreve over two minims over four crotchets: the picture *is* the
/// rule, and it is far quicker to read than the sentence that states it.
public struct ValueTree: Equatable, Sendable {
  /// The rows, longest figure first.
  public let rows: [NoteValue]

  /// One line explaining what to look at.
  public let caption: String

  /// Creates a value tree.
  /// - Parameters:
  ///   - rows: The rows, longest first.
  ///   - caption: One line explaining what to look at.
  public init(rows: [NoteValue] = [.whole, .half, .quarter, .eighth], caption: String) {
    self.rows = rows
    self.caption = caption
  }
}

/// A figure on a teaching page.
///
/// Keyboard, hands and duration are spatial things. Saying in words where the C
/// is costs a paragraph and still reads as ambiguous; a drawn keyboard with the
/// key shaded needs no sentence at all.
public enum Illustration: Equatable, Sendable {
  /// A passage of staff.
  case staff(StaffExample)
  /// A stretch of keyboard with keys called out.
  case keyboard(KeyboardDiagram)
  /// The hands with their fingers numbered.
  case hands(HandDiagram)
  /// The halving of note values.
  case valueTree(ValueTree)

  /// The line printed under the figure.
  public var caption: String {
    switch self {
    case .staff(let example): return example.caption
    case .keyboard(let diagram): return diagram.caption
    case .hands(let diagram): return diagram.caption
    case .valueTree(let tree): return tree.caption
    }
  }
}

/// One teaching page: the concept explained, before anything is asked.
///
/// Questions alone cannot teach — they can only check. A block opens with these
/// so the round that follows has something to check against.
public struct TheoryNote: Equatable, Sendable, Identifiable {
  /// Stable identifier, referenced by the lessons.
  public let id: String

  /// Which block it belongs to.
  public let topic: TheoryTopic

  /// The heading.
  public let title: String

  /// The explanation, one entry per paragraph.
  public let body: [String]

  /// Symbols illustrating the page.
  public let glyphs: [GlyphLabel]

  /// The figures on the page, in the order they are shown.
  public let illustrations: [Illustration]

  /// Creates a teaching page.
  /// - Parameters:
  ///   - id: Stable identifier, referenced by the lessons.
  ///   - topic: Which block it belongs to.
  ///   - title: The heading.
  ///   - body: The explanation, one entry per paragraph.
  ///   - glyphs: Symbols illustrating the page.
  ///   - example: A staff example, when seeing it on the staff is the point.
  ///   - illustrations: Further figures, shown after the staff example.
  public init(
    id: String,
    topic: TheoryTopic,
    title: String,
    body: [String],
    glyphs: [GlyphLabel] = [],
    example: StaffExample? = nil,
    illustrations: [Illustration] = []
  ) {
    self.id = id
    self.topic = topic
    self.title = title
    self.body = body
    self.glyphs = glyphs
    self.illustrations = example.map { [.staff($0)] + illustrations } ?? illustrations
  }

  /// The staff example, when the page has one.
  public var example: StaffExample? {
    illustrations.lazy
      .compactMap {
        guard case .staff(let example) = $0 else { return nil }
        return example
      }
      .first
  }
}

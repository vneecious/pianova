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

  /// A staff example, when seeing it on the staff is the point.
  public let example: StaffExample?

  /// Creates a teaching page.
  /// - Parameters:
  ///   - id: Stable identifier, referenced by the lessons.
  ///   - topic: Which block it belongs to.
  ///   - title: The heading.
  ///   - body: The explanation, one entry per paragraph.
  ///   - glyphs: Symbols illustrating the page.
  ///   - example: A staff example, when useful.
  public init(
    id: String,
    topic: TheoryTopic,
    title: String,
    body: [String],
    glyphs: [GlyphLabel] = [],
    example: StaffExample? = nil
  ) {
    self.id = id
    self.topic = topic
    self.title = title
    self.body = body
    self.glyphs = glyphs
    self.example = example
  }
}

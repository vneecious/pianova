import ScoreModel

/// One step of the card curriculum.
///
/// A level with more than one section mixes clefs inside the same round, which
/// is harder than either clef alone: the reference changes card to card.
public struct QuizLevel: Equatable, Sendable {
  /// One clef and the range of notes drawn for it.
  public struct Section: Equatable, Sendable {
    /// The clef these notes are drawn in.
    public let clef: Clef

    /// The MIDI range to draw from, inclusive.
    public let range: ClosedRange<UInt8>

    /// Creates a section.
    /// - Parameters:
    ///   - clef: The clef these notes are drawn in.
    ///   - range: The MIDI range to draw from, inclusive.
    public init(clef: Clef, range: ClosedRange<UInt8>) {
      self.clef = clef
      self.range = range
    }
  }

  /// The sections making up this level.
  public let sections: [Section]

  /// Whether rounds at this level mix in reversed cards.
  ///
  /// README › Cards invertidos rule 14 keeps level one free of them, so the
  /// basics settle before difficulty is added.
  public let includesReversedCards: Bool

  /// Creates a level.
  /// - Parameters:
  ///   - sections: The sections making up the level.
  ///   - includesReversedCards: Whether rounds mix in reversed cards.
  public init(sections: [Section], includesReversedCards: Bool = false) {
    self.sections = sections
    self.includesReversedCards = includesReversedCards
  }

  /// Whether this level draws from more than one clef.
  public var mixesClefs: Bool { Set(sections.map(\.clef)).count > 1 }
}

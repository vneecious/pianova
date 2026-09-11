import Foundation

/// Which hands a passage is being worked at with.
public enum PracticeHands: String, CaseIterable, Identifiable, Sendable {
  /// Both, as written.
  case both
  /// The upper staff alone.
  case right
  /// The lower staff alone.
  case left

  /// Stable identity for `ForEach`.
  public var id: String { rawValue }

  /// The name shown to the player.
  public var title: String {
    switch self {
    case .both: return "Duas mãos"
    case .right: return "Direita"
    case .left: return "Esquerda"
    }
  }

  /// Whether notes written on a staff are being judged.
  /// - Parameter staff: 1 for the upper staff, 2 for the lower.
  /// - Returns: `true` when this hand is the one in study.
  public func judges(staff: Int) -> Bool {
    switch self {
    case .both: return true
    case .right: return staff == 1
    case .left: return staff == 2
    }
  }

  /// The notes of one moment that this hand is answerable for.
  ///
  /// Judged note by note, never moment by moment: where the hands play
  /// together, the studied hand answers for its own notes and no others —
  /// classifying the whole moment by one staff made a one-hand study wait
  /// for the other hand exactly where the hands coincide.
  /// - Parameters:
  ///   - pitches: Everything sounding at the moment.
  ///   - upper: What the upper staff carries there.
  ///   - lower: What the lower staff carries there.
  /// - Returns: The notes this hand is judged on; empty means "not judged".
  public func sounding(
    of pitches: Set<Pitch>, upper: Set<Pitch>, lower: Set<Pitch>
  ) -> Set<Pitch> {
    switch self {
    case .both: return pitches
    case .right: return pitches.intersection(upper)
    case .left: return pitches.intersection(lower)
    }
  }

  /// The staff left as reference, to be drawn faded.
  ///
  /// Faded and not removed: the other hand is what this one has to fit into,
  /// and taking it off the page takes the reason for the passage with it.
  public var quietStaff: Int? {
    switch self {
    case .both: return nil
    case .right: return 2
    case .left: return 1
    }
  }

  /// How it is named inside a sentence.
  public var spoken: String {
    switch self {
    case .both: return "as duas mãos"
    case .right: return "mão direita"
    case .left: return "mão esquerda"
    }
  }

  /// The short name, for a control with no room.
  public var shortTitle: String {
    switch self {
    case .both: return "Ambas"
    case .right: return "M.D."
    case .left: return "M.E."
    }
  }
}

/// A stretch of bars being worked at.
public struct PracticeRange: Equatable, Sendable {
  /// The first bar, counting as the score numbers them.
  public let first: Int

  /// The last bar, inclusive.
  public let last: Int

  /// Creates a range, in whichever order the bars were chosen.
  /// - Parameters:
  ///   - first: One end.
  ///   - last: The other.
  public init(first: Int, last: Int) {
    self.first = min(first, last)
    self.last = max(first, last)
  }

  /// How many bars it covers.
  public var count: Int { last - first + 1 }

  /// Whether a bar falls inside the passage, and so is judged.
  /// - Parameter bar: A bar number, as the score counts them.
  /// - Returns: `true` when it belongs to the passage.
  public func judges(bar: Int) -> Bool { bar >= first && bar <= last }

  /// How it is named inside a sentence.
  public var spoken: String {
    count == 1 ? "o compasso \(first)" : "os compassos \(first)–\(last)"
  }

  /// How it is written out for the player.
  public var label: String {
    count == 1 ? "Compasso \(first)" : "Compassos \(first)–\(last)"
  }
}

extension Score {
  /// Which columns a passage covers, in the piece's own numbering.
  ///
  /// The passage is a stretch of this score and not a score of its own, so that
  /// everything keyed to a column — the highlight, the scroll, the cursor —
  /// keeps meaning the same thing while a passage plays.
  /// - Parameter range: The bars, or `nil` for all of them.
  /// - Returns: The columns those bars occupy.
  public func columns(in range: PracticeRange?) -> Range<Int> {
    guard let range else { return 0..<columns.count }

    let inside = columns.indices.filter { range.judges(bar: measureNumber(atColumn: $0)) }
    guard let first = inside.first, let last = inside.last else { return 0..<0 }

    return first..<(last + 1)
  }

  /// How many bars the player can choose between.
  public var measureCount: Int {
    max(rightHand.measures.count - (hasPickup ? 1 : 0), 1)
  }
}

/// What is being worked at right now.
///
/// Studying a passage is not only about what is judged: hearing the whole piece
/// while working at four bars of it is not a reference for those four bars.
public struct Study: Equatable, Sendable {
  /// The bars, or `nil` for all of them.
  public let range: PracticeRange?

  /// Which hands.
  public let hands: PracticeHands

  /// Creates a study.
  /// - Parameters:
  ///   - range: The bars, or `nil` for the whole piece.
  ///   - hands: Which hands are being worked at.
  public init(range: PracticeRange?, hands: PracticeHands) {
    self.range = range
    self.hands = hands
  }

  /// Whether nothing has been narrowed down yet.
  public var isWholePiece: Bool { range == nil && hands == .both }

  /// What the listen button says, which is what it will play.
  public var listenTitle: String {
    switch (range, hands) {
    case (nil, .both): return "Ouvir a peça"
    case (let bars?, .both): return "Ouvir \(bars.spoken)"
    case (nil, let hands): return "Ouvir a \(hands.spoken)"
    case (let bars?, let hands): return "Ouvir \(bars.spoken), \(hands.spoken)"
    }
  }

}

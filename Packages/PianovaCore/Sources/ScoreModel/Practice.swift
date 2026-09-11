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

  /// How it is written out for the player.
  public var label: String {
    count == 1 ? "Compasso \(first)" : "Compassos \(first)–\(last)"
  }
}

extension Score {
  /// The piece reduced to what is being studied.
  ///
  /// Re-engraved rather than cropped on screen: the passage becomes a score of
  /// its own, so it keeps its clef, its key and its bar numbers, and everything
  /// downstream — cursor, timemap, preview — works on it unchanged.
  ///
  /// - Parameters:
  ///   - range: The bars to keep, or `nil` for the whole piece.
  ///   - hands: Which staves to keep.
  /// - Returns: The passage as a piece.
  public func extracting(_ range: PracticeRange?, hands: PracticeHands = .both) -> Score {
    let upper = hands == .left ? nil : slice(rightHand, to: range)
    let lower = hands == .right ? nil : leftHand.flatMap { slice($0, to: range) }

    // Studying the left hand alone must still give a piece, so whichever staff
    // survives becomes the one that is read.
    guard let played = upper ?? lower else { return self }

    return Score(
      title: title,
      composer: composer,
      timeSignature: timeSignature,
      key: key,
      rightHand: played,
      leftHand: upper == nil ? nil : lower,
      // A passage that does not start at the beginning has no upbeat: the
      // first bar of it is a whole bar of music.
      hasPickup: hasPickup && (range?.first ?? 1) <= 1)
  }

  /// One staff, cut to the bars asked for.
  private func slice(_ part: Part, to range: PracticeRange?) -> Part? {
    guard let range else { return part }

    // Bar numbers are what the player sees, and an upbeat is not numbered — so
    // they are turned back into positions before anything is cut.
    let offset = hasPickup ? 1 : 0
    let from = max(range.first - 1 + offset, 0)
    let through = min(range.last - 1 + offset, part.measures.count - 1)
    guard from <= through else { return nil }

    return Part(clef: part.clef, measures: Array(part.measures[from...through]))
  }

  /// How many bars the player can choose between.
  public var measureCount: Int {
    max(rightHand.measures.count - (hasPickup ? 1 : 0), 1)
  }
}

import ScoreModel

/// One step of an exercise: the pitches that must sound together to clear it.
public struct ExerciseItem: Equatable, Sendable {
  /// The pitches required to complete this item.
  public let pitches: Set<Pitch>

  /// Creates an item from pitches that must be played simultaneously.
  /// - Parameter pitches: The pitches required to complete the item.
  public init(pitches: Set<Pitch>) {
    self.pitches = pitches
  }

  /// Creates a single-note item.
  /// - Parameter pitch: The pitch required to complete the item.
  public init(_ pitch: Pitch) {
    self.pitches = [pitch]
  }
}

/// An ordered sequence of items, played from the first to the last.
public struct Exercise: Equatable, Sendable {
  /// The items, in the order they must be played.
  public let items: [ExerciseItem]

  /// Creates an exercise.
  /// - Parameter items: The items, in playing order.
  public init(items: [ExerciseItem]) {
    self.items = items
  }
}

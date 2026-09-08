import ScoreModel

/// Something the player can be asked about, tracked over time.
public enum ReviewKey: Hashable, Codable, Sendable {
  /// Reading one note on one staff. The same pitch in another clef is a
  /// different thing to learn, so the clef is part of the key.
  case note(midi: UInt8, clef: Clef)

  /// One theory question, by identifier.
  case theory(String)
}

/// How well one item is known, and when it should come back.
///
/// A Leitner ladder: each correct answer moves the item up a box and pushes it
/// further into the future; a miss drops it to the bottom and brings it back
/// the same day. Simple, and it is the part that turns drilling into learning —
/// an item you keep missing keeps returning, and one you know stops wasting
/// your time.
public struct ReviewItem: Codable, Equatable, Sendable {
  /// Days until an item in each box is due again.
  ///
  /// Widening gaps: seen today, tomorrow, in two days, four, eight, sixteen.
  public static let intervals = [0, 1, 2, 4, 8, 16]

  /// What is being reviewed.
  public let key: ReviewKey

  /// Which box it is in, from 0 to the last interval.
  public private(set) var box: Int

  /// The day it becomes due again.
  public private(set) var dueDay: Int

  /// How many times it has been answered.
  public private(set) var seenCount: Int

  /// How many times it has been missed.
  public private(set) var missCount: Int

  /// Creates a fresh item, due immediately.
  /// - Parameters:
  ///   - key: What is being reviewed.
  ///   - dueDay: The day it is first due.
  public init(key: ReviewKey, dueDay: Int = 0) {
    self.key = key
    box = 0
    self.dueDay = dueDay
    seenCount = 0
    missCount = 0
  }

  /// Records an answer.
  /// - Parameters:
  ///   - wasCorrect: Whether it was answered correctly.
  ///   - today: The current day number.
  public mutating func record(wasCorrect: Bool, today: Int) {
    seenCount += 1

    guard wasCorrect else {
      missCount += 1
      box = 0
      dueDay = today
      return
    }

    box = min(box + 1, Self.intervals.count - 1)
    dueDay = today + Self.intervals[box]
  }

  /// Whether it should be asked today.
  /// - Parameter today: The current day number.
  /// - Returns: `true` when it is due.
  public func isDue(on today: Int) -> Bool { dueDay <= today }

  /// How shaky the item looks, from 0 to 1.
  ///
  /// Used to order practice: the weakest come first.
  public var weakness: Double {
    guard seenCount > 0 else { return 1 }
    let missRate = Double(missCount) / Double(seenCount)
    let boxRelief = Double(box) / Double(Self.intervals.count - 1)
    return max(0, min(1, missRate * 0.7 + (1 - boxRelief) * 0.3))
  }
}

/// Everything the player has been asked, and how it went.
public struct ReviewLog: Codable, Equatable, Sendable {
  private var items: [ReviewItem]

  /// Creates an empty log.
  public init() {
    items = []
  }

  /// Every tracked item.
  public var all: [ReviewItem] { items }

  /// The record for one key, if it has ever been asked.
  /// - Parameter key: What to look up.
  /// - Returns: Its record, or `nil`.
  public func item(for key: ReviewKey) -> ReviewItem? {
    items.first { $0.key == key }
  }

  /// Records an answer, creating the record if this is the first time.
  /// - Parameters:
  ///   - key: What was asked.
  ///   - wasCorrect: Whether it was answered correctly.
  ///   - today: The current day number.
  public mutating func record(_ key: ReviewKey, wasCorrect: Bool, today: Int) {
    if let index = items.firstIndex(where: { $0.key == key }) {
      items[index].record(wasCorrect: wasCorrect, today: today)
    } else {
      var item = ReviewItem(key: key, dueDay: today)
      item.record(wasCorrect: wasCorrect, today: today)
      items.append(item)
    }
  }

  /// Keys that are due today, weakest first.
  /// - Parameter today: The current day number.
  /// - Returns: The due keys, in the order they should be practised.
  public func dueKeys(on today: Int) -> [ReviewKey] {
    items.filter { $0.isDue(on: today) }
      .sorted { $0.weakness > $1.weakness }
      .map(\.key)
  }

  /// Orders candidates for practice: never-seen first, then due weakest-first,
  /// then everything else.
  ///
  /// A candidate the player has never met outranks revision, because meeting it
  /// is what creates the record in the first place.
  /// - Parameters:
  ///   - candidates: Everything the exercise could ask.
  ///   - today: The current day number.
  /// - Returns: The candidates, in the order they should be asked.
  public func prioritise(_ candidates: [ReviewKey], on today: Int) -> [ReviewKey] {
    let unseen = candidates.filter { item(for: $0) == nil }
    let due =
      candidates
      .compactMap { key in item(for: key).map { (key, $0) } }
      .filter { $0.1.isDue(on: today) }
      .sorted { $0.1.weakness > $1.1.weakness }
      .map(\.0)
    let rest =
      candidates
      .compactMap { key in item(for: key).map { (key, $0) } }
      .filter { !$0.1.isDue(on: today) }
      .sorted { $0.1.dueDay < $1.1.dueDay }
      .map(\.0)

    return unseen + due + rest
  }
}

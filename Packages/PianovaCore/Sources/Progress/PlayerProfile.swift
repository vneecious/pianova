import Foundation

/// Everything the app remembers about the player between sessions.
///
/// Without this the app is an exerciser: it drills you and forgets. With it,
/// what you personally keep missing comes back on its own.
public struct PlayerProfile: Codable, Equatable, Sendable {
  /// Identifiers of lessons already cleared.
  public var completedLessonIDs: Set<String>

  /// What has been asked, and how it went.
  public var reviews: ReviewLog

  /// Longest clean run in the endless drill.
  public var bestDrillStreak: Int

  /// Day numbers on which the player practised.
  public private(set) var practiceDays: Set<Int>

  /// Creates an empty profile.
  public init() {
    completedLessonIDs = []
    reviews = ReviewLog()
    bestDrillStreak = 0
    practiceDays = []
  }

  /// Records that the player practised today.
  /// - Parameter today: The current day number.
  public mutating func markPractised(on today: Int) {
    practiceDays.insert(today)
  }

  /// How many days in a row have been practised, counting back from today.
  ///
  /// Practice works when it is short and daily, so the streak is the number
  /// worth showing — not the total.
  /// - Parameter today: The current day number.
  /// - Returns: The unbroken run, ending today or yesterday.
  public func streak(on today: Int) -> Int {
    guard practiceDays.contains(today) || practiceDays.contains(today - 1) else { return 0 }

    var day = practiceDays.contains(today) ? today : today - 1
    var length = 0
    while practiceDays.contains(day) {
      length += 1
      day -= 1
    }
    return length
  }

  /// How many days the player has practised in all.
  public var totalPracticeDays: Int { practiceDays.count }
}

/// Where a profile is kept.
public protocol ProfileStore: Sendable {
  /// Loads the stored profile, or a fresh one if there is none.
  func load() -> PlayerProfile

  /// Saves the profile.
  /// - Parameter profile: What to store.
  func save(_ profile: PlayerProfile)
}

/// A profile stored as JSON in the app's support directory.
public struct FileProfileStore: ProfileStore {
  private let url: URL

  /// Creates a store at the app's usual location.
  /// - Parameter fileName: Name of the file to use.
  public init(fileName: String = "profile.json") {
    let base =
      FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first ?? URL(fileURLWithPath: NSTemporaryDirectory())

    let folder = base.appendingPathComponent("Pianova", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    url = folder.appendingPathComponent(fileName)
  }

  /// Creates a store at an explicit location, for tests.
  /// - Parameter url: Where to read and write.
  public init(url: URL) {
    self.url = url
  }

  /// Reads the stored profile, or a fresh one when there is nothing to read.
  /// - Returns: The profile.
  public func load() -> PlayerProfile {
    guard let data = try? Data(contentsOf: url),
      let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data)
    else { return PlayerProfile() }

    return profile
  }

  /// Writes the profile, atomically so a crash cannot leave it half written.
  /// - Parameter profile: What to store.
  public func save(_ profile: PlayerProfile) {
    guard let data = try? JSONEncoder().encode(profile) else { return }
    try? data.write(to: url, options: .atomic)
  }
}

/// Turns dates into the day numbers the review schedule counts in.
///
/// Whole days, not timestamps: a review due "in two days" should not depend on
/// the hour at which it was answered.
public enum PracticeDay {
  /// The day number for a date.
  /// - Parameters:
  ///   - date: The moment to convert.
  ///   - calendar: The calendar to count in.
  /// - Returns: Days since the reference date, in whole local days.
  public static func number(for date: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: date)
    return Int(start.timeIntervalSinceReferenceDate / 86_400)
  }
}

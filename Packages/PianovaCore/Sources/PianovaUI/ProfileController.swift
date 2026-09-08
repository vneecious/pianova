import Course
import Foundation
import Progress
import ScoreModel
import SwiftUI

/// The player's memory: what is done, what is shaky, how often they practise.
///
/// Every answer in the app passes through here, so what you personally keep
/// missing comes back on its own instead of being drilled once and forgotten.
@MainActor
public final class ProfileController: ObservableObject {
  /// What the app remembers.
  @Published public private(set) var profile: PlayerProfile

  private let store: ProfileStore

  /// Creates a controller over a store.
  /// - Parameter store: Where the profile lives.
  public init(store: ProfileStore = FileProfileStore()) {
    self.store = store
    profile = store.load()
  }

  /// Today's day number.
  public var today: Int { PracticeDay.number(for: Date()) }

  /// Course progress as the trail sees it.
  /// - Parameter unlocksEverything: Whether to open every lesson for testing.
  /// - Returns: Progress built from what has been completed.
  public func courseProgress(unlocksEverything: Bool) -> CourseProgress {
    CourseProgress(
      completedIDs: profile.completedLessonIDs,
      unlocksEverything: unlocksEverything)
  }

  /// How many days in a row have been practised.
  public var streak: Int { profile.streak(on: today) }

  /// Records that a lesson was cleared.
  /// - Parameter lesson: The lesson completed.
  public func complete(_ lesson: Lesson) {
    profile.completedLessonIDs.insert(lesson.id)
    save()
  }

  /// Records reading one note on one staff.
  /// - Parameters:
  ///   - pitch: The note asked about.
  ///   - clef: The staff it was read on.
  ///   - wasCorrect: Whether it was answered correctly.
  public func recordNote(_ pitch: Pitch, clef: Clef, wasCorrect: Bool) {
    profile.reviews.record(
      .note(midi: pitch.midiNoteNumber, clef: clef), wasCorrect: wasCorrect, today: today)
    touch()
  }

  /// Records answering one theory question.
  /// - Parameters:
  ///   - questionID: Which question.
  ///   - wasCorrect: Whether it was answered correctly.
  public func recordTheory(_ questionID: String, wasCorrect: Bool) {
    profile.reviews.record(.theory(questionID), wasCorrect: wasCorrect, today: today)
    touch()
  }

  /// Records a drill run, keeping the best streak.
  /// - Parameter streak: The longest clean run of that session.
  public func recordDrillStreak(_ streak: Int) {
    guard streak > profile.bestDrillStreak else { return }
    profile.bestDrillStreak = streak
    save()
  }

  /// Orders what an exercise could ask, weakest and unseen first.
  /// - Parameter candidates: Everything on offer.
  /// - Returns: The same items, in the order worth practising.
  public func prioritise(_ candidates: [ReviewKey]) -> [ReviewKey] {
    profile.reviews.prioritise(candidates, on: today)
  }

  /// How shaky an item looks, from 0 to 1.
  /// - Parameter key: What to look up.
  /// - Returns: Its weakness, or 1 if never seen.
  public func weakness(of key: ReviewKey) -> Double {
    profile.reviews.item(for: key)?.weakness ?? 1
  }

  private func touch() {
    profile.markPractised(on: today)
    save()
  }

  private func save() {
    store.save(profile)
  }
}

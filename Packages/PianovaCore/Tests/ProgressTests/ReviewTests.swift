import Foundation
import ScoreModel
import Testing

@testable import Progress

private let middleCTreble = ReviewKey.note(midi: 60, clef: .treble)
private let middleCBass = ReviewKey.note(midi: 60, clef: .bass)

/// The same pitch in another clef is a different thing to learn.
@Test func theSamePitchInAnotherClefIsADifferentItem() {
  #expect(middleCTreble != middleCBass)
}

/// A fresh item is due at once.
@Test func aFreshItemIsDueAtOnce() {
  let item = ReviewItem(key: middleCTreble)

  #expect(item.isDue(on: 0))
  #expect(item.box == 0)
  #expect(item.seenCount == 0)
}

/// Each correct answer pushes the item further into the future.
@Test func correctAnswersWidenTheGap() {
  var item = ReviewItem(key: middleCTreble)

  item.record(wasCorrect: true, today: 0)
  let first = item.dueDay

  item.record(wasCorrect: true, today: first)
  let second = item.dueDay

  #expect(first == 1)
  #expect(second > first + 1)
  #expect(item.box == 2)
}

/// A miss drops the item to the bottom and brings it back today.
@Test func aMissBringsTheItemStraightBack() {
  var item = ReviewItem(key: middleCTreble)
  item.record(wasCorrect: true, today: 0)
  item.record(wasCorrect: true, today: 1)

  item.record(wasCorrect: false, today: 3)

  #expect(item.box == 0)
  #expect(item.dueDay == 3)
  #expect(item.isDue(on: 3))
  #expect(item.missCount == 1)
}

/// The ladder has a top: an item well known does not schedule forever out.
@Test func theLadderHasATop() {
  var item = ReviewItem(key: middleCTreble)
  var day = 0

  for _ in 0..<20 {
    item.record(wasCorrect: true, today: day)
    day = item.dueDay
  }

  #expect(item.box == ReviewItem.intervals.count - 1)
  #expect(item.dueDay - day == 0)
}

/// An item never seen counts as completely unknown.
@Test func anUnseenItemIsFullyWeak() {
  #expect(ReviewItem(key: middleCTreble).weakness == 1)
}

/// Missing an item makes it look weaker than one always answered right.
@Test func missesMakeAnItemLookWeaker() {
  var missed = ReviewItem(key: middleCTreble)
  var known = ReviewItem(key: middleCBass)

  missed.record(wasCorrect: false, today: 0)
  missed.record(wasCorrect: false, today: 0)
  known.record(wasCorrect: true, today: 0)
  known.record(wasCorrect: true, today: 1)

  #expect(missed.weakness > known.weakness)
}

/// The log creates a record the first time something is asked.
@Test func theLogRemembersTheFirstAnswer() {
  var log = ReviewLog()

  log.record(middleCTreble, wasCorrect: true, today: 0)

  #expect(log.item(for: middleCTreble)?.seenCount == 1)
  #expect(log.item(for: middleCBass) == nil)
}

/// Answers accumulate on the same record.
@Test func answersAccumulate() {
  var log = ReviewLog()

  log.record(middleCTreble, wasCorrect: true, today: 0)
  log.record(middleCTreble, wasCorrect: false, today: 1)

  #expect(log.item(for: middleCTreble)?.seenCount == 2)
  #expect(log.item(for: middleCTreble)?.missCount == 1)
  #expect(log.all.count == 1)
}

/// Due items come back weakest first.
@Test func dueItemsComeBackWeakestFirst() {
  var log = ReviewLog()
  log.record(middleCTreble, wasCorrect: false, today: 0)
  log.record(middleCBass, wasCorrect: true, today: 0)

  let due = log.dueKeys(on: 0)

  #expect(due.first == middleCTreble)
}

/// What has never been asked comes before revision.
@Test func theUnseenComesBeforeRevision() {
  var log = ReviewLog()
  log.record(middleCTreble, wasCorrect: false, today: 0)

  let order = log.prioritise([middleCTreble, middleCBass], on: 0)

  #expect(order.first == middleCBass, "o que nunca foi visto deveria vir primeiro")
  #expect(order.count == 2)
}

/// What is not due yet sinks to the bottom, but is not dropped.
@Test func whatIsNotDueYetSinksButIsKept() {
  var log = ReviewLog()
  log.record(middleCTreble, wasCorrect: true, today: 0)
  log.record(middleCBass, wasCorrect: false, today: 0)

  let order = log.prioritise([middleCTreble, middleCBass], on: 0)

  #expect(order == [middleCBass, middleCTreble])
}

/// Practising on consecutive days builds a streak.
@Test func consecutiveDaysBuildAStreak() {
  var profile = PlayerProfile()

  profile.markPractised(on: 10)
  profile.markPractised(on: 11)
  profile.markPractised(on: 12)

  #expect(profile.streak(on: 12) == 3)
  #expect(profile.totalPracticeDays == 3)
}

/// A missed day breaks the streak.
@Test func aMissedDayBreaksTheStreak() {
  var profile = PlayerProfile()

  profile.markPractised(on: 10)
  profile.markPractised(on: 12)

  #expect(profile.streak(on: 12) == 1)
}

/// Yesterday still counts, so the streak survives until the day is over.
@Test func yesterdayStillCounts() {
  var profile = PlayerProfile()

  profile.markPractised(on: 9)
  profile.markPractised(on: 10)

  #expect(profile.streak(on: 11) == 2)
  #expect(profile.streak(on: 12) == 0)
}

/// A profile survives a round trip through storage.
@Test func aProfileSurvivesStorage() throws {
  let url = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pianova-test-\(UUID().uuidString).json")
  let store = FileProfileStore(url: url)

  var profile = PlayerProfile()
  profile.completedLessonIDs = ["a-staff", "a-clefs"]
  profile.bestDrillStreak = 12
  profile.markPractised(on: 42)
  profile.reviews.record(middleCTreble, wasCorrect: false, today: 42)

  store.save(profile)
  let loaded = store.load()

  #expect(loaded == profile)
  #expect(loaded.reviews.item(for: middleCTreble)?.missCount == 1)

  try? FileManager.default.removeItem(at: url)
}

/// With nothing stored, the app starts fresh instead of failing.
@Test func nothingStoredMeansAFreshStart() {
  let url = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pianova-missing-\(UUID().uuidString).json")

  #expect(FileProfileStore(url: url).load() == PlayerProfile())
}

/// Day numbers count whole days, so the hour of practice never matters.
@Test func dayNumbersIgnoreTheHour() {
  let calendar = Calendar(identifier: .gregorian)
  let morning = Date(timeIntervalSinceReferenceDate: 800_000_000)
  let evening = morning.addingTimeInterval(60 * 60 * 8)

  #expect(
    PracticeDay.number(for: morning, calendar: calendar)
      == PracticeDay.number(for: evening, calendar: calendar))
}

/// Consecutive days really are consecutive numbers.
@Test func consecutiveDatesGiveConsecutiveNumbers() {
  let calendar = Calendar(identifier: .gregorian)
  let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
  let next = day.addingTimeInterval(86_400)

  #expect(
    PracticeDay.number(for: next, calendar: calendar)
      - PracticeDay.number(for: day, calendar: calendar) == 1)
}

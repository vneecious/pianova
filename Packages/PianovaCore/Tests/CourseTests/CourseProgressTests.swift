import ScoreModel
import Testing

@testable import Course

/// The course starts with its first lesson open and nothing else.
@Test func onlyTheFirstLessonStartsUnlocked() {
  let progress = CourseProgress()

  #expect(progress.isUnlocked(at: 0))
  #expect(progress.isUnlocked(at: 1) == false)
  #expect(progress.isUnlocked(at: 2) == false)
}

/// Clearing a lesson opens the next one.
@Test func clearingALessonUnlocksTheNext() {
  var progress = CourseProgress()

  progress.complete(Course.lessons[0])

  #expect(progress.isUnlocked(at: 1))
  #expect(progress.isUnlocked(at: 2) == false)
}

/// A cleared lesson stays open, so it can be replayed for practice.
@Test func clearedLessonsStayOpen() {
  var progress = CourseProgress()

  progress.complete(Course.lessons[0])
  progress.complete(Course.lessons[1])

  #expect(progress.isUnlocked(at: 0))
  #expect(progress.isUnlocked(at: 1))
  #expect(progress.isCompleted(Course.lessons[0]))
}

/// The current lesson is the first one not yet cleared.
@Test func theCurrentLessonIsTheFirstUnclearedOne() {
  var progress = CourseProgress()

  #expect(progress.currentIndex == 0)

  progress.complete(Course.lessons[0])
  #expect(progress.currentIndex == 1)

  progress.complete(Course.lessons[1])
  #expect(progress.currentIndex == 2)
}

/// Clearing the same lesson twice changes nothing.
@Test func clearingTwiceIsHarmless() {
  var progress = CourseProgress()

  progress.complete(Course.lessons[0])
  progress.complete(Course.lessons[0])

  #expect(progress.completedIDs.count == 1)
  #expect(progress.currentIndex == 1)
}

/// Indexes outside the course are never unlocked.
@Test func indexesOutsideTheCourseAreNeverUnlocked() {
  let progress = CourseProgress(completedIDs: Set(Course.lessons.map(\.id)))

  #expect(progress.isUnlocked(at: -1) == false)
  #expect(progress.isUnlocked(at: Course.lessons.count) == false)
}

/// Finishing everything leaves the current index on the last lesson rather
/// than running off the end.
@Test func finishingEverythingStaysOnTheLastLesson() {
  let progress = CourseProgress(completedIDs: Set(Course.lessons.map(\.id)))

  #expect(progress.currentIndex == Course.lessons.count - 1)
}

/// The development switch opens every lesson at once.
@Test func unlockingEverythingOpensTheWholeCourse() {
  let progress = CourseProgress(unlocksEverything: true)

  #expect(Course.lessons.indices.allSatisfy { progress.isUnlocked(at: $0) })
}

/// Opening everything does not pretend anything was earned.
///
/// The trail still shows what was actually cleared, so turning the switch off
/// leaves real progress intact.
@Test func unlockingEverythingMarksNothingAsCompleted() {
  let progress = CourseProgress(unlocksEverything: true)

  #expect(progress.completedIDs.isEmpty)
  #expect(Course.lessons.allSatisfy { !progress.isCompleted($0) })
  #expect(progress.currentIndex == 0)
}

/// Even with everything open, indexes outside the course stay closed.
@Test func unlockingEverythingStillRejectsBadIndexes() {
  let progress = CourseProgress(unlocksEverything: true)

  #expect(progress.isUnlocked(at: -1) == false)
  #expect(progress.isUnlocked(at: Course.lessons.count) == false)
}

/// Turning the switch off restores the normal gating.
@Test func turningTheSwitchOffRestoresGating() {
  var progress = CourseProgress(unlocksEverything: true)

  progress.unlocksEverything = false

  #expect(progress.isUnlocked(at: 0))
  #expect(progress.isUnlocked(at: 1) == false)
}

/// Lesson identifiers are unique, since completion is recorded by identifier.
@Test func lessonIdentifiersAreUnique() {
  #expect(Set(Course.lessons.map(\.id)).count == Course.lessons.count)
}

/// Every lesson has at least one activity.
@Test func everyLessonHasSteps() {
  #expect(Course.lessons.allSatisfy { !$0.steps.isEmpty })
}

/// Songs are melodies, not empty placeholders.
@Test func songsHaveNotes() {
  #expect(Songs.odeToJoy.melody.count > 20)
  #expect(Songs.twinkle.melody.isEmpty == false)
  #expect(Songs.frereJacques.melody.isEmpty == false)
}

/// Ode to Joy opens on its familiar repeated E.
@Test func odeToJoyOpensOnRepeatedE() {
  #expect(Songs.odeToJoy.melody.prefix(4).map(\.midiNoteNumber) == [64, 64, 65, 67])
}

/// Beginner songs stay inside a five-finger position from middle C.
@Test func beginnerSongsStayInFiveFingerPosition() {
  for song in [Songs.twinkle, Songs.frereJacques] {
    #expect(song.melody.allSatisfy { $0.midiNoteNumber >= 60 })
  }
  #expect(Songs.frereJacques.melody.allSatisfy { $0.midiNoteNumber <= 67 })
}

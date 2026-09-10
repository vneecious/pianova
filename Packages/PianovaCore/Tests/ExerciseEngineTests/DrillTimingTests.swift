import Foundation
import ScoreModel
import Testing

@testable import ExerciseEngine

// MARK: - Rule 55: the median, never the mean

/// Rule 55 — one distraction destroys a mean and leaves a median alone.
///
/// This is the whole reason the median was chosen, so it is worth stating as a
/// test rather than only as a comment.
@Test func oneSlowAnswerDoesNotMoveTheMedian() {
  var timing = DrillTiming()
  for seconds in [1.0, 1.1, 0.9, 1.0, 40.0] {
    timing.record(seconds: seconds, pitch: Pitch(60))
  }

  let mean = timing.samples.reduce(0, +) / Double(timing.samples.count)

  #expect(timing.median == 1.0)
  #expect(mean > 8, "a média deveria estar arruinada, e é por isso que não a usamos")
}

/// An even count averages the two middle values.
@Test func anEvenCountAveragesTheMiddle() {
  var timing = DrillTiming()
  for seconds in [1.0, 2.0, 3.0, 4.0] { timing.record(seconds: seconds, pitch: Pitch(60)) }

  #expect(timing.median == 2.5)
}

/// Nothing answered yet is not zero: it is nothing.
@Test func anEmptyRecordHasNoMedian() {
  #expect(DrillTiming().median == nil)
  #expect(DrillTiming().hesitations().isEmpty)
}

/// Rule 59 — a time that makes no sense is not recorded.
@Test func nonsenseTimesAreRefused() {
  var timing = DrillTiming()
  timing.record(seconds: 0, pitch: Pitch(60))
  timing.record(seconds: -3, pitch: Pitch(60))

  #expect(timing.samples.isEmpty)
}

// MARK: - Rule 59: only clean answers are timed

/// Rule 59 — an answer that already went wrong is not timed.
@Test func aWrongAnswerIsNeverTimed() {
  var stats = DrillStats()
  stats.record(wasClean: false, seconds: 2, style: .staff, pitch: Pitch(60))

  #expect(stats.answered == 1)
  #expect(stats.timings[.staff]?.samples.isEmpty ?? true)
}

/// A clean answer is timed, under its own style.
@Test func aCleanAnswerIsTimedUnderItsStyle() {
  var stats = DrillStats()
  stats.record(wasClean: true, seconds: 1.5, style: .staff, pitch: Pitch(60))

  #expect(stats.timings[.staff]?.median == 1.5)
  #expect(stats.timings[.ear] == nil)
}

// MARK: - Rule 56: statistics per prompt style

/// Rule 56 — reading and ear training never share a number.
///
/// They measure different skills, and in an ear exercise speed is not even the
/// goal, so one combined median would be meaningless.
@Test func stylesAreCountedSeparately() {
  var stats = DrillStats()
  stats.record(wasClean: true, seconds: 1.0, style: .staff, pitch: Pitch(60))
  stats.record(wasClean: true, seconds: 9.0, style: .ear, pitch: Pitch(60))

  #expect(stats.timings[.staff]?.median == 1.0)
  #expect(stats.timings[.ear]?.median == 9.0)
}

// MARK: - Rule 57: where the hesitation is

/// Rule 57 — the slowest notes come first.
@Test func hesitationsAreOrderedSlowestFirst() {
  var timing = DrillTiming()
  for _ in 0..<2 { timing.record(seconds: 0.8, pitch: Pitch(60)) }
  for _ in 0..<2 { timing.record(seconds: 4.0, pitch: Pitch(71)) }
  for _ in 0..<2 { timing.record(seconds: 2.0, pitch: Pitch(65)) }

  #expect(timing.hesitations().map(\.pitch.midiNoteNumber) == [71, 65, 60])
}

/// A note answered once is not yet evidence of anything.
@Test func aSingleAnswerIsNotAHesitation() {
  var timing = DrillTiming()
  timing.record(seconds: 9.0, pitch: Pitch(71))

  #expect(timing.hesitations().isEmpty)
  #expect(timing.hesitations(minimumSamples: 1).count == 1)
}

/// Each note keeps its own median.
@Test func eachNoteKeepsItsOwnMedian() {
  var timing = DrillTiming()
  for seconds in [1.0, 3.0] { timing.record(seconds: seconds, pitch: Pitch(60)) }

  #expect(timing.median(for: Pitch(60)) == 2.0)
  #expect(timing.median(for: Pitch(62)) == nil)
}

// MARK: - Rule 58: the loop closes

/// Rule 58 — a hesitated note really does get asked about more.
///
/// This is the thing a separate stopwatch cannot do: it shows you the list and
/// leaves the work to you.
@Test func hesitatedNotesAreAskedAboutMore() {
  let settings = DrillSettings(difficulty: .easy, usesTreble: true, usesBass: false, style: .staff)
  let target = Pitch(64)

  var withFocus = 0
  var without = 0

  for seed in UInt64(1)...UInt64(400) {
    var a = SeededGenerator(seed: seed)
    var b = SeededGenerator(seed: seed)

    let focused = DrillGenerator.next(settings: settings, hesitations: [target], using: &a)
    let plain = DrillGenerator.next(settings: settings, using: &b)

    withFocus += focused.pitches.filter { $0 == target }.count
    without += plain.pitches.filter { $0 == target }.count
  }

  #expect(withFocus > without, "a nota hesitada deveria aparecer mais: \(withFocus) vs \(without)")
}

/// Pushing at a note outside the drill's range changes nothing.
@Test func aHesitationOutsideTheRangeIsIgnored() {
  let settings = DrillSettings(difficulty: .easy, usesTreble: true, usesBass: false, style: .staff)

  var a = SeededGenerator(seed: 7)
  var b = SeededGenerator(seed: 7)

  let focused = DrillGenerator.next(settings: settings, hesitations: [Pitch(24)], using: &a)
  let plain = DrillGenerator.next(settings: settings, using: &b)

  #expect(focused.pitches == plain.pitches)
}

/// A repeatable generator, so the comparison above is fair.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1 }

  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

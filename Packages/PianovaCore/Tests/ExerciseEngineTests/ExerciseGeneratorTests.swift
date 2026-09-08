import ScoreModel
import Testing

@testable import ExerciseEngine

/// Deterministic randomness, so generator tests do not flake.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

/// The C major scale, one octave up from middle C.
private let scale = [60, 62, 64, 65, 67, 69, 71, 72].map { Pitch(UInt8($0)) }

/// The exercise has exactly as many notes as asked for.
@Test func generatedExerciseHasTheRequestedLength() {
  var generator = SeededGenerator(seed: 1)

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 8, maxLeap: 2, using: &generator)

  #expect(exercise.items.count == 8)
}

/// Every note comes from the pool, so an exercise never asks for a key the
/// level does not cover.
@Test func generatedNotesComeFromThePool() {
  var generator = SeededGenerator(seed: 2)
  let pool = Set(scale)

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 20, maxLeap: 3, using: &generator)

  #expect(exercise.items.allSatisfy { item in item.pitches.allSatisfy { pool.contains($0) } })
}

/// Each item is a single note, not a chord.
@Test func generatedItemsAreSingleNotes() {
  var generator = SeededGenerator(seed: 3)

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 10, maxLeap: 2, using: &generator)

  #expect(exercise.items.allSatisfy { $0.pitches.count == 1 })
}

/// Consecutive notes stay close together, so a beginner exercise moves by
/// steps instead of leaping across the keyboard.
@Test func consecutiveNotesStayWithinTheLeapLimit() {
  var generator = SeededGenerator(seed: 4)
  let positions = Dictionary(uniqueKeysWithValues: scale.enumerated().map { ($1, $0) })

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 30, maxLeap: 2, using: &generator)

  let indices = exercise.items.compactMap { $0.pitches.first.flatMap { positions[$0] } }
  for (previous, next) in zip(indices, indices.dropFirst()) {
    #expect(abs(next - previous) <= 2)
  }
}

/// The same note never appears twice in a row.
@Test func generatedNotesNeverRepeatBackToBack() {
  var generator = SeededGenerator(seed: 5)

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 30, maxLeap: 2, using: &generator)

  for (previous, next) in zip(exercise.items, exercise.items.dropFirst()) {
    #expect(previous != next)
  }
}

/// A wider leap limit is allowed to produce wider intervals.
@Test func aWiderLeapLimitAllowsWiderIntervals() {
  var generator = SeededGenerator(seed: 6)
  let positions = Dictionary(uniqueKeysWithValues: scale.enumerated().map { ($1, $0) })

  let exercise = ExerciseGenerator.build(
    pitches: scale, length: 40, maxLeap: 4, using: &generator)

  let indices = exercise.items.compactMap { $0.pitches.first.flatMap { positions[$0] } }
  let widest = zip(indices, indices.dropFirst()).map { abs($1 - $0) }.max() ?? 0

  #expect(widest > 2)
  #expect(widest <= 4)
}

/// The same seed produces the same exercise.
@Test func sameSeedProducesTheSameExercise() {
  var first = SeededGenerator(seed: 7)
  var second = SeededGenerator(seed: 7)

  let a = ExerciseGenerator.build(pitches: scale, length: 10, maxLeap: 2, using: &first)
  let b = ExerciseGenerator.build(pitches: scale, length: 10, maxLeap: 2, using: &second)

  #expect(a == b)
}

/// An empty pool yields an empty exercise rather than looping forever.
@Test func anEmptyPoolYieldsAnEmptyExercise() {
  var generator = SeededGenerator(seed: 8)

  let exercise = ExerciseGenerator.build(
    pitches: [], length: 10, maxLeap: 2, using: &generator)

  #expect(exercise.items.isEmpty)
}

/// A pool with a single pitch cannot avoid repeats, so it yields one note.
@Test func aSinglePitchPoolYieldsOneNote() {
  var generator = SeededGenerator(seed: 9)

  let exercise = ExerciseGenerator.build(
    pitches: [Pitch(60)], length: 10, maxLeap: 2, using: &generator)

  #expect(exercise.items.count == 1)
}

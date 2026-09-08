import ScoreModel
import Testing

@testable import ExerciseEngine

/// Deterministic randomness, so generator tests do not flake.
private struct HarmonySeed: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

/// Two octaves of white keys from middle C.
private let pool = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84]
  .map { Pitch(UInt8($0)) }

private func harmony(voices: Int, length: Int = 12, seed: UInt64 = 1) -> Exercise {
  var generator = HarmonySeed(seed: seed)
  return ExerciseGenerator.buildHarmony(
    pitches: pool, length: length, voices: voices, using: &generator)
}

/// The sequence has as many groups as asked for.
@Test func harmonyHasTheRequestedLength() {
  #expect(harmony(voices: 2).items.count == 12)
}

/// Two voices sound together in every group.
@Test func twoVoicesGiveTwoNotesAtOnce() {
  #expect(harmony(voices: 2).items.allSatisfy { $0.pitches.count == 2 })
}

/// Three voices give a triad.
@Test func threeVoicesGiveATriad() {
  #expect(harmony(voices: 3).items.allSatisfy { $0.pitches.count == 3 })
}

/// Voices are stacked in thirds, which over natural notes is the diatonic
/// third methods teach first.
@Test func voicesAreStackedInThirds() {
  let positions = Dictionary(uniqueKeysWithValues: pool.enumerated().map { ($1, $0) })

  for item in harmony(voices: 3).items {
    let indices = item.pitches.compactMap { positions[$0] }.sorted()

    #expect(indices.count == 3)
    #expect(indices[1] - indices[0] == 2)
    #expect(indices[2] - indices[1] == 2)
  }
}

/// Every note comes from the pool.
@Test func harmonyNotesComeFromThePool() {
  let allowed = Set(pool)

  #expect(
    harmony(voices: 2).items
      .allSatisfy { item in
        item.pitches.allSatisfy { allowed.contains($0) }
      })
}

/// A single voice is just a melody, so the same call still works.
@Test func oneVoiceIsAPlainMelody() {
  #expect(harmony(voices: 1).items.allSatisfy { $0.pitches.count == 1 })
}

/// The same seed produces the same sequence.
@Test func sameSeedProducesTheSameHarmony() {
  #expect(harmony(voices: 3, seed: 5) == harmony(voices: 3, seed: 5))
}

/// A pool too small to stack the voices yields nothing rather than a broken
/// chord.
@Test func aPoolTooSmallToStackYieldsNothing() {
  var generator = HarmonySeed(seed: 6)
  let tiny = [Pitch(60), Pitch(62)]

  let exercise = ExerciseGenerator.buildHarmony(
    pitches: tiny, length: 5, voices: 3, using: &generator)

  #expect(exercise.items.isEmpty)
}

/// Asking for no groups yields nothing.
@Test func zeroLengthYieldsNothing() {
  #expect(harmony(voices: 2, length: 0).items.isEmpty)
}

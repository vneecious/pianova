import ScoreModel
import Testing

@testable import ExerciseEngine

/// Deterministic randomness, so drill tests do not flake.
private struct DrillGeneratorSeed: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

/// Draws a handful of prompts, so tests can look at behaviour over a run rather
/// than one lucky draw.
private func prompts(_ settings: DrillSettings, count: Int = 40, seed: UInt64 = 1) -> [DrillPrompt]
{
  var generator = DrillGeneratorSeed(seed: seed)
  return (0..<count).map { _ in DrillGenerator.next(settings: settings, using: &generator) }
}

/// Every prompt asks for at least one note.
@Test func everyPromptHasNotes() {
  #expect(prompts(DrillSettings()).allSatisfy { !$0.pitches.isEmpty })
}

/// Easy asks for one note at a time.
@Test func easyAsksForSingleNotes() {
  let settings = DrillSettings(difficulty: .easy)

  #expect(prompts(settings).allSatisfy { $0.pitches.count == 1 })
}

/// Harder settings ask for sequences, but never longer than they allow.
@Test func sequencesStayWithinTheDifficultyLimit() {
  for difficulty in DrillDifficulty.allCases {
    let settings = DrillSettings(difficulty: difficulty)
    let lengths = prompts(settings).map(\.pitches.count)

    #expect(lengths.allSatisfy { $0 >= 1 && $0 <= settings.maxSequenceLength })
  }
}

/// Medium really does produce sequences, not just single notes.
@Test func mediumProducesSequences() {
  let lengths = prompts(DrillSettings(difficulty: .medium)).map(\.pitches.count)

  #expect(lengths.contains { $0 > 1 })
}

/// Notes stay inside the range the difficulty defines for their clef.
@Test func notesStayInsideTheDifficultyRange() {
  for difficulty in DrillDifficulty.allCases {
    let settings = DrillSettings(difficulty: difficulty)

    for prompt in prompts(settings) {
      let range = settings.range(for: prompt.clef)
      #expect(prompt.pitches.allSatisfy { range.contains($0.midiNoteNumber) })
    }
  }
}

/// Turning a clef off keeps it out of the drill.
@Test func turningAClefOffKeepsItOut() {
  let trebleOnly = prompts(DrillSettings(usesTreble: true, usesBass: false))
  let bassOnly = prompts(DrillSettings(usesTreble: false, usesBass: true))

  #expect(trebleOnly.allSatisfy { $0.clef == .treble })
  #expect(bassOnly.allSatisfy { $0.clef == .bass })
}

/// With both clefs on, both really show up.
@Test func bothClefsAppearWhenBothAreOn() {
  let drawn = Set(prompts(DrillSettings()).map(\.clef))

  #expect(drawn == [.treble, .bass])
}

/// Turning both clefs off falls back to treble instead of asking nothing.
@Test func turningBothClefsOffFallsBackToTreble() {
  let settings = DrillSettings(usesTreble: false, usesBass: false)

  #expect(settings.clefs == [.treble])
  #expect(prompts(settings).allSatisfy { $0.clef == .treble })
}

/// A prompt is never handed back as `mixed`: the style is resolved first, so
/// the view always knows what to draw.
@Test func mixedIsResolvedIntoAConcreteStyle() {
  let drawn = prompts(DrillSettings(style: .mixed)).map(\.style)

  #expect(drawn.allSatisfy { $0 != .mixed })
  #expect(Set(drawn) == [.staff, .name, .ear])
}

/// A fixed style is respected.
@Test func aFixedStyleIsRespected() {
  #expect(prompts(DrillSettings(style: .staff)).allSatisfy { $0.style == .staff })
  #expect(prompts(DrillSettings(style: .name)).allSatisfy { $0.style == .name })
}

/// Ear prompts stay short: playing back a melody is memory, not hearing.
@Test func earPromptsStayShort() {
  for difficulty in DrillDifficulty.allCases {
    let settings = DrillSettings(difficulty: difficulty, style: .ear)
    let lengths = prompts(settings).map(\.pitches.count)

    #expect(lengths.allSatisfy { $0 <= settings.maxEarLength })
    #expect(settings.maxEarLength <= settings.maxSequenceLength)
  }
}

/// Easy and medium ask for a single note by ear.
@Test func easyEarPromptsAreSingleNotes() {
  for difficulty in [DrillDifficulty.easy, .medium] {
    let settings = DrillSettings(difficulty: difficulty, style: .ear)
    #expect(prompts(settings).allSatisfy { $0.pitches.count == 1 })
  }
}

/// A fixed ear style really only produces ear prompts.
@Test func aFixedEarStyleIsRespected() {
  #expect(prompts(DrillSettings(style: .ear)).allSatisfy { $0.style == .ear })
}

/// Only the hardest setting uses black keys.
@Test func onlyHardUsesBlackKeys() {
  for difficulty in [DrillDifficulty.easy, .medium] {
    let drawn = prompts(DrillSettings(difficulty: difficulty))
    #expect(drawn.allSatisfy { $0.pitches.allSatisfy { !$0.requiresSharp } })
  }

  let hard = prompts(DrillSettings(difficulty: .hard), count: 120)
  #expect(hard.contains { $0.pitches.contains { $0.requiresSharp } })
}

/// The same seed produces the same run, which is what makes these tests mean
/// anything.
@Test func sameSeedProducesTheSameRun() {
  #expect(prompts(DrillSettings(), seed: 9) == prompts(DrillSettings(), seed: 9))
}

/// Ranges widen as difficulty rises.
@Test func rangesWidenWithDifficulty() {
  for clef in [Clef.treble, .bass] {
    let easy = DrillSettings(difficulty: .easy).range(for: clef)
    let medium = DrillSettings(difficulty: .medium).range(for: clef)
    let hard = DrillSettings(difficulty: .hard).range(for: clef)

    #expect(medium.count > easy.count)
    #expect(hard.count > medium.count)
  }
}

/// A clean answer extends the streak.
@Test func cleanAnswersExtendTheStreak() {
  var stats = DrillStats()

  stats.record(wasClean: true)
  stats.record(wasClean: true)

  #expect(stats.streak == 2)
  #expect(stats.correct == 2)
  #expect(stats.answered == 2)
}

/// A mistake breaks the streak but keeps the best one.
@Test func aMistakeBreaksTheStreakButKeepsTheBest() {
  var stats = DrillStats()

  stats.record(wasClean: true)
  stats.record(wasClean: true)
  stats.record(wasClean: false)

  #expect(stats.streak == 0)
  #expect(stats.bestStreak == 2)
  #expect(stats.answered == 3)
  #expect(stats.correct == 2)
}

/// Accuracy is correct over answered, and safe before anything is answered.
@Test func accuracyIsSafeBeforeAnythingIsAnswered() {
  var stats = DrillStats()
  #expect(stats.accuracy == 0)

  stats.record(wasClean: true)
  stats.record(wasClean: false)

  #expect(stats.accuracy == 0.5)
}

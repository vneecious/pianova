import ScoreModel
import Testing

@testable import ExerciseEngine

/// Deterministic randomness, so generator tests do not flake.
private struct TwoHandsSeed: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private let right = [60, 62, 64, 65, 67].map { Pitch(UInt8($0)) }
private let left = [48, 50, 52, 53, 55].map { Pitch(UInt8($0)) }

private func twoHands(length: Int = 10, seed: UInt64 = 1) -> Exercise {
  var generator = TwoHandsSeed(seed: seed)
  return ExerciseGenerator.buildTwoHands(
    rightHand: right, leftHand: left, length: length, using: &generator)
}

/// The sequence has as many groups as asked for.
@Test func twoHandsHasTheRequestedLength() {
  #expect(twoHands().items.count == 10)
}

/// Each group asks for exactly two notes at once, one per hand.
@Test func eachGroupIsOneNotePerHand() {
  #expect(twoHands().items.allSatisfy { $0.pitches.count == 2 })
}

/// Every group takes one note from each pool, so both hands really play.
@Test func everyGroupDrawsFromBothHands() {
  let rightSet = Set(right)
  let leftSet = Set(left)

  for item in twoHands().items {
    #expect(item.pitches.filter { rightSet.contains($0) }.count == 1)
    #expect(item.pitches.filter { leftSet.contains($0) }.count == 1)
  }
}

/// The hands land on opposite sides of middle C, which is what makes the grand
/// staff split work.
@Test func theHandsLandOnOppositeStaves() {
  for item in twoHands().items {
    let clefs = Set(item.pitches.map(\.grandStaffClef))
    #expect(clefs == [.treble, .bass])
  }
}

/// The same seed produces the same sequence.
@Test func sameSeedProducesTheSameTwoHandsRun() {
  #expect(twoHands(seed: 4) == twoHands(seed: 4))
}

/// An empty hand yields nothing rather than a one-handed exercise pretending
/// to be for two.
@Test func anEmptyHandYieldsNothing() {
  var generator = TwoHandsSeed(seed: 5)

  let noLeft = ExerciseGenerator.buildTwoHands(
    rightHand: right, leftHand: [], length: 5, using: &generator)
  let noRight = ExerciseGenerator.buildTwoHands(
    rightHand: [], leftHand: left, length: 5, using: &generator)

  #expect(noLeft.items.isEmpty)
  #expect(noRight.items.isEmpty)
}

/// Asking for no groups yields nothing.
@Test func zeroLengthYieldsNoTwoHandedGroups() {
  #expect(twoHands(length: 0).items.isEmpty)
}

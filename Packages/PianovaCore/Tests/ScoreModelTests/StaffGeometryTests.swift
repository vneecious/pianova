import CoreGraphics
import Testing

@testable import ScoreModel

private let geometry = StaffGeometry(staffSpace: 20, bottomLineY: 200)

/// Step zero is the bottom line itself.
@Test func stepZeroSitsOnTheBottomLine() {
  #expect(geometry.y(for: 0) == 200)
}

/// Each step is half a space, so two steps is a full space upwards.
@Test func eachStepIsHalfASpace() {
  #expect(geometry.y(for: 1) == 190)
  #expect(geometry.y(for: 2) == 180)
}

/// Negative steps sit below the staff, further down the screen.
@Test func negativeStepsSitBelowTheStaff() {
  #expect(geometry.y(for: -2) == 220)
}

/// Hit testing the exact position of a step returns that step.
@Test func hitTestingAnExactPositionReturnsItsStep() {
  #expect(geometry.step(atY: 200) == 0)
  #expect(geometry.step(atY: 180) == 2)
  #expect(geometry.step(atY: 220) == -2)
}

/// README › Cards invertidos — rule 12: a tap snaps to the nearest step, so it
/// does not need to be precise.
@Test func hitTestingSnapsToTheNearestStep() {
  #expect(geometry.step(atY: 196) == 0)
  #expect(geometry.step(atY: 184) == 2)
  #expect(geometry.step(atY: 191) == 1)
}

/// A tap exactly between two steps resolves consistently rather than wobbling.
@Test func hitTestingAMidpointIsStable() {
  #expect(geometry.step(atY: 195) == geometry.step(atY: 195))
}

/// Positions round trip: turning a step into a point and back gives the step.
@Test func stepsRoundTripThroughPoints() {
  for step in -6...14 {
    #expect(geometry.step(atY: geometry.y(for: step)) == step)
  }
}

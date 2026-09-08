import CoreGraphics
import Testing

@testable import ScoreModel

private let geometry = StaffGeometry(staffSpace: 20, bottomLineY: 200)
private let steps = [-2, 0, 2, 4, 6]
private let firstX: CGFloat = 100
private let spacing: CGFloat = 50

private var positions: [CGPoint] {
  geometry.targetPositions(steps: steps, firstX: firstX, spacing: spacing)
}

/// Every step gets a target.
@Test func everyStepGetsATarget() {
  #expect(positions.count == steps.count)
}

/// Targets march to the right, one column each, so none sits directly above
/// another.
@Test func targetsMarchToTheRight() {
  let xs = positions.map(\.x)

  #expect(xs == [100, 150, 200, 250, 300])
  #expect(Set(xs).count == xs.count)
}

/// A target keeps the height of the line or space it stands for.
@Test func targetsKeepTheHeightOfTheirStep() {
  for (position, step) in zip(positions, steps) {
    #expect(position.y == geometry.y(for: step))
  }
}

/// Higher notes sit higher, so the staircase climbs as it goes right.
@Test func theStaircaseClimbsToTheRight() {
  let ys = positions.map(\.y)

  #expect(zip(ys, ys.dropFirst()).allSatisfy { $1 < $0 })
}

/// Tapping a target hits it.
@Test func tappingATargetHitsIt() {
  for (position, step) in zip(positions, steps) {
    let hit = geometry.nearestTarget(
      to: position, among: steps, firstX: firstX, spacing: spacing, maxDistance: 30)

    #expect(hit == step)
  }
}

/// A tap slightly off still hits the target it is closest to.
@Test func aTapSlightlyOffStillHits() {
  let hit = geometry.nearestTarget(
    to: CGPoint(x: 158, y: geometry.y(for: 0) + 6),
    among: steps, firstX: firstX, spacing: spacing, maxDistance: 30)

  #expect(hit == 0)
}

/// The separation is the point: a tap between two columns lands on the nearer
/// one rather than being ambiguous.
@Test func aTapBetweenColumnsResolvesToTheNearerOne() {
  let leftish = geometry.nearestTarget(
    to: CGPoint(x: 120, y: geometry.y(for: -2)),
    among: steps, firstX: firstX, spacing: spacing, maxDistance: 40)

  #expect(leftish == -2)
}

/// A tap far from every target answers nothing, so a stray touch does not
/// spend an answer.
@Test func aStrayTapHitsNothing() {
  let hit = geometry.nearestTarget(
    to: CGPoint(x: 600, y: 40),
    among: steps, firstX: firstX, spacing: spacing, maxDistance: 30)

  #expect(hit == nil)
}

/// With no targets on offer, nothing can be hit.
@Test func noTargetsMeansNoHit() {
  let hit = geometry.nearestTarget(
    to: CGPoint(x: 100, y: 200), among: [], firstX: firstX, spacing: spacing,
    maxDistance: 30)

  #expect(hit == nil)
}

/// Neighbouring targets stay at least a finger apart, which is the whole
/// reason for the staircase.
@Test func neighbouringTargetsStayAFingerApart() {
  let distances = zip(positions, positions.dropFirst())
    .map { first, second in
      hypot(second.x - first.x, second.y - first.y)
    }

  #expect(distances.allSatisfy { $0 >= 44 })
}

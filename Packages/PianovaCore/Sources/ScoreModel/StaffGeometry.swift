import CoreGraphics

/// Maps staff steps to vertical positions and back.
///
/// Pure geometry, kept out of the view so that hit testing a tap is testable
/// without rendering anything.
public struct StaffGeometry: Equatable, Sendable {
  /// Distance between two staff lines, in points.
  public let staffSpace: CGFloat

  /// Vertical position of the bottom staff line, in points.
  public let bottomLineY: CGFloat

  /// Creates a geometry.
  /// - Parameters:
  ///   - staffSpace: Distance between two staff lines, in points.
  ///   - bottomLineY: Vertical position of the bottom staff line.
  public init(staffSpace: CGFloat, bottomLineY: CGFloat) {
    self.staffSpace = staffSpace
    self.bottomLineY = bottomLineY
  }

  /// Vertical position of a staff step.
  /// - Parameter step: Half-spaces above the bottom line.
  /// - Returns: The y coordinate, measured downwards from the top.
  public func y(for step: Int) -> CGFloat {
    bottomLineY - CGFloat(step) * staffSpace / 2
  }

  /// The staff step nearest a vertical position.
  ///
  /// Rounds to the closest line or space, so a tap does not need to be precise.
  /// - Parameter y: The y coordinate, measured downwards from the top.
  /// - Returns: Half-spaces above the bottom line.
  public func step(atY y: CGFloat) -> Int {
    Int(((bottomLineY - y) / (staffSpace / 2)).rounded())
  }

  /// Where each tap target sits, laid out as a diagonal staircase.
  ///
  /// Steps are only half a staff space apart, which is far too tight for a
  /// finger. Giving each target its own column spreads them out without moving
  /// them off the line or space they belong to.
  /// - Parameters:
  ///   - steps: The steps to place, in ascending order.
  ///   - firstX: Centre of the first target.
  ///   - spacing: Horizontal distance between targets.
  /// - Returns: One point per step, in the same order.
  public func targetPositions(
    steps: [Int], firstX: CGFloat, spacing: CGFloat
  ) -> [CGPoint] {
    steps.enumerated()
      .map { index, step in
        CGPoint(x: firstX + CGFloat(index) * spacing, y: y(for: step))
      }
  }

  /// The target nearest a point, if the point is close enough to count.
  ///
  /// Taps beyond `maxDistance` answer nothing, so a stray touch on the staff
  /// does not spend an answer.
  /// - Parameters:
  ///   - point: Where the player tapped.
  ///   - steps: The steps on offer, in ascending order.
  ///   - firstX: Centre of the first target.
  ///   - spacing: Horizontal distance between targets.
  ///   - maxDistance: How far a tap may land and still count.
  /// - Returns: The step that was hit, or `nil` if none was close enough.
  public func nearestTarget(
    to point: CGPoint,
    among steps: [Int],
    firstX: CGFloat,
    spacing: CGFloat,
    maxDistance: CGFloat
  ) -> Int? {
    let positions = targetPositions(steps: steps, firstX: firstX, spacing: spacing)

    let closest = zip(steps, positions)
      .map { step, position in
        (step: step, distance: hypot(position.x - point.x, position.y - point.y))
      }
      .min { $0.distance < $1.distance }

    guard let closest, closest.distance <= maxDistance else { return nil }
    return closest.step
  }
}

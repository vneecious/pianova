import Foundation
import ScoreModel

/// What is being worked at on the piece currently open.
///
/// Held apart from the page because more than the page needs it: the title bar
/// says what is in study, the controls change it, the engraved view restricts
/// judging to it, and the preview plays it.
@MainActor
public final class StudySession: ObservableObject {
  /// The bars in study, or `nil` for the whole piece.
  @Published public private(set) var range: PracticeRange?

  /// Which hands are in study.
  @Published public var hands: PracticeHands = .both

  /// Whether the passage starts again on its own.
  @Published public var loops = true

  /// The bar the selection was anchored at.
  ///
  /// Kept so that a second tap moves the far end instead of starting over: a
  /// passage is picked at both ends, and losing the anchor means never being
  /// able to adjust one of them.
  private var anchor: Int?

  /// Creates an empty session: the whole piece, both hands.
  public init() {}

  /// Whether a passage is being picked out.
  public var isSelecting: Bool { range != nil }

  /// What is being studied right now.
  public var study: Study { Study(range: range, hands: hands) }

  /// Begins a selection at one bar, as holding a photo does.
  /// - Parameter bar: The bar held.
  public func begin(at bar: Int) {
    anchor = bar
    range = PracticeRange(first: bar, last: bar)
  }

  /// Stretches the selection to reach a bar, keeping everything in between.
  ///
  /// Does nothing outside selection: a tap on the page means "listen from here"
  /// until something has been held.
  /// - Parameter bar: The far end.
  public func extend(to bar: Int) {
    guard let anchor else { return }
    range = PracticeRange(first: anchor, last: bar)
  }

  /// Leaves the selection: the whole piece, both hands, as it was found.
  public func finish() {
    anchor = nil
    range = nil
    hands = .both
  }
}

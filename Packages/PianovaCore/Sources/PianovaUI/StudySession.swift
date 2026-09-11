import Foundation
import ScoreModel

/// What is being worked at on the piece currently open.
///
/// Three moments, like picking photos: browsing the whole piece; selecting,
/// begun by holding a bar; and studying, entered the moment the last bar of
/// the passage is tapped. Held apart from the page because more than the page
/// needs it — the title bar names it, the controls change it, the engraved
/// view judges by it, and the preview plays it.
@MainActor
public final class StudySession: ObservableObject {
  /// Where the player is: browsing, selecting a passage, or studying one.
  public enum Phase: Sendable {
    /// The whole piece, nothing marked.
    case browsing
    /// A first bar held; waiting for the last one.
    case selecting
    /// A passage on its own, everything else off the screen.
    case studying
  }

  /// The moment the session is in.
  @Published public private(set) var phase: Phase = .browsing

  /// The bars in study, or `nil` while browsing.
  @Published public private(set) var range: PracticeRange?

  /// Which hands are in study.
  @Published public var hands: PracticeHands = .both

  /// Whether the passage starts again on its own.
  @Published public var loops = true

  /// The bar the selection was anchored at, held down first.
  private var anchor: Int?

  /// Creates a session browsing the whole piece.
  public init() {}

  /// What is being studied right now.
  public var study: Study { Study(range: phase == .studying ? range : nil, hands: hands) }

  /// Begins a selection at one bar, as holding a photo does.
  ///
  /// Also mid-study: holding a bar always means "start choosing again".
  /// - Parameter bar: The bar held.
  public func begin(at bar: Int) {
    anchor = bar
    range = PracticeRange(first: bar, last: bar)
    hands = .both
    phase = .selecting
  }

  /// Closes the passage at its last bar and enters study.
  ///
  /// The tap that picks the far end is the tap that starts studying: the
  /// passage runs from the held bar to this one, whichever order they came in.
  /// Does nothing outside selection, where a tap means "listen from here".
  /// - Parameter bar: The far end.
  public func choose(_ bar: Int) {
    guard phase == .selecting, let anchor else { return }

    range = PracticeRange(first: anchor, last: bar)
    phase = .studying
  }

  /// Leaves selection or study: the whole piece, both hands, as found.
  public func finish() {
    anchor = nil
    range = nil
    hands = .both
    phase = .browsing
  }
}

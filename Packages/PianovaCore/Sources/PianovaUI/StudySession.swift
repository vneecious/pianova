import Foundation
import ScoreModel

/// What is being worked at on the piece currently open.
///
/// Three moments, the way iOS selects text: browsing the whole piece;
/// selecting, begun by holding a bar and adjusted by handles or taps; and
/// studying, entered only by confirming. Adjusting and confirming are
/// different acts — a gesture that adjusts never commits, which is what makes
/// a selection predictable.
@MainActor
public final class StudySession: ObservableObject {
  /// Where the player is: browsing, selecting a passage, or studying one.
  public enum Phase: Sendable {
    /// The whole piece, nothing marked.
    case browsing
    /// A passage being picked out, handles at both ends.
    case selecting
    /// A passage on its own, everything else off the screen.
    case studying
  }

  /// The moment the session is in.
  @Published public private(set) var phase: Phase = .browsing

  /// The bars selected or in study, or `nil` while browsing.
  @Published public private(set) var range: PracticeRange?

  /// Which hands are in study.
  @Published public var hands: PracticeHands = .both

  /// Whether the passage starts again on its own.
  @Published public var loops = true

  /// Creates a session browsing the whole piece.
  public init() {}

  /// What is being studied right now.
  public var study: Study { Study(range: phase == .studying ? range : nil, hands: hands) }

  /// Begins a selection at one bar, as holding a photo does.
  ///
  /// Also mid-study: holding a bar always means "start choosing again".
  /// - Parameter bar: The bar held.
  public func begin(at bar: Int) {
    range = PracticeRange(first: bar, last: bar)
    hands = .both
    phase = .selecting
  }

  /// Widens the selection to take a bar in, moving whichever end is nearer.
  ///
  /// Tapping inside changes nothing: shrinking is the handles' work, so that
  /// no tap ever takes away bars the player meant to keep.
  /// - Parameter bar: The bar tapped.
  public func extend(to bar: Int) {
    guard phase == .selecting, let range else { return }

    if bar < range.first {
      self.range = PracticeRange(first: bar, last: range.last)
    } else if bar > range.last {
      self.range = PracticeRange(first: range.first, last: bar)
    }
  }

  /// Reshapes the selection to exactly these bars, as a handle drag does.
  /// - Parameter range: Where the handles now are.
  public func resize(_ range: PracticeRange) {
    guard phase == .selecting else { return }
    self.range = range
  }

  /// Confirms the selection and enters study.
  ///
  /// The one way in, and always an explicit act — the floating button, never
  /// a side effect of adjusting.
  public func commit() {
    guard phase == .selecting, range != nil else { return }
    phase = .studying
  }

  /// Leaves selection or study: the whole piece, both hands, as found.
  public func finish() {
    range = nil
    hands = .both
    phase = .browsing
  }
}

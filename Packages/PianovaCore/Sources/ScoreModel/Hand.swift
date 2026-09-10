/// Which hand plays a note.
///
/// Needed the moment fingering enters the course: finger 1 of the right hand
/// and finger 1 of the left hand are mirror images, so a finger number means
/// nothing without the hand beside it.
public enum Hand: String, CaseIterable, Sendable, Equatable {
  /// The right hand, normally reading the treble staff.
  case right
  /// The left hand, normally reading the bass staff.
  case left

  /// How the hand is abbreviated on a score, in Portuguese.
  public var label: String {
    switch self {
    case .right: return "M.D."
    case .left: return "M.E."
    }
  }

  /// The full name, for instructions read aloud.
  public var name: String {
    switch self {
    case .right: return "mão direita"
    case .left: return "mão esquerda"
    }
  }

  /// The staff the hand normally reads.
  public var clef: Clef {
    switch self {
    case .right: return .treble
    case .left: return .bass
    }
  }
}

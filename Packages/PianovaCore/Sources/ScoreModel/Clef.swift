/// A clef, which fixes where each pitch sits on the staff.
public enum Clef: Sendable, CaseIterable, Codable {
  /// Treble clef, whose bottom line is E4.
  case treble

  /// Bass clef, whose bottom line is G2.
  case bass

  /// Diatonic step that sits on the bottom line of this clef's staff.
  var bottomLineStep: Int {
    switch self {
    case .treble: return Pitch(64).diatonicStep
    case .bass: return Pitch(43).diatonicStep
    }
  }
}

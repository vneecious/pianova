import ScoreModel

extension NoteLetter {
  /// The solfège name, as music is taught in Brazil.
  ///
  /// Lives in the presentation layer on purpose: the domain names notes by
  /// letter, and only the screen speaks solfège.
  public var solfegeName: String {
    switch self {
    case .c: return "Dó"
    case .d: return "Ré"
    case .e: return "Mi"
    case .f: return "Fá"
    case .g: return "Sol"
    case .a: return "Lá"
    case .b: return "Si"
    }
  }
}

extension Pitch {
  /// The solfège name with its octave, such as `Dó 4` for middle C.
  ///
  /// The octave is spelled out because README › Cards invertidos rule 13 asks
  /// for one specific position, not any note with that name.
  public var solfegeWithOctave: String {
    "\(letter.solfegeName) \(octaveNumber)"
  }
}

extension Clef {
  /// The clef's name in Portuguese, for pickers and labels.
  public var displayName: String {
    switch self {
    case .treble: return "Clave de sol"
    case .bass: return "Clave de fá"
    }
  }
}

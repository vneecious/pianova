/// A letter name, ignoring octave and accidental.
///
/// Ordered as the diatonic scale is, starting at C, so the raw value doubles as
/// the position within an octave.
public enum NoteLetter: Int, CaseIterable, Sendable {
  /// C, called Dó in solfège.
  case c
  /// D, called Ré in solfège.
  case d
  /// E, called Mi in solfège.
  case e
  /// F, called Fá in solfège.
  case f
  /// G, called Sol in solfège.
  case g
  /// A, called Lá in solfège.
  case a
  /// B, called Si in solfège.
  case b
}

extension Pitch {
  /// The letter this pitch is named by.
  ///
  /// Accidentals do not change it: C sharp is still a C.
  public var letter: NoteLetter {
    // The modulo is taken twice so pitches below C0, whose diatonic step is
    // negative, still land on a valid case.
    let index = ((diatonicStep % 7) + 7) % 7
    return NoteLetter(rawValue: index) ?? .c
  }
}

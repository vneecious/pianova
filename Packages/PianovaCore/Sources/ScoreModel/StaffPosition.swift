extension Pitch {
  /// Diatonic step of each pitch class, counting letter names only.
  ///
  /// C and C sharp share a step because they occupy the same place on the
  /// staff and differ only by an accidental.
  private static let diatonicStepsInOctave = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]

  /// Pitch classes that fall on black keys.
  private static let sharpPitchClasses: Set<Int> = [1, 3, 6, 8, 10]

  /// Diatonic step number, counting letter names only.
  var diatonicStep: Int {
    let number = Int(midiNoteNumber)
    return (number / 12 - 1) * 7 + Self.diatonicStepsInOctave[number % 12]
  }

  /// Whether this pitch is a black key, drawn with a sharp sign.
  public var requiresSharp: Bool {
    Self.sharpPitchClasses.contains(Int(midiNoteNumber) % 12)
  }

  /// Where this pitch sits on the staff, in half-spaces from the bottom line.
  ///
  /// Zero is the bottom line, 1 the space just above it, 2 the second line, and
  /// so on. Negative values are below the staff, on ledger lines.
  /// - Parameter clef: The clef the staff is written in.
  /// - Returns: The offset in half-spaces from the bottom line.
  public func staffStep(in clef: Clef) -> Int {
    diatonicStep - clef.bottomLineStep
  }

  /// Which staff of a grand staff this pitch is written on.
  ///
  /// Middle C is the hinge and belongs to neither by nature; it is written on
  /// the treble side here so the split has one unambiguous answer.
  public var grandStaffClef: Clef {
    midiNoteNumber >= 60 ? .treble : .bass
  }
}

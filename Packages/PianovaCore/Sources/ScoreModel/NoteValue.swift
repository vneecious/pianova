/// How long a note lasts, as written.
///
/// Each figure is worth half the one before it — that halving is the whole
/// system, and is why the values are never arbitrary.
public enum NoteValue: String, CaseIterable, Sendable, Comparable {
  /// Semibreve: four beats.
  case whole
  /// Mínima: two beats.
  case half
  /// Semínima: one beat, the usual unit of time.
  case quarter
  /// Colcheia: half a beat.
  case eighth
  /// Semicolcheia: a quarter of a beat.
  ///
  /// Not taught by the course, which stops at the quaver, but real sheet music
  /// is full of them — a Bach prelude is nothing else — and a figure the model
  /// cannot represent gets rounded to one it can, which doubles the bar.
  case sixteenth

  /// How many beats the plain figure lasts.
  public var beats: Double {
    switch self {
    case .whole: return 4
    case .half: return 2
    case .quarter: return 1
    case .eighth: return 0.5
    case .sixteenth: return 0.25
    }
  }

  /// The Portuguese name of the figure.
  public var name: String {
    switch self {
    case .whole: return "semibreve"
    case .half: return "mínima"
    case .quarter: return "semínima"
    case .eighth: return "colcheia"
    case .sixteenth: return "semicolcheia"
    }
  }

  /// The name of the matching rest.
  public var restName: String {
    "pausa de \(name)"
  }

  /// Longer figures sort before shorter ones.
  public static func < (lhs: NoteValue, rhs: NoteValue) -> Bool {
    lhs.beats < rhs.beats
  }
}

/// A tuplet's ratio: how many written figures fit the time of how many.
///
/// A triplet is 3 in the time of 2; a quintuplet, 5 in the time of 4. This is
/// MusicXML's `time-modification`, and what the bracket's number means.
public struct TupletRatio: Equatable, Sendable {
  /// How many figures are written.
  public let actual: Int

  /// How many of the same figure the time really holds.
  public let normal: Int

  /// Creates a ratio.
  /// - Parameters:
  ///   - actual: How many figures are written.
  ///   - normal: How many the time really holds.
  public init(actual: Int, normal: Int) {
    self.actual = actual
    self.normal = normal
  }
}

/// A written duration: a figure, possibly dotted, possibly in a tuplet.
public struct Duration: Equatable, Sendable {
  /// The figure.
  public let value: NoteValue

  /// Whether an augmentation dot follows it.
  public let isDotted: Bool

  /// The tuplet this figure belongs to, or `nil` when the time is plain.
  public let tuplet: TupletRatio?

  /// Creates a duration.
  /// - Parameters:
  ///   - value: The figure.
  ///   - isDotted: Whether an augmentation dot follows it.
  ///   - tuplet: The tuplet the figure belongs to, if any.
  public init(_ value: NoteValue, dotted isDotted: Bool = false, tuplet: TupletRatio? = nil) {
    self.value = value
    self.isDotted = isDotted
    self.tuplet = tuplet
  }

  /// How many beats it lasts.
  ///
  /// The dot adds half the figure's own value, which is what makes a dotted
  /// minim worth three beats rather than four. A tuplet squeezes the figure:
  /// a triplet quaver lasts two thirds of a plain one.
  public var beats: Double {
    let dotted = isDotted ? value.beats * 1.5 : value.beats
    guard let tuplet else { return dotted }
    return dotted * Double(tuplet.normal) / Double(tuplet.actual)
  }

  /// How it should be read aloud.
  public var name: String {
    isDotted ? "\(value.name) pontuada" : value.name
  }
}

/// A time signature: how many beats a bar holds, and which figure is the beat.
public struct TimeSignature: Equatable, Sendable {
  /// Beats in a bar — the upper number.
  public let beatsPerBar: Int

  /// The figure worth one beat — the lower number.
  public let beatValue: NoteValue

  /// Creates a time signature.
  /// - Parameters:
  ///   - beatsPerBar: Beats in a bar.
  ///   - beatValue: The figure worth one beat.
  public init(beatsPerBar: Int, beatValue: NoteValue = .quarter) {
    self.beatsPerBar = beatsPerBar
    self.beatValue = beatValue
  }

  /// Four beats to the bar, the quarter note as the unit.
  public static let fourFour = TimeSignature(beatsPerBar: 4)

  /// Three beats to the bar.
  public static let threeFour = TimeSignature(beatsPerBar: 3)

  /// How much a whole bar holds, in crotchet units.
  ///
  /// The unit matters: `beatsPerBar` counts beats, but a beat is not always a
  /// crotchet. A 6/8 bar is six beats and three crotchets.
  public var barBeats: Double {
    Double(beatsPerBar) * beatValue.beats
  }

  /// How it is written, as in `4/4`.
  public var label: String {
    let lower = Int((4 / beatValue.beats).rounded())
    return "\(beatsPerBar)/\(lower)"
  }
}

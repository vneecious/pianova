/// Decides which notes are joined by a beam.
///
/// A lone quaver takes a flag; consecutive quavers are joined by a horizontal
/// beam. This is not typographic vanity: the beam groups what belongs to one
/// beat. Two beamed quavers read as "one beat"; two separate flags read as two
/// unrelated notes and have to be counted.
public enum BeamGrouping {
  /// How many beams a figure carries.
  ///
  /// Zero for anything a crotchet or longer, which is what "does not beam"
  /// means; one for a quaver, two for a semiquaver.
  /// - Parameter value: The written figure.
  /// - Returns: How many beam lines it needs.
  public static func beams(for value: NoteValue) -> Int {
    switch value {
    case .whole, .half, .quarter: return 0
    case .eighth: return 1
    case .sixteenth: return 2
    }
  }

  /// How much music one beam group spans, in crotchets.
  ///
  /// Compound time groups in threes, because there the beat is a dotted
  /// crotchet: six quavers in 6/8 are two groups of three, never three of two.
  public static func groupLength(for time: TimeSignature) -> Double {
    let isCompound = time.beatValue == .eighth && time.beatsPerBar % 3 == 0
    return isCompound ? 1.5 : time.beatValue.beats
  }

  /// One event, as beaming needs to see it.
  public struct Note: Equatable, Sendable {
    /// When it begins, in crotchets from the start of the piece.
    public let start: Double
    /// How long it lasts.
    public let duration: Duration
    /// Whether nothing sounds.
    public let isRest: Bool

    /// Creates an event.
    /// - Parameters:
    ///   - start: When it begins, in crotchets.
    ///   - duration: How long it lasts.
    ///   - isRest: Whether nothing sounds.
    public init(start: Double, duration: Duration, isRest: Bool) {
      self.start = start
      self.duration = duration
      self.isRest = isRest
    }
  }

  /// Runs of notes that should share a beam.
  ///
  /// A run of one is left out: it keeps its flag.
  /// - Parameters:
  ///   - notes: The events, in order.
  ///   - time: The time signature in force.
  ///   - offset: How much the first bar is short by, for an upbeat.
  /// - Returns: Ranges of indices to beam together.
  public static func groups(
    notes: [Note],
    time: TimeSignature,
    offset: Double = 0
  ) -> [Range<Int>] {
    let span = groupLength(for: time)
    let bar = time.barBeats
    guard span > 0, bar > 0 else { return [] }

    var groups: [Range<Int>] = []
    var start: Int?
    var currentSlot: Double?

    func close(at end: Int) {
      // A beam over a single note is not a beam. It keeps its flag.
      if let begin = start, end - begin >= 2 { groups.append(begin..<end) }
      start = nil
      currentSlot = nil
    }

    for (index, note) in notes.enumerated() {
      // A rest breaks the group: a beam never spans a silence.
      guard !note.isRest, beams(for: note.duration.value) > 0, !note.duration.isDotted else {
        close(at: index)
        continue
      }

      let position = note.start + offset
      // Which beat group it falls in, counted from the start of its own bar so
      // a group can never straddle a bar line.
      let slot = (position / span).rounded(.down)
      let barOf = (position / bar).rounded(.down)
      let key = barOf * 1_000 + slot

      if currentSlot != key {
        close(at: index)
        start = index
        currentSlot = key
      }
    }

    close(at: notes.count)
    return groups
  }
}

extension Score {
  /// Runs of columns that share a beam.
  public var beamGroups: [Range<Int>] {
    let offset =
      hasPickup
      ? timeSignature.barBeats - (rightHand.measures.first?.beats ?? timeSignature.barBeats)
      : 0

    return BeamGrouping.groups(
      notes: columns.map {
        BeamGrouping.Note(start: $0.beats, duration: $0.duration, isRest: $0.isRest)
      },
      time: timeSignature,
      offset: offset)
  }
}

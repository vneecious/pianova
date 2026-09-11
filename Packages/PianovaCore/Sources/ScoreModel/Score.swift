/// How many sharps or flats a key signature carries.
///
/// Stored the way MusicXML and every theory text store it: a signed count of
/// fifths from C. Positive is sharps, negative is flats, so `2` is D major and
/// `-1` is F major.
public struct KeySignature: Equatable, Sendable {
  /// Fifths from C: positive for sharps, negative for flats.
  public let fifths: Int

  /// Creates a key signature.
  /// - Parameter fifths: Fifths from C, positive for sharps.
  public init(fifths: Int) {
    self.fifths = fifths
  }

  /// C major, with nothing written.
  public static let c = KeySignature(fifths: 0)

  /// G major, one sharp.
  public static let g = KeySignature(fifths: 1)

  /// F major, one flat.
  public static let f = KeySignature(fifths: -1)

  /// How many accidentals are drawn.
  public var accidentalCount: Int { abs(fifths) }

  /// Whether the accidentals are sharps.
  public var usesSharps: Bool { fifths > 0 }

  /// The letters that carry an accidental, in the order they are written.
  ///
  /// The order is fixed by convention and never varies: sharps go F C G D A E
  /// B, and flats run the same list backwards.
  public var alteredLetters: [NoteLetter] {
    let sharpOrder: [NoteLetter] = [.f, .c, .g, .d, .a, .e, .b]
    let order = usesSharps ? sharpOrder : sharpOrder.reversed()
    return Array(order.prefix(accidentalCount))
  }
}

/// One written event of a piece: notes sounding together, or a rest.
///
/// A rest is a note with no pitches rather than a separate case, because
/// everything downstream — bar filling, the playhead, the written layout —
/// treats it identically: it occupies time.
public struct ScoreNote: Equatable, Sendable {
  /// The pitches sounding together.
  ///
  /// Empty means a rest.
  public let pitches: [Pitch]

  /// How long it lasts, as written.
  public let duration: Duration

  /// Whether it is tied into the next event.
  public let isTiedToNext: Bool

  /// Written fingering, aligned with ``pitches`` — empty means none written.
  ///
  /// Pedagogical editions finger the decisions: the first note of a position,
  /// the thumb-under, the crossing. The model carries the numbers; whether a
  /// piece has any is the edition's choice, never invented downstream.
  public let fingers: [Int]

  /// Creates a written event.
  /// - Parameters:
  ///   - pitches: The pitches sounding together, or empty for a rest.
  ///   - duration: How long it lasts.
  ///   - isTiedToNext: Whether it is tied into the next event.
  ///   - fingers: Written fingering aligned with the pitches, if any.
  public init(
    pitches: [Pitch], duration: Duration, isTiedToNext: Bool = false, fingers: [Int] = []
  ) {
    self.pitches = pitches
    self.duration = duration
    self.isTiedToNext = isTiedToNext
    self.fingers = fingers
  }

  /// A single note.
  /// - Parameters:
  ///   - pitch: The pitch.
  ///   - value: The figure.
  ///   - isDotted: Whether an augmentation dot follows it.
  public init(_ pitch: Pitch, _ value: NoteValue, dotted isDotted: Bool = false) {
    self.init(pitches: [pitch], duration: Duration(value, dotted: isDotted))
  }

  /// A rest.
  /// - Parameters:
  ///   - value: The figure the silence lasts.
  ///   - isDotted: Whether an augmentation dot follows it.
  /// - Returns: The rest.
  public static func rest(_ value: NoteValue, dotted isDotted: Bool = false) -> ScoreNote {
    ScoreNote(pitches: [], duration: Duration(value, dotted: isDotted))
  }

  /// Whether nothing sounds.
  public var isRest: Bool { pitches.isEmpty }

  /// How many beats it occupies.
  public var beats: Double { duration.beats }
}

/// One bar of a part.
public struct Measure: Equatable, Sendable {
  /// The events in the bar, in order.
  public let notes: [ScoreNote]

  /// Creates a bar.
  /// - Parameter notes: The events, in order.
  public init(_ notes: [ScoreNote]) {
    self.notes = notes
  }

  /// How many beats the bar actually holds.
  public var beats: Double { notes.reduce(0) { $0 + $1.beats } }

  /// Whether the bar holds exactly what the time signature asks.
  ///
  /// Measured in crotchet units, because that is what ``Duration/beats``
  /// returns. Comparing against `beatsPerBar` alone would be wrong the moment
  /// the beat is not a crotchet: 6/8 holds six quavers, which is three of
  /// these units and not six.
  /// - Parameter time: The time signature in force.
  /// - Returns: Whether the bar is complete.
  public func isComplete(in time: TimeSignature) -> Bool {
    abs(beats - time.barBeats) < 0.001
  }
}

/// A part: everything one hand reads.
public struct Part: Equatable, Sendable {
  /// The clef the part is written in.
  public let clef: Clef

  /// The bars, in order.
  public let measures: [Measure]

  /// Creates a part.
  /// - Parameters:
  ///   - clef: The clef it is written in.
  ///   - measures: The bars, in order.
  public init(clef: Clef, measures: [Measure]) {
    self.clef = clef
    self.measures = measures
  }

  /// Every event of the part, bar lines ignored.
  public var notes: [ScoreNote] { measures.flatMap(\.notes) }

  /// Every pitch that sounds, in playing order, rests dropped.
  ///
  /// This is what the exercise engine consumes: it judges which key was struck,
  /// and a rest is nothing to strike.
  public var soundingPitches: [Pitch] { notes.flatMap(\.pitches) }
}

/// A piece of music, written out properly.
///
/// A first version of this type held only pitches. What it drew was not a poor
/// score, it was a row of note heads: no rhythm, no bars, no key. Reading
/// cannot be learnt from that, which is why every field below exists.
public struct Score: Equatable, Sendable {
  /// The title shown to the player.
  public let title: String

  /// Who wrote it.
  public let composer: String

  /// Beats to the bar, and which figure is the beat.
  public let timeSignature: TimeSignature

  /// The key it is written in.
  public let key: KeySignature

  /// The right hand part.
  public let rightHand: Part

  /// The left hand part, or `nil` for a one-handed piece.
  public let leftHand: Part?

  /// Whether the piece begins on an upbeat.
  ///
  /// When it does, the first bar is short by design and is exempt from the rule
  /// that bars must fill.
  public let hasPickup: Bool

  /// Creates a score.
  /// - Parameters:
  ///   - title: The title shown to the player.
  ///   - composer: Who wrote it.
  ///   - timeSignature: Beats to the bar.
  ///   - key: The key it is written in.
  ///   - rightHand: The right hand part.
  ///   - leftHand: The left hand part, or `nil` for one hand.
  ///   - hasPickup: Whether the piece begins on an upbeat.
  public init(
    title: String,
    composer: String,
    timeSignature: TimeSignature = .fourFour,
    key: KeySignature = .c,
    rightHand: Part,
    leftHand: Part? = nil,
    hasPickup: Bool = false
  ) {
    self.title = title
    self.composer = composer
    self.timeSignature = timeSignature
    self.key = key
    self.rightHand = rightHand
    self.leftHand = leftHand
    self.hasPickup = hasPickup
  }

  /// Whether the piece needs both hands, and so a grand staff.
  public var isTwoHanded: Bool { leftHand != nil }

  /// Every pitch the right hand strikes, in order, rests dropped.
  public var melody: [Pitch] { rightHand.soundingPitches }

  /// Every pitch the left hand strikes, in order, rests dropped.
  public var bass: [Pitch] { leftHand?.soundingPitches ?? [] }

  /// One column of the written score: what is drawn at a single moment.
  ///
  /// A rest is a column with no pitches. It is drawn, and it takes its width,
  /// because a silence you cannot see is a silence you cannot count.
  public struct Column: Equatable, Sendable {
    /// When it begins, in crotchets from the start.
    public let beats: Double

    /// What the upper staff carries here.
    public let upper: [Pitch]

    /// What the lower staff carries here, empty for a one-handed piece.
    ///
    /// Kept apart from ``upper`` rather than merged, because which staff a note
    /// was written on is not something its pitch can answer: the left hand of
    /// BWV 846 plays middle C and E above it, and routing by pitch sent the
    /// whole left hand to the treble staff and left the bass one empty.
    public let lower: [Pitch]

    /// How long it lasts, as written.
    public let duration: Duration

    /// Everything that sounds here, both staves.
    public var pitches: [Pitch] { upper + lower }

    /// Whether nothing sounds here.
    public var isRest: Bool { pitches.isEmpty }

    /// What sounds here when only one hand is being worked at.
    ///
    /// The other hand goes quiet but its time still passes: a bar where the
    /// right hand rests is a bar where the right hand rests, and shortening it
    /// would teach the wrong rhythm.
    /// - Parameter hands: Which hands are in study.
    /// - Returns: The pitches that should sound.
    public func pitches(for hands: PracticeHands) -> [Pitch] {
      switch hands {
      case .both: return pitches
      case .right: return upper
      case .left: return lower
      }
    }
  }

  /// Everything written, in time order, silences included.
  ///
  /// Built from both hands at once: anything beginning at the same moment
  /// becomes one column, and a moment where neither hand begins a note is a
  /// rest.
  public var columns: [Column] {
    var upper: [Double: [Pitch]] = [:]
    var lower: [Double: [Pitch]] = [:]
    var lengths: [Double: Duration] = [:]
    var moments: Set<Double> = []

    for (part, isUpper) in [(rightHand, true), (leftHand, false)]
      .compactMap({ part, flag in
        part.map { ($0, flag) }
      })
    {
      var time = 0.0
      for note in part.notes {
        moments.insert(time)
        if !note.pitches.isEmpty {
          if isUpper {
            upper[time, default: []].append(contentsOf: note.pitches)
          } else {
            lower[time, default: []].append(contentsOf: note.pitches)
          }
        }

        // The shortest figure starting here decides the width: it is the one
        // that has to stay legible.
        if let held = lengths[time], held.beats <= note.beats {
          // keep the shorter one
        } else {
          lengths[time] = note.duration
        }
        time += note.beats
      }
    }

    return moments.sorted()
      .map { time in
        Column(
          beats: time,
          upper: upper[time] ?? [],
          lower: lower[time] ?? [],
          duration: lengths[time] ?? Duration(.quarter))
      }
  }

  /// Indices of the columns that actually have to be played.
  ///
  /// The staff shows rests; the engine cannot ask for one. This maps between
  /// the two so the cursor lands on the right column.
  public var soundingColumns: [Int] {
    columns.enumerated().filter { !$0.element.isRest }.map(\.offset)
  }

  /// Every moment something must be struck, and what sounds at it.
  ///
  /// Once the hands have real rhythm they stop lining up note for note — a
  /// whole note under four crotchets is one event against four. So the two
  /// parts are merged by **onset**: everything that begins on the same beat
  /// becomes one thing to play, and a held note is not asked for again.
  ///
  /// Beats land on exact halves, so using them as keys is safe here.
  public var onsets: [(beats: Double, pitches: [Pitch])] {
    columns.filter { !$0.isRest }.map { (beats: $0.beats, pitches: $0.pitches) }
  }

  /// The clef the piece is read in when only one hand plays.
  public var clef: Clef { rightHand.clef }

  /// Onset indices after which a bar line falls.
  ///
  /// Derived rather than stored: where a bar ends is a fact about the written
  /// rhythm, so anything drawing it should ask the music, not be told.
  public var barlineColumns: Set<Int> {
    let bar = timeSignature.barBeats
    guard bar > 0, columns.count > 1 else { return [] }

    // A pickup shifts every later bar line by however much the first bar is
    // missing, which is why the offset is measured and not assumed.
    let firstBar = rightHand.measures.first?.beats ?? bar
    let offset = hasPickup ? bar - firstBar : 0

    var result: Set<Int> = []
    let times = columns.map(\.beats)

    for index in 0..<(times.count - 1) {
      let here = ((times[index] + offset) / bar).rounded(.down)
      let next = ((times[index + 1] + offset) / bar).rounded(.down)
      if here != next { result.insert(index) }
    }

    return result
  }

  /// Which bar a column falls in, counting as an editor would.
  ///
  /// An upbeat is not numbered: the first complete bar is number 1, which is
  /// what every publisher does and what a teacher will say out loud.
  /// - Parameter column: Index into ``columns``.
  /// - Returns: The bar number, or `0` for a column in the upbeat.
  public func measureNumber(atColumn column: Int) -> Int {
    let ended = barlineColumns.filter { $0 < column }.count
    return hasPickup ? ended : ended + 1
  }

  /// Bars that do not hold what the time signature asks.
  ///
  /// A pickup bar is excused, and only the first one: a short bar anywhere else
  /// is a mistake in the writing, not a musical intention.
  public var incompleteMeasures: [(part: Clef, index: Int)] {
    var found: [(Clef, Int)] = []

    for part in [rightHand, leftHand].compactMap({ $0 }) {
      for (index, measure) in part.measures.enumerated() {
        if hasPickup && index == 0 { continue }
        if !measure.isComplete(in: timeSignature) { found.append((part.clef, index)) }
      }
    }

    return found.map { (part: $0.0, index: $0.1) }
  }

  /// Whether every bar holds exactly what it should.
  public var isWellFormed: Bool { incompleteMeasures.isEmpty }
}

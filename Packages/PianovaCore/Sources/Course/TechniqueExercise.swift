import ScoreModel

/// One note of a technique exercise: which key, which finger, how long.
///
/// Fingering is not decoration here. The whole point of a technique exercise is
/// the movement, and the movement is decided by which finger goes where — an
/// exercise played with the wrong fingers trains the wrong thing.
public struct TechniqueNote: Equatable, Sendable {
  /// The key to play.
  public let pitch: Pitch

  /// The hand that plays it.
  public let hand: Hand

  /// Which finger, 1 (thumb) to 5 (little finger).
  public let finger: Int

  /// The written figure.
  public let value: NoteValue

  /// Whether an augmentation dot follows it.
  public let isDotted: Bool

  /// Creates a note of an exercise.
  /// - Parameters:
  ///   - pitch: The key to play.
  ///   - hand: The hand that plays it.
  ///   - finger: Which finger, 1 to 5.
  ///   - value: The written figure.
  ///   - isDotted: Whether an augmentation dot follows it.
  public init(
    _ pitch: Pitch,
    hand: Hand,
    finger: Int,
    value: NoteValue = .quarter,
    dotted isDotted: Bool = false
  ) {
    self.pitch = pitch
    self.hand = hand
    self.finger = finger
    self.value = value
    self.isDotted = isDotted
  }

  /// How long the note lasts, dot included.
  public var duration: Duration { Duration(value, dotted: isDotted) }
}

/// A guided technique exercise: the closing drill of a unit.
///
/// "Guided" is the requirement, not a flourish. A drill handed over as bare
/// notes teaches a beginner to repeat a shape without knowing what the shape is
/// for, and that is how tension and wrong habits get practised into place. So
/// every exercise carries its own goal and its own execution instructions, and
/// the app shows them before a single key is pressed.
public struct TechniqueExercise: Equatable, Sendable, Identifiable {
  /// Stable identifier, used to record completion.
  public let id: String

  /// The name shown to the player.
  public let title: String

  /// What the exercise trains, in one line.
  public let goal: String

  /// How to execute it, one instruction per line.
  ///
  /// Never empty: an exercise with no instructions is not guided.
  public let hints: [String]

  /// Beats per minute the exercise is meant to be taken at.
  public let tempo: Double

  /// Beats in a bar.
  public let beatsPerBar: Int

  /// The notes, in playing order.
  public let notes: [TechniqueNote]

  /// Creates a guided exercise.
  /// - Parameters:
  ///   - id: Stable identifier.
  ///   - title: The name shown to the player.
  ///   - goal: What it trains, in one line.
  ///   - hints: How to execute it, one instruction per line.
  ///   - tempo: Beats per minute.
  ///   - beatsPerBar: Beats in a bar.
  ///   - notes: The notes, in playing order.
  public init(
    id: String,
    title: String,
    goal: String,
    hints: [String],
    tempo: Double = 66,
    beatsPerBar: Int = 4,
    notes: [TechniqueNote]
  ) {
    self.id = id
    self.title = title
    self.goal = goal
    self.hints = hints
    self.tempo = tempo
    self.beatsPerBar = beatsPerBar
    self.notes = notes
  }

  /// Which hands the exercise uses.
  public var hands: Set<Hand> { Set(notes.map(\.hand)) }

  /// Whether both hands play.
  public var isTwoHanded: Bool { hands.count > 1 }

  /// The clef the exercise is read in, or the grand staff when both hands play.
  public var clef: Clef {
    hands == [.left] ? .bass : .treble
  }

  /// The exercise as a rhythm pattern, for the step that plays it in time.
  public var rhythmPattern: [RhythmStepNote] {
    notes.map { RhythmStepNote($0.pitch, $0.value, dotted: $0.isDotted) }
  }

  /// How many bars the written rhythm fills, rounded up.
  public var barCount: Int {
    let beats = notes.reduce(0.0) { $0 + $1.duration.beats }
    return Int((beats / Double(beatsPerBar)).rounded(.up))
  }
}

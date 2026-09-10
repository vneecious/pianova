import ScoreModel

/// One note of a written rhythm: which key, and how long it lasts.
///
/// Kept in the course data so a lesson can spell out its own rhythm rather than
/// having one generated at random — a first rhythm should be predictable.
public struct RhythmStepNote: Equatable, Sendable {
  /// The key to play.
  public let pitch: Pitch

  /// The written figure.
  public let value: NoteValue

  /// Whether an augmentation dot follows it.
  public let isDotted: Bool

  /// Creates a written note.
  /// - Parameters:
  ///   - pitch: The key to play.
  ///   - value: The written figure.
  ///   - isDotted: Whether an augmentation dot follows it.
  public init(_ pitch: Pitch, _ value: NoteValue, dotted isDotted: Bool = false) {
    self.pitch = pitch
    self.value = value
    self.isDotted = isDotted
  }
}

/// One activity inside a lesson.
///
/// A lesson alternates between them on purpose: naming a note and finding it
/// under the hand are different skills, and a lesson that only did one would
/// leave the other untrained.
public enum LessonStep: Equatable, Sendable {
  /// Teaching pages, shown one at a time. Explains before anything is asked.
  case reading(noteIDs: [String])

  /// Theory questions, drawn only from pages already read.
  case theory(count: Int)

  /// Naming and placement cards over a range.
  case cards(clef: Clef, range: ClosedRange<UInt8>, count: Int)

  /// Heard notes, named by ear. Nothing is written until the answer is given.
  case ear(clef: Clef, range: ClosedRange<UInt8>, count: Int)

  /// A generated sequence to play on the instrument.
  case play(clef: Clef, range: ClosedRange<UInt8>, length: Int)

  /// Notes sounding together: two voices make thirds, three make triads.
  case harmony(clef: Clef, range: ClosedRange<UInt8>, length: Int, voices: Int)

  /// A sequence that includes black keys.
  ///
  /// Playing an accidental comes well before naming one, so this is a playing
  /// step and never a card.
  case chromatic(clef: Clef, range: ClosedRange<UInt8>, length: Int)

  /// A rhythmic exercise: the right notes, at the right moments.
  case rhythm(clef: Clef, pattern: [RhythmStepNote], tempo: Double, beatsPerBar: Int)

  /// Both hands at once, read on a grand staff.
  case bothHands(rightRange: ClosedRange<UInt8>, leftRange: ClosedRange<UInt8>, length: Int)

  /// A piece to play from start to end.
  case song(Score)

  /// A guided technique drill: goal and instructions first, then the notes.
  case technique(TechniqueExercise)
}

/// One stop on the course: a short run of mixed activities.
public struct Lesson: Equatable, Sendable, Identifiable {
  /// Stable identifier, used to record completion.
  public let id: String

  /// Which of the sixteen units the lesson belongs to.
  public let unit: Int

  /// Short title shown on the trail.
  public let title: String

  /// One line on what the lesson covers.
  public let subtitle: String

  /// The activities, in order.
  public let steps: [LessonStep]

  /// Creates a lesson.
  /// - Parameters:
  ///   - id: Stable identifier, used to record completion.
  ///   - unit: Which of the sixteen units it belongs to.
  ///   - title: Short title shown on the trail.
  ///   - subtitle: One line on what the lesson covers.
  ///   - steps: The activities, in order.
  public init(
    id: String,
    unit: Int,
    title: String,
    subtitle: String,
    steps: [LessonStep]
  ) {
    self.id = id
    self.unit = unit
    self.title = title
    self.subtitle = subtitle
    self.steps = steps
  }

  /// Whether the lesson includes a theory round.
  public var hasTheory: Bool {
    steps.contains {
      switch $0 {
      case .theory, .reading: return true
      default: return false
      }
    }
  }

  /// Identifiers of every teaching page the lesson shows.
  public var readingIDs: [String] {
    steps.flatMap { step -> [String] in
      guard case .reading(let ids) = step else { return [] }
      return ids
    }
  }

  /// Whether the lesson ends on a piece.
  public var hasSong: Bool {
    steps.contains {
      guard case .song = $0 else { return false }
      return true
    }
  }

  /// The guided technique drills the lesson runs.
  public var techniqueExercises: [TechniqueExercise] {
    steps.compactMap { step in
      guard case .technique(let exercise) = step else { return nil }
      return exercise
    }
  }
}

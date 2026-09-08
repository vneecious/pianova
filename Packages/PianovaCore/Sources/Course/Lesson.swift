import ScoreModel

/// A piece to play, stored as its melody.
public struct Song: Equatable, Sendable {
  /// The title shown to the player.
  public let title: String

  /// Who wrote it.
  public let composer: String

  /// The clef it is written in.
  public let clef: Clef

  /// The melody, in playing order.
  public let notes: [Pitch]

  /// The left hand part, note for note against `notes`.
  ///
  /// Empty for a one-handed piece. When present it is played on a grand staff,
  /// each left hand note sounding with the melody note beside it.
  public let leftHandNotes: [Pitch]

  /// Creates a song.
  /// - Parameters:
  ///   - title: The title shown to the player.
  ///   - composer: Who wrote it.
  ///   - clef: The clef it is written in.
  ///   - notes: The melody, in playing order.
  ///   - leftHandNotes: The left hand part, note for note. Empty for one hand.
  public init(
    title: String,
    composer: String,
    clef: Clef,
    notes: [Pitch],
    leftHandNotes: [Pitch] = []
  ) {
    self.title = title
    self.composer = composer
    self.clef = clef
    self.notes = notes
    self.leftHandNotes = leftHandNotes
  }

  /// Whether the piece needs both hands, and so a grand staff.
  public var isTwoHanded: Bool { !leftHandNotes.isEmpty }
}

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
  case song(Song)
}

/// One stop on the course: a short run of mixed activities.
public struct Lesson: Equatable, Sendable, Identifiable {
  /// Stable identifier, used to record completion.
  public let id: String

  /// Which block of the syllabus the lesson belongs to.
  public let block: TheoryTopic

  /// Short title shown on the trail.
  public let title: String

  /// One line on what the lesson covers.
  public let subtitle: String

  /// The activities, in order.
  public let steps: [LessonStep]

  /// Creates a lesson.
  /// - Parameters:
  ///   - id: Stable identifier, used to record completion.
  ///   - block: Which block of the syllabus it belongs to.
  ///   - title: Short title shown on the trail.
  ///   - subtitle: One line on what the lesson covers.
  ///   - steps: The activities, in order.
  public init(
    id: String,
    block: TheoryTopic,
    title: String,
    subtitle: String,
    steps: [LessonStep]
  ) {
    self.id = id
    self.block = block
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
}

import ScoreModel

/// How hard an endless drill is.
public enum DrillDifficulty: String, CaseIterable, Sendable {
  /// Five-finger position around middle C, one note at a time.
  case easy
  /// The whole staff, short sequences.
  case medium
  /// Ledger lines, longer sequences, black keys.
  case hard
}

/// How a drill asks for a note.
public enum DrillPromptStyle: String, CaseIterable, Sendable {
  /// Drawn on the staff, to be found on the keyboard.
  case staff
  /// Written as a name, to be found on the keyboard.
  case name
  /// Played aloud, to be reproduced on the keyboard.
  ///
  /// Nothing is shown. This trains ear to instrument, which is the one link
  /// neither the staff nor the note name can teach.
  case ear
  /// One of the others, chosen at random each time.
  case mixed
}

/// What the drill is showing right now.
public struct DrillPrompt: Equatable, Sendable {
  /// The notes to play, in order.
  public let pitches: [Pitch]

  /// The clef they are read in.
  public let clef: Clef

  /// Whether they are drawn on the staff or written as names.
  public let style: DrillPromptStyle

  /// Creates a prompt.
  /// - Parameters:
  ///   - pitches: The notes to play, in order.
  ///   - clef: The clef they are read in.
  ///   - style: How they are shown. Never `mixed`, which is resolved first.
  public init(pitches: [Pitch], clef: Clef, style: DrillPromptStyle) {
    self.pitches = pitches
    self.clef = clef
    self.style = style
  }
}

/// What an endless drill draws from.
public struct DrillSettings: Equatable, Sendable {
  /// How hard the prompts are.
  public var difficulty: DrillDifficulty

  /// Whether treble clef prompts appear.
  public var usesTreble: Bool

  /// Whether bass clef prompts appear.
  public var usesBass: Bool

  /// How prompts are shown.
  public var style: DrillPromptStyle

  /// Creates settings.
  /// - Parameters:
  ///   - difficulty: How hard the prompts are.
  ///   - usesTreble: Whether treble clef prompts appear.
  ///   - usesBass: Whether bass clef prompts appear.
  ///   - style: How prompts are shown.
  public init(
    difficulty: DrillDifficulty = .easy,
    usesTreble: Bool = true,
    usesBass: Bool = true,
    style: DrillPromptStyle = .staff
  ) {
    self.difficulty = difficulty
    self.usesTreble = usesTreble
    self.usesBass = usesBass
    self.style = style
  }

  /// The clefs in play.
  ///
  /// Never empty: turning both off falls back to treble, because a drill with
  /// no clef would have nothing to ask.
  public var clefs: [Clef] {
    var result: [Clef] = []
    if usesTreble { result.append(.treble) }
    if usesBass { result.append(.bass) }
    return result.isEmpty ? [.treble] : result
  }

  /// The MIDI range a clef draws from at this difficulty.
  /// - Parameter clef: The clef being drawn.
  /// - Returns: The range, inclusive.
  public func range(for clef: Clef) -> ClosedRange<UInt8> {
    switch (difficulty, clef) {
    case (.easy, .treble): return 60...67
    case (.easy, .bass): return 53...60
    case (.medium, .treble): return 64...77
    case (.medium, .bass): return 43...57
    case (.hard, .treble): return 55...84
    case (.hard, .bass): return 36...64
    }
  }

  /// Longest sequence a prompt may hold.
  public var maxSequenceLength: Int {
    switch difficulty {
    case .easy: return 1
    case .medium: return 3
    case .hard: return 5
    }
  }

  /// Longest sequence an ear prompt may hold.
  ///
  /// Shorter than the rest on purpose: holding a melody in your head and
  /// playing it back is far harder than reading the same notes, and a long one
  /// tests memory rather than hearing.
  public var maxEarLength: Int {
    switch difficulty {
    case .easy, .medium: return 1
    case .hard: return 3
    }
  }

  /// Whether black keys appear.
  public var includesAccidentals: Bool { difficulty == .hard }
}

/// Builds prompts for an endless drill.
public enum DrillGenerator {
  /// Builds the next prompt.
  /// - Parameters:
  ///   - settings: What to draw from.
  ///   - generator: Source of randomness, injected so tests stay deterministic.
  /// - Returns: A prompt ready to show.
  public static func next<G: RandomNumberGenerator>(
    settings: DrillSettings,
    using generator: inout G
  ) -> DrillPrompt {
    let clef = settings.clefs.randomElement(using: &generator) ?? .treble
    let pool = pitches(in: settings.range(for: clef), accidentals: settings.includesAccidentals)

    // The style is resolved first, never handed on as `mixed`, so the view
    // always knows what to show — and so an ear prompt can be kept short.
    let concrete: [DrillPromptStyle] = [.staff, .name, .ear]
    let style =
      settings.style == .mixed
      ? (concrete.randomElement(using: &generator) ?? .staff)
      : settings.style

    let ceiling = style == .ear ? settings.maxEarLength : settings.maxSequenceLength
    let length = Int.random(in: 1...max(ceiling, 1), using: &generator)

    let exercise = ExerciseGenerator.build(
      pitches: pool,
      length: length,
      maxLeap: settings.difficulty == .easy ? 2 : 4,
      using: &generator)

    return DrillPrompt(
      pitches: exercise.items.compactMap { $0.pitches.first },
      clef: clef,
      style: style)
  }

  private static func pitches(
    in range: ClosedRange<UInt8>, accidentals: Bool
  ) -> [Pitch] {
    let all = range.map(Pitch.init)
    return accidentals ? all : all.filter { !$0.requiresSharp }
  }
}

/// Running tally of an endless drill.
///
/// A drill has no end, so the tally is the only feedback on how it is going.
public struct DrillStats: Equatable, Sendable {
  /// How many prompts were answered.
  public private(set) var answered = 0

  /// How many were cleared without a mistake.
  public private(set) var correct = 0

  /// How many in a row are currently clean.
  public private(set) var streak = 0

  /// The longest clean run so far.
  public private(set) var bestStreak = 0

  /// Creates an empty tally.
  public init() {}

  /// Records one finished prompt.
  /// - Parameter wasClean: Whether it was cleared without a mistake.
  public mutating func record(wasClean: Bool) {
    answered += 1
    guard wasClean else {
      streak = 0
      return
    }
    correct += 1
    streak += 1
    bestStreak = max(bestStreak, streak)
  }

  /// Share of prompts cleared cleanly, from 0 to 1.
  public var accuracy: Double {
    guard answered > 0 else { return 0 }
    return Double(correct) / Double(answered)
  }
}

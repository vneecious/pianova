import Foundation
import ScoreModel

/// One note of a rhythmic exercise: what to play, and how long it is written.
public struct RhythmicNote: Equatable, Sendable {
  /// The pitches sounding together.
  public let pitches: Set<Pitch>

  /// The written duration.
  public let duration: Duration

  /// Creates a note.
  /// - Parameters:
  ///   - pitches: The pitches sounding together.
  ///   - duration: The written duration.
  public init(pitches: Set<Pitch>, duration: Duration) {
    self.pitches = pitches
    self.duration = duration
  }

  /// Creates a single note.
  /// - Parameters:
  ///   - pitch: The pitch to play.
  ///   - value: The figure.
  ///   - dotted: Whether an augmentation dot follows it.
  public init(_ pitch: Pitch, _ value: NoteValue, dotted: Bool = false) {
    self.init(pitches: [pitch], duration: Duration(value, dotted: dotted))
  }
}

/// How close to the written moment a press landed.
public enum RhythmVerdict: Equatable, Sendable {
  /// Within the tolerance window.
  case onTime
  /// Ahead of the beat.
  case early
  /// Behind the beat.
  case late
  /// The right moment, but the wrong key.
  case wrongNote
  /// The note went by without being played at all.
  case missed
}

/// What one press did to a rhythmic run.
public struct RhythmJudgement: Equatable, Sendable {
  /// How the press was graded.
  public let verdict: RhythmVerdict

  /// Seconds away from the written moment; negative is early.
  public let offset: TimeInterval

  /// Whether the run finished with this press.
  public let isFinished: Bool
}

/// A rhythmic exercise: the right notes, at the right moments.
///
/// Grades **onset** — when each note begins — against the tempo. How long a key
/// is held is not graded: on a piano the sound decays whether or not the finger
/// stays down, so holding is a poor proxy for the written value at this level.
public struct RhythmSession {
  /// Fraction of a beat a press may be off and still count as on time.
  ///
  /// Generous on purpose. A beginner playing within a quarter of a beat is
  /// keeping time, and a tighter window would only teach discouragement.
  public static let defaultTolerance = 0.25

  /// The notes to play, in order.
  public let notes: [RhythmicNote]

  /// Beats per minute.
  public let tempo: Double

  /// Fraction of a beat allowed either side of the written moment.
  public let tolerance: Double

  /// Index of the note expected next.
  public private(set) var index = 0

  /// How many presses landed outside the window.
  public private(set) var offBeatCount = 0

  /// How many presses hit the wrong key.
  public private(set) var wrongNoteCount = 0

  /// How many notes went by without being played at all.
  ///
  /// Only grows in continuous reading, where the music does not wait.
  public private(set) var missedCount = 0

  /// How each note turned out, or `nil` for notes not yet reached.
  ///
  /// Without this a missed note looks exactly like a played one on screen,
  /// which is the same as showing no feedback at all.
  public private(set) var outcomes: [RhythmVerdict?]

  /// Creates a run.
  /// - Parameters:
  ///   - notes: The notes to play, in order.
  ///   - tempo: Beats per minute.
  ///   - tolerance: Fraction of a beat allowed either side.
  public init(
    notes: [RhythmicNote],
    tempo: Double = 60,
    tolerance: Double = RhythmSession.defaultTolerance
  ) {
    self.notes = notes
    self.tempo = max(tempo, 1)
    self.tolerance = max(tolerance, 0)
    outcomes = Array(repeating: nil, count: notes.count)
  }

  /// How one note turned out.
  /// - Parameter noteIndex: Position in the sequence.
  /// - Returns: Its verdict, or `nil` if it has not been reached.
  public func outcome(of noteIndex: Int) -> RhythmVerdict? {
    outcomes.indices.contains(noteIndex) ? outcomes[noteIndex] : nil
  }

  /// How long one beat lasts, in seconds.
  public var beatDuration: TimeInterval { 60 / tempo }

  /// How far a press may be from the written moment and still count.
  public var toleranceWindow: TimeInterval { beatDuration * tolerance }

  /// The note expected next, or `nil` once the run is over.
  public var currentNote: RhythmicNote? {
    notes.indices.contains(index) ? notes[index] : nil
  }

  /// Whether every note has been played.
  public var isFinished: Bool { index >= notes.count }

  /// When a note is written to begin, in seconds from the start.
  ///
  /// The onset of a note is the sum of everything written before it — which is
  /// exactly what reading rhythm means.
  /// - Parameter noteIndex: Position in the sequence.
  /// - Returns: Seconds from the start of the run.
  public func onset(of noteIndex: Int) -> TimeInterval {
    notes.prefix(max(noteIndex, 0))
      .reduce(0) { $0 + $1.duration.beats * beatDuration }
  }

  /// How long the whole run lasts, in seconds.
  public var totalDuration: TimeInterval { onset(of: notes.count) }

  /// Which bar a note falls in, counting from zero.
  /// - Parameters:
  ///   - noteIndex: Position in the sequence.
  ///   - beatsPerBar: Beats to the bar.
  /// - Returns: The bar number, from zero.
  public func bar(of noteIndex: Int, beatsPerBar: Int) -> Int {
    guard beatsPerBar > 0 else { return 0 }
    let beats = onset(of: noteIndex) / beatDuration
    return Int((beats / Double(beatsPerBar)).rounded(.down))
  }

  /// The first note of the bar a given note sits in.
  ///
  /// Where a mistake sends you back to: an error is undone by retaking the bar
  /// it happened in, not by restarting the whole piece.
  /// - Parameters:
  ///   - noteIndex: Position in the sequence.
  ///   - beatsPerBar: Beats to the bar.
  /// - Returns: The index of the first note of that bar.
  public func firstNote(ofBarContaining noteIndex: Int, beatsPerBar: Int) -> Int {
    let target = bar(of: noteIndex, beatsPerBar: beatsPerBar)
    for candidate in 0...max(noteIndex, 0)
    where bar(of: candidate, beatsPerBar: beatsPerBar) == target {
      return candidate
    }
    return 0
  }

  /// Goes back to a note, forgetting how everything from there on turned out.
  ///
  /// Verdicts already earned before that point are kept: retaking a bar should
  /// not erase the bars that went right.
  /// - Parameter target: The note to resume from.
  public mutating func rewind(to target: Int) {
    let safe = min(max(target, 0), notes.count)
    index = safe

    for position in safe..<outcomes.count { outcomes[position] = nil }
  }

  /// Lets the music move on without the player.
  ///
  /// Reading is continuous: you do not stop and wait at each note, and an
  /// exercise that waits trains hesitation. Calling this as the clock runs
  /// abandons any note whose moment has passed and counts it as missed.
  /// - Parameter time: Seconds since the run started.
  /// - Returns: How many notes were passed over.
  @discardableResult
  public mutating func advance(to time: TimeInterval) -> Int {
    var skipped = 0

    while !isFinished, time > onset(of: index) + toleranceWindow {
      missedCount += 1
      outcomes[index] = .missed
      index += 1
      skipped += 1
    }

    return skipped
  }

  /// Judges one press.
  /// - Parameters:
  ///   - pitches: The pitches held at that moment.
  ///   - time: Seconds since the run started.
  /// - Returns: How it was graded.
  public mutating func press(_ pitches: Set<Pitch>, at time: TimeInterval) -> RhythmJudgement {
    guard let note = currentNote else {
      return RhythmJudgement(verdict: .onTime, offset: 0, isFinished: true)
    }

    let offset = time - onset(of: index)

    guard note.pitches == pitches else {
      wrongNoteCount += 1
      return RhythmJudgement(verdict: .wrongNote, offset: offset, isFinished: false)
    }

    let verdict: RhythmVerdict
    if abs(offset) <= toleranceWindow {
      verdict = .onTime
    } else {
      verdict = offset < 0 ? .early : .late
      offBeatCount += 1
    }

    outcomes[index] = verdict
    index += 1
    return RhythmJudgement(verdict: verdict, offset: offset, isFinished: isFinished)
  }
}

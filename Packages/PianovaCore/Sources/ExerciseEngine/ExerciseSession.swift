import Foundation
import ScoreModel

/// Tracks progress through an exercise while keys are pressed.
///
/// The cursor marks exactly one item at a time and walks the sequence as the
/// player clears it. See README › Modelo de interação for the rules it enforces.
public struct ExerciseSession {
  /// The exercise being played.
  public let exercise: Exercise

  /// Largest gap, in seconds, between presses that still count as one chord.
  public let simultaneityWindow: TimeInterval

  /// Index of the item the cursor currently marks.
  public private(set) var cursorIndex = 0

  /// How many wrong presses the run has had.
  ///
  /// Drives level progression the same way the card mode's mistake count does.
  public private(set) var mistakeCount = 0

  /// Correct pitches collected so far towards the current item.
  private var pendingPitches: Set<Pitch> = []

  /// When the most recent pitch of `pendingPitches` arrived.
  ///
  /// The window slides: each right note renews the deadline for the ones
  /// still missing (rule 3). Counted from the first, a chord arriving by
  /// microphone — hands and analysis bands never in step — expired mid-build.
  private var pendingSince: TimeInterval?

  /// Next item's notes that arrived early (rule 4's exception): anxiety,
  /// not error — they wait in the hand and count when the cursor arrives.
  private var earlyPresses: Set<Pitch> = []

  /// When the earliest of `earlyPresses` arrived.
  private var earlySince: TimeInterval?

  /// How long an early note stays good for.
  ///
  /// Anxiety has a deadline.
  private let earlyWindow: TimeInterval = 1.0

  /// Creates a session positioned at the first item.
  /// - Parameters:
  ///   - exercise: The exercise to play.
  ///   - simultaneityWindow: Largest gap, in seconds, between presses that
  ///     should still be read as a single chord.
  public init(exercise: Exercise, simultaneityWindow: TimeInterval = 0.35) {
    self.exercise = exercise
    self.simultaneityWindow = simultaneityWindow
  }

  /// Whether every item has been cleared.
  public var isFinished: Bool { cursorIndex >= exercise.items.count }

  /// The item the cursor marks, or `nil` once the exercise is over.
  public var currentItem: ExerciseItem? {
    guard !isFinished else { return nil }
    return exercise.items[cursorIndex]
  }

  /// Feeds one key press to the session.
  /// - Parameters:
  ///   - pitch: The pitch that was pressed.
  ///   - time: When the press happened, in seconds.
  /// - Returns: What the press did to the cursor.
  public mutating func press(_ pitch: Pitch, at time: TimeInterval) -> KeyPressOutcome {
    guard let item = currentItem else { return .finished }

    // Rule 4's exception: the NEXT item's note arriving early is anxiety,
    // not error. It must not reset the chord being built, and it counts
    // when the cursor gets there — two real hands are never simultaneous.
    if !item.pitches.contains(pitch),
      cursorIndex + 1 < exercise.items.count,
      exercise.items[cursorIndex + 1].pitches.contains(pitch)
    {
      if earlySince == nil { earlySince = time }
      earlyPresses.insert(pitch)
      return .incomplete
    }

    // Rule 4: anything outside the current item is an error, and the cursor
    // stays where it is, waiting for the right note. The staff waits;
    // repetition is a choice (rule 5), never a punishment.
    guard item.pitches.contains(pitch) else {
      clearPending()
      earlyPresses.removeAll()
      earlySince = nil
      mistakeCount += 1
      return .wrong
    }

    // Rule 3: presses only build the same chord while they stay inside the
    // simultaneity window. A late press starts a fresh attempt instead.
    if let since = pendingSince, time - since > simultaneityWindow {
      clearPending()
    }
    pendingPitches.insert(pitch)
    pendingSince = time

    guard pendingPitches == item.pitches else { return .incomplete }

    // Rule 2: the item is complete, so the cursor moves on with no
    // confirmation step.
    clearPending()
    cursorIndex += 1

    // What waited in the hand now counts (rule 4's exception) — if it is
    // still fresh, and it may even complete the next item outright.
    if let since = earlySince, time - since <= earlyWindow,
      let next = currentItem
    {
      pendingPitches = earlyPresses.intersection(next.pitches)
      pendingSince = pendingPitches.isEmpty ? nil : time
      if !pendingPitches.isEmpty, pendingPitches == next.pitches {
        clearPending()
        cursorIndex += 1
      }
    }
    earlyPresses.removeAll()
    earlySince = nil

    return isFinished ? .finished : .advanced
  }

  private mutating func clearPending() {
    pendingPitches.removeAll()
    pendingSince = nil
  }
}

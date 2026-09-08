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

  /// When the first pitch of `pendingPitches` arrived.
  private var pendingSince: TimeInterval?

  /// Creates a session positioned at the first item.
  /// - Parameters:
  ///   - exercise: The exercise to play.
  ///   - simultaneityWindow: Largest gap, in seconds, between presses that
  ///     should still be read as a single chord.
  public init(exercise: Exercise, simultaneityWindow: TimeInterval = 0.08) {
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

    // Rule 4: anything outside the current item is an error, and the cursor
    // steps back so the failed transition gets played again. Rule 5: there is
    // no position before the first item, so the cursor stays put there.
    guard item.pitches.contains(pitch) else {
      clearPending()
      mistakeCount += 1
      cursorIndex = max(0, cursorIndex - 1)
      return .wrong
    }

    // Rule 3: presses only build the same chord while they stay inside the
    // simultaneity window. A late press starts a fresh attempt instead.
    if let since = pendingSince, time - since > simultaneityWindow {
      clearPending()
    }
    if pendingSince == nil {
      pendingSince = time
    }
    pendingPitches.insert(pitch)

    guard pendingPitches == item.pitches else { return .incomplete }

    // Rule 2: the item is complete, so the cursor moves on with no
    // confirmation step.
    clearPending()
    cursorIndex += 1
    return isFinished ? .finished : .advanced
  }

  private mutating func clearPending() {
    pendingPitches.removeAll()
    pendingSince = nil
  }
}

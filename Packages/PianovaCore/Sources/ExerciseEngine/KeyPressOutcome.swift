/// What a single key press did to the cursor.
public enum KeyPressOutcome: Equatable, Sendable {
  /// Correct so far, but the current item still needs more notes.
  case incomplete
  /// The current item was cleared and the cursor moved to the next one.
  case advanced
  /// The press did not belong to the current item, so the cursor rolled back.
  case wrong
  /// The last item was cleared; the exercise is over.
  case finished
}

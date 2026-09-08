import ScoreModel

/// Something the player did, decoded from a raw MIDI byte stream.
public enum MIDIKeyEvent: Equatable, Sendable {
  /// A key went down.
  ///
  /// Velocity runs 1...127 and carries how hard the key was struck.
  case pressed(Pitch, velocity: UInt8)

  /// A key came back up.
  case released(Pitch)

  /// The sustain pedal changed state.
  case sustainPedal(isDown: Bool)
}

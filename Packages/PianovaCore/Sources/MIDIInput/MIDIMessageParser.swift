import ScoreModel

/// Decodes raw MIDI bytes into key events.
///
/// Keeps running-status state across calls, so feed it packets in arrival
/// order. It is deliberately free of Core MIDI: bytes in, events out, fully
/// testable without hardware.
public struct MIDIMessageParser {
  /// Controller number the MIDI standard assigns to the sustain pedal.
  private static let sustainController: UInt8 = 64

  /// Value at or above which a controller counts as engaged.
  private static let controllerThreshold: UInt8 = 64

  /// Status byte carried over for messages that omit their own.
  private var runningStatus: UInt8 = 0

  /// Creates a parser with no carried-over state.
  public init() {}

  /// Decodes one packet of MIDI bytes.
  /// - Parameter bytes: The raw bytes, as delivered by the transport.
  /// - Returns: The key events contained in the packet, in order.
  public mutating func parse(_ bytes: [UInt8]) -> [MIDIKeyEvent] {
    var events: [MIDIKeyEvent] = []
    var index = 0

    while index < bytes.count {
      var status = bytes[index]

      if status & 0x80 != 0 {
        index += 1
        guard status < 0xF0 else {
          // System messages carry no channel and cancel running status. Skip
          // their data bytes so the rest of the packet still decodes.
          runningStatus = 0
          while index < bytes.count && bytes[index] & 0x80 == 0 {
            index += 1
          }
          continue
        }
        runningStatus = status
      } else {
        guard runningStatus != 0 else {
          index += 1
          continue
        }
        // Running status: the sender omitted the status byte to save space.
        status = runningStatus
      }

      switch status & 0xF0 {
      case 0x80, 0x90:
        guard index + 1 < bytes.count else { return events }
        let note = bytes[index]
        let velocity = bytes[index + 1]
        index += 2
        // A Note On with zero velocity is the standard way to say Note Off.
        if status & 0xF0 == 0x90 && velocity > 0 {
          events.append(.pressed(Pitch(note), velocity: velocity))
        } else {
          events.append(.released(Pitch(note)))
        }

      case 0xB0:
        guard index + 1 < bytes.count else { return events }
        let controller = bytes[index]
        let value = bytes[index + 1]
        index += 2
        if controller == Self.sustainController {
          events.append(.sustainPedal(isDown: value >= Self.controllerThreshold))
        }

      case 0xA0, 0xE0:
        // Aftertouch and pitch bend: two data bytes, no key event.
        index += 2

      case 0xC0, 0xD0:
        // Program change and channel pressure: a single data byte.
        index += 1

      default:
        index += 1
      }
    }

    return events
  }
}

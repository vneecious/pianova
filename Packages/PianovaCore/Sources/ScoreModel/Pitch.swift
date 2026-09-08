/// A pitch, identified by its MIDI note number.
///
/// Middle C is note number 60. An 88-key keyboard spans 21 (A0) to 108 (C8).
public struct Pitch: Hashable, Sendable {
  /// Note names within an octave, starting at C.
  private static let noteNames = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
  ]

  /// The MIDI note number, in the range 0...127.
  public let midiNoteNumber: UInt8

  /// Creates a pitch from a MIDI note number.
  /// - Parameter midiNoteNumber: The MIDI note number, in the range 0...127.
  public init(_ midiNoteNumber: UInt8) {
    self.midiNoteNumber = midiNoteNumber
  }

  /// The octave number in scientific pitch notation.
  ///
  /// Middle C is in octave 4. The number rolls over at C, not at A.
  public var octaveNumber: Int {
    Int(midiNoteNumber) / 12 - 1
  }

  /// The scientific pitch name, such as `C4` for middle C.
  ///
  /// Black keys are spelled with sharps, so note 61 reads as `C#4`. The octave
  /// number rolls over at C, not at A.
  public var scientificName: String {
    "\(Self.noteNames[Int(midiNoteNumber) % 12])\(octaveNumber)"
  }
}

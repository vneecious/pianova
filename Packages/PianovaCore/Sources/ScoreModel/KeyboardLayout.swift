import CoreGraphics

/// Where the keys of a piano sit.
///
/// Pure geometry, so the shape of the keyboard is testable without drawing it.
public struct KeyboardLayout: Equatable, Sendable {
  /// Fraction of the full key height that black keys occupy.
  public static let blackKeyHeightRatio: CGFloat = 0.62

  /// Black key width, as a fraction of a white key's width.
  public static let blackKeyWidthRatio: CGFloat = 0.58

  /// Comfortable white key width on a touch screen, in points.
  ///
  /// Well past the 44pt minimum, because a wrong key here is a wrong answer.
  public static let preferredWhiteKeyWidth: CGFloat = 54

  /// Comfortable white key height, in points.
  public static let preferredHeight: CGFloat = 168

  /// How far each black key sits from the boundary between its neighbours, in
  /// white key widths.
  ///
  /// On a real piano black keys are not centred on the gap. In the group of
  /// two, C sharp leans left and D sharp leans right; in the group of three, F
  /// sharp leans left, G sharp sits centred and A sharp leans right. Getting
  /// this wrong teaches the wrong geography to someone learning to find keys
  /// without looking.
  private static let blackKeyOffsets: [Int: CGFloat] = [
    1: -0.10,  // C sharp
    3: +0.10,  // D sharp
    6: -0.15,  // F sharp
    8: 0.00,  // G sharp
    10: +0.15,  // A sharp
  ]

  /// The MIDI range the keyboard covers, inclusive.
  public let range: ClosedRange<UInt8>

  /// Creates a layout.
  /// - Parameter range: The MIDI range to cover, inclusive.
  public init(range: ClosedRange<UInt8>) {
    self.range = range
  }

  /// Three octaves centred on middle C.
  ///
  /// A fixed window on purpose: a keyboard that only showed the notes of the
  /// current exercise would answer half of it.
  public static let standard = KeyboardLayout(range: 48...84)

  /// The white keys, left to right.
  public var whiteKeys: [Pitch] {
    range.map(Pitch.init).filter { !$0.requiresSharp }
  }

  /// The black keys, left to right.
  public var blackKeys: [Pitch] {
    range.map(Pitch.init).filter(\.requiresSharp)
  }

  /// Width the keyboard wants, at a comfortable key size.
  public var preferredWidth: CGFloat {
    CGFloat(whiteKeys.count) * Self.preferredWhiteKeyWidth
  }

  /// Horizontal centre of a black key, in white key widths from the left edge.
  /// - Parameter pitch: The black key.
  /// - Returns: The centre in white-key units, or `nil` if it is not a black
  ///   key in range.
  public func blackKeyCentre(for pitch: Pitch) -> CGFloat? {
    guard pitch.requiresSharp, range.contains(pitch.midiNoteNumber) else { return nil }

    let whiteBelow = Pitch(pitch.midiNoteNumber - 1)
    guard let index = whiteKeys.firstIndex(of: whiteBelow) else { return nil }

    let offset = Self.blackKeyOffsets[Int(pitch.midiNoteNumber) % 12] ?? 0
    return CGFloat(index + 1) + offset
  }

  /// Index of a white key, for positioning.
  /// - Parameter pitch: The white key.
  /// - Returns: Its position from the left, or `nil` if it is not a white key
  ///   in range.
  public func whiteKeyIndex(of pitch: Pitch) -> Int? {
    whiteKeys.firstIndex(of: pitch)
  }
}

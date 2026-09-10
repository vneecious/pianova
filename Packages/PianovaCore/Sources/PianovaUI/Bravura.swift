import CoreText
import Foundation
import ScoreModel

/// The Bravura music font and the SMuFL glyphs the app draws.
///
/// SMuFL fixes both the code points and the metrics: one em equals four staff
/// spaces. Every size here is derived from the staff space, never guessed.
public enum Bravura {
  /// Family name the font registers under.
  public static let familyName = "Bravura"

  /// SMuFL code points for the glyphs the app draws.
  public enum Glyph {
    /// Treble clef.
    ///
    /// Its baseline sits on the G line, the second from the bottom.
    public static let trebleClef = "\u{E050}"

    /// Bass clef.
    ///
    /// Its baseline sits on the F line, the fourth from the bottom.
    public static let bassClef = "\u{E062}"

    /// Filled note head, used when no stem is wanted.
    public static let noteheadBlack = "\u{E0A4}"

    /// Semibreve: a hollow head with no stem.
    public static let noteWhole = "\u{E1D2}"

    /// Mínima with the stem up, and its stem-down twin.
    public static let noteHalfUp = "\u{E1D3}"
    /// Mínima with the stem down.
    public static let noteHalfDown = "\u{E1D4}"

    /// Semínima with the stem up.
    public static let noteQuarterUp = "\u{E1D5}"
    /// Semínima with the stem down.
    public static let noteQuarterDown = "\u{E1D6}"

    /// Colcheia with the stem up, flag included.
    public static let noteEighthUp = "\u{E1D7}"
    /// Colcheia with the stem down, flag included.
    public static let noteEighthDown = "\u{E1D8}"

    /// The augmentation dot.
    public static let augmentationDot = "\u{E1E7}"

    /// Sharp sign.
    public static let sharp = "\u{E262}"

    /// Flat sign, for key signatures.
    public static let flat = "\u{E260}"

    /// The rest matching a written figure.
    ///
    /// A silence has to be drawn, not left as a gap: a gap is indistinguishable
    /// from the piece simply having fewer notes.
    /// - Parameter value: The figure the silence lasts.
    /// - Returns: Its code point.
    public static func rest(for value: NoteValue) -> String {
      switch value {
      case .whole: return "\u{E4E3}"
      case .half: return "\u{E4E4}"
      case .quarter: return "\u{E4E5}"
      case .eighth: return "\u{E4E6}"
      }
    }

    /// A time signature digit.
    /// - Parameter value: The digit, 0 to 9.
    /// - Returns: Its code point, or `0` for anything out of range.
    public static func timeSignatureDigit(_ value: Int) -> String {
      guard (0...9).contains(value) else { return "\u{E080}" }
      return String(UnicodeScalar(0xE080 + value) ?? "0")
    }
  }

  /// One em equals this many staff spaces, per the SMuFL specification.
  public static let staffSpacesPerEm: CGFloat = 4

  private static let registration: Void = {
    guard let url = Bundle.module.url(forResource: "Bravura", withExtension: "otf") else {
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }()

  /// Registers the bundled font.
  ///
  /// Safe to call more than once.
  public static func register() {
    _ = registration
  }

  /// The glyph for a written duration, with the stem on the right side.
  ///
  /// SMuFL ships each figure as a single glyph with its stem and flag already
  /// attached, which is why the notation looks engraved rather than assembled.
  /// - Parameters:
  ///   - duration: The written duration.
  ///   - stemUp: Whether the stem points up.
  /// - Returns: The code point to draw.
  public static func glyph(for duration: Duration, stemUp: Bool) -> String {
    switch duration.value {
    case .whole: return Glyph.noteWhole
    case .half: return stemUp ? Glyph.noteHalfUp : Glyph.noteHalfDown
    case .quarter: return stemUp ? Glyph.noteQuarterUp : Glyph.noteQuarterDown
    case .eighth: return stemUp ? Glyph.noteEighthUp : Glyph.noteEighthDown
    }
  }

  /// A font sized so that one staff space measures `staffSpace` points.
  /// - Parameter staffSpace: The distance between two staff lines, in points.
  /// - Returns: A Core Text font at the matching em size.
  public static func font(staffSpace: CGFloat) -> CTFont {
    register()
    return CTFontCreateWithName(familyName as CFString, staffSpace * staffSpacesPerEm, nil)
  }
}

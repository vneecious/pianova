import CoreGraphics
import Foundation
import ScoreModel

/// One moment of a piece, as the engraver sees it.
public struct EngravedEvent: Equatable, Sendable {
  /// When it sounds, in seconds from the start.
  public let time: TimeInterval

  /// Identifiers of the notes that begin here.
  public let elementIDs: [String]

  /// The keys those notes are, which is what the engine judges against.
  public let pitches: [Pitch]

  /// Creates an event.
  /// - Parameters:
  ///   - time: When it sounds, in seconds.
  ///   - elementIDs: Identifiers of the notes beginning here.
  ///   - pitches: The keys they stand for.
  public init(time: TimeInterval, elementIDs: [String], pitches: [Pitch]) {
    self.time = time
    self.elementIDs = elementIDs
    self.pitches = pitches
  }
}

/// Something that can engrave music and say which drawn element is which note.
///
/// A protocol, and the reason is containment: the engraver underneath is C++,
/// and Swift's interop is viral — every module that can see it must be built
/// for it, all the way up to the app. Behind this protocol, the screens see
/// only values.
public protocol ScoreEngraver: AnyObject, Sendable {
  /// Lays out a piece.
  /// - Parameter musicXML: The piece, as MusicXML.
  /// - Returns: Whether it could be laid out.
  @discardableResult
  func load(musicXML: String) -> Bool

  /// Lays out a piece at a given page width, which is what zoom is.
  ///
  /// Fewer units across the page means fewer bars per line, each drawn
  /// larger at the same display width — the page reflows instead of
  /// stretching.
  /// - Parameters:
  ///   - musicXML: The piece, as MusicXML.
  ///   - width: Page width, in tenths of a staff space.
  ///   - height: Page height, in the same units.
  /// - Returns: Whether it could be laid out.
  @discardableResult
  func load(musicXML: String, width: Int, height: Int) -> Bool

  /// How many pages the piece came to.
  var pageCount: Int { get }

  /// Draws one page, counting from one.
  func page(_ number: Int) -> EngravedPage?

  /// Which page an element was drawn on.
  func page(containing id: String) -> Int

  /// Everything that sounds, in order, with the keys it means.
  func events() -> [EngravedEvent]
}

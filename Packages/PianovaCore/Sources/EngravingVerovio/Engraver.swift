import CoreGraphics
import Engraving
import Foundation
import ScoreModel
import VerovioToolkit

/// Engraves music properly, and says which drawn element is which note.
///
/// The engraver draws; it decides nothing. Which key was pressed, when, and
/// whether that was right stays in Swift — the only thing crossing over is
/// "this identifier is that pitch", through the timemap.
/// The engraver is used from one screen at a time, and the toolkit underneath
/// holds the whole document, so it is not free to share across threads.
public final class Engraver: ScoreEngraver, @unchecked Sendable {
  private let toolkit: VerovioToolkit

  /// Creates an engraver, pointed at its own resources.
  public init() {
    // The fonts and metric tables travel in the package's own bundle.
    let resources = (VerovioResources.bundle.resourcePath ?? "") + "/data"
    toolkit = VerovioToolkit(resources)
  }

  /// Lays out a piece at the default page size.
  /// - Parameter musicXML: The piece, as MusicXML.
  /// - Returns: Whether it could be laid out.
  @discardableResult
  public func load(musicXML: String) -> Bool {
    load(musicXML: musicXML, width: 2100, height: 2970)
  }

  /// Lays out a piece at a given page size.
  /// - Parameters:
  ///   - musicXML: The piece, as MusicXML.
  ///   - width: Page width, in tenths of a staff space.
  ///   - height: Page height, in the same units.
  /// - Returns: Whether it could be laid out.
  @discardableResult
  public func load(musicXML: String, width: Int, height: Int) -> Bool {
    let options = """
      {"pageWidth": \(width), "pageHeight": \(height), "scale": 40,
       "adjustPageHeight": true, "footer": "none", "header": "none",
       "spacingStaff": 8, "breaks": "auto"}
      """
    _ = toolkit.setOptions(options)
    return toolkit.loadData(musicXML)
  }

  /// How many pages the piece came to.
  public var pageCount: Int { toolkit.getPageCount() }

  /// Draws one page.
  /// - Parameter number: Which page, counting from one.
  /// - Returns: The page, or `nil` if it could not be drawn.
  public func page(_ number: Int) -> EngravedPage? {
    EngravedPageParser.page(from: toolkit.renderToSVG(number, false))
  }

  /// Which page an element was drawn on.
  /// - Parameter id: The element identifier.
  /// - Returns: The page number, counting from one.
  public func page(containing id: String) -> Int {
    toolkit.getPageWithElement(id)
  }

  /// Everything that sounds, in order, with the keys it means.
  ///
  /// This is the whole bridge between the engraver and the engine: each moment
  /// carries the identifiers to highlight and the pitches to judge against.
  public func events() -> [EngravedEvent] {
    guard let data = toolkit.renderToTimemap("{}").data(using: .utf8),
      let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }

    return entries.compactMap { entry in
      guard let starting = entry["on"] as? [String], !starting.isEmpty else { return nil }
      let milliseconds = (entry["tstamp"] as? Double) ?? 0

      return EngravedEvent(
        time: milliseconds / 1000,
        elementIDs: starting,
        pitches: starting.compactMap(pitch(of:)))
    }
  }

  /// The key one drawn note stands for.
  /// - Parameter id: The element identifier.
  /// - Returns: Its pitch, or `nil` if the element is not a sounding note.
  public func pitch(of id: String) -> Pitch? {
    guard let data = toolkit.getMIDIValuesForElement(id).data(using: .utf8),
      let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let number = values["pitch"] as? Int,
      (0...127).contains(number)
    else {
      return nil
    }

    return Pitch(UInt8(number))
  }

  /// What the engraver complained about, if anything.
  public var log: String { toolkit.getLog() }
}

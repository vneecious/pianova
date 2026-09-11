import Foundation

/// The player's own pencil marks, kept between sessions.
///
/// One file per page of one piece at one zoom — a page that reflows is a
/// different page, and a circle around bar 12 must not land on bar 9 after a
/// pinch. Stored as opaque data: what PencilKit writes, PencilKit reads.
public struct AnnotationStore {
  /// Where the drawings live.
  public let folder: URL

  /// Creates a store.
  /// - Parameter folder: Where to keep the drawings. Defaults to Application
  ///   Support, next to the score library.
  public init(folder: URL? = nil) {
    self.folder =
      folder
      ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory()))
      .appendingPathComponent("Pianova", isDirectory: true)
      .appendingPathComponent("Annotations", isDirectory: true)
  }

  /// The name one page's drawing is filed under.
  ///
  /// Piece, zoom and page — all three, because each combination is its own
  /// canvas. Base64 of the key keeps any title filesystem-safe.
  private func file(title: String, units: Int, page: Int) -> URL {
    let key = "\(title)|\(units)|\(page)"
    let name = Data(key.utf8).base64EncodedString()
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: "+", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return folder.appendingPathComponent(name).appendingPathExtension("drawing")
  }

  /// The saved drawing for one page, if any.
  /// - Parameters:
  ///   - title: The piece's title.
  ///   - units: The engraving width the page was drawn at.
  ///   - page: The page index.
  /// - Returns: The drawing's data, or `nil` if none was made.
  public func drawing(title: String, units: Int, page: Int) -> Data? {
    try? Data(contentsOf: file(title: title, units: units, page: page))
  }

  /// Keeps one page's drawing, or removes it when it emptied.
  /// - Parameters:
  ///   - data: What PencilKit produced — empty removes the file.
  ///   - title: The piece's title.
  ///   - units: The engraving width the page was drawn at.
  ///   - page: The page index.
  public func save(_ data: Data, title: String, units: Int, page: Int) {
    let url = file(title: title, units: units, page: page)

    guard !data.isEmpty else {
      try? FileManager.default.removeItem(at: url)
      return
    }

    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? data.write(to: url)
  }

  /// Forgets every drawing made on one piece, at every zoom.
  /// - Parameter title: The piece's title.
  public func clear(title: String) {
    let found =
      (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
      ?? []

    for url in found {
      let name = url.deletingPathExtension().lastPathComponent
        .replacingOccurrences(of: "-", with: "/")
        .replacingOccurrences(of: "_", with: "+")
      let padded = name.padding(
        toLength: ((name.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

      guard let data = Data(base64Encoded: padded),
        let key = String(data: data, encoding: .utf8),
        key.hasPrefix("\(title)|")
      else { continue }

      try? FileManager.default.removeItem(at: url)
    }
  }
}

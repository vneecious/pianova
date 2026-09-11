import CoreGraphics
import Foundation

/// Where a pencil stroke hangs on the music (rule 131).
public enum AnnotationAnchor {
  /// The map from a bar's old box to its new one.
  ///
  /// Corner goes to corner and centre to centre: whatever was drawn over the
  /// bar rides along when the page reflows and the bar lands elsewhere at
  /// another size.
  /// - Parameters:
  ///   - old: The bar's box when the stroke was made.
  ///   - new: The bar's box on the page as engraved now.
  /// - Returns: The affine map between them.
  public static func transform(from old: CGRect, to new: CGRect) -> CGAffineTransform {
    guard old.width > 0, old.height > 0 else { return .identity }

    return CGAffineTransform(translationX: new.minX, y: new.minY)
      .scaledBy(x: new.width / old.width, y: new.height / old.height)
      .translatedBy(x: -old.minX, y: -old.minY)
  }
}

/// The player's own pencil marks, kept between sessions.
///
/// One file per piece, each stroke anchored to its bar (rule 131): the page
/// that reflows is another page, but the bar is the same bar, and a circle
/// around bar 12 belongs to bar 12 at every zoom. The stroke itself is opaque:
/// what PencilKit writes, PencilKit reads.
public struct AnnotationStore {
  /// One pencil stroke, hung on its bar.
  public struct AnchoredStroke: Codable, Equatable {
    /// The bar the stroke was drawn over.
    public let bar: Int

    /// The bar's box, in page units, when the stroke was made.
    public let anchor: CGRect

    /// The stroke itself, in the same page units — PencilKit's own bytes.
    public let stroke: Data

    /// Creates an anchored stroke.
    /// - Parameters:
    ///   - bar: The bar it was drawn over.
    ///   - anchor: The bar's box when it was made, in page units.
    ///   - stroke: PencilKit's bytes for the one stroke, in page units.
    public init(bar: Int, anchor: CGRect, stroke: Data) {
      self.bar = bar
      self.anchor = anchor
      self.stroke = stroke
    }
  }

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

  /// The name one piece's strokes are filed under.
  ///
  /// Base64 of the title keeps any of them filesystem-safe.
  private func file(title: String) -> URL {
    let name = Data(title.utf8).base64EncodedString()
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: "+", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return folder.appendingPathComponent(name).appendingPathExtension("annotations")
  }

  /// Every stroke made on one piece, in the order they were made.
  /// - Parameter title: The piece's title.
  /// - Returns: The anchored strokes, or nothing when none were made.
  public func strokes(title: String) -> [AnchoredStroke] {
    guard let data = try? Data(contentsOf: file(title: title)),
      let strokes = try? JSONDecoder().decode([AnchoredStroke].self, from: data)
    else { return [] }
    return strokes
  }

  /// Keeps one piece's strokes, or removes them all when the list emptied.
  /// - Parameters:
  ///   - strokes: Every stroke of the piece — empty removes the file.
  ///   - title: The piece's title.
  public func save(_ strokes: [AnchoredStroke], title: String) {
    let url = file(title: title)

    guard !strokes.isEmpty, let data = try? JSONEncoder().encode(strokes) else {
      try? FileManager.default.removeItem(at: url)
      return
    }

    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? data.write(to: url)
  }

  /// Forgets every drawing made on one piece — and only that one.
  /// - Parameter title: The piece's title.
  public func clear(title: String) {
    try? FileManager.default.removeItem(at: file(title: title))

    // Drawings from before the anchoring were filed per zoom and page, under
    // "title|units|page" — they are unreadable now and leave with the piece.
    let found =
      (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
      ?? []
    for url in found where url.pathExtension == "drawing" {
      let name = url.deletingPathExtension().lastPathComponent
        .replacingOccurrences(of: "-", with: "/")
        .replacingOccurrences(of: "_", with: "+")
      let padded = name.padding(toLength: ((name.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

      guard let data = Data(base64Encoded: padded),
        let key = String(data: data, encoding: .utf8),
        key.hasPrefix("\(title)|")
      else { continue }
      try? FileManager.default.removeItem(at: url)
    }
  }
}

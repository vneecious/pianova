import Foundation

/// The scores the player imported, kept between sessions.
///
/// What is stored is the **original file**, re-read on each launch. The file is
/// the source of truth: storing our reading of it instead would freeze today's
/// import bugs into the library, and those are still being fixed.
///
/// The files live in the app's `Documents` — the folder the Files app shows
/// as "Pianova". A library its owner cannot see is not a library: whatever is
/// dropped there appears in the repertoire, and whatever is imported through
/// the app appears there.
public struct ScoreLibrary {
  /// Where the files live.
  public let folder: URL

  /// Creates a library, carrying over anything left in the old hidden home.
  /// - Parameters:
  ///   - folder: Where to keep the files. Defaults to `Documents`, which the
  ///     Files app shows.
  ///   - legacy: The old Application Support folder, migrated on sight and
  ///     never overwriting what the visible folder already has.
  public init(folder: URL? = nil, legacy: URL? = nil) {
    self.folder =
      folder
      ?? (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory()))

    // Migration reaches the real Application Support only from the real
    // default library. A custom folder with no explicit legacy — a test's
    // scratch, say — must never siphon the actual library into itself,
    // which is exactly what happened on the first try.
    let hidden =
      legacy
      ?? (folder == nil
        ? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
          ?? URL(fileURLWithPath: NSTemporaryDirectory()))
          .appendingPathComponent("Pianova", isDirectory: true)
          .appendingPathComponent("Scores", isDirectory: true)
        : nil)

    if let hidden { migrate(from: hidden) }
  }

  /// Moves the old folder's scores into the visible one, once and gently.
  private func migrate(from hidden: URL) {
    let left =
      (try? FileManager.default.contentsOfDirectory(at: hidden, includingPropertiesForKeys: nil))
      ?? []

    for file in left where Self.extensions.contains(file.pathExtension.lowercased()) {
      let target = folder.appendingPathComponent(file.lastPathComponent)
      guard !FileManager.default.fileExists(atPath: target.path) else { continue }

      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try? FileManager.default.moveItem(at: file, to: target)
    }
  }

  /// Extensions the library will keep.
  public static let extensions = ["musicxml", "xml"]

  /// The files kept, oldest name first.
  public func files() -> [URL] {
    let found =
      (try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil)) ?? []

    return
      found
      .filter { Self.extensions.contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// Everything in the library, read fresh.
  ///
  /// A file that no longer parses is skipped rather than fatal: one bad import
  /// should not stop the others from opening.
  public func scores() -> [Score] {
    files().compactMap { try? MusicXMLImporter.score(at: $0) }
  }

  /// Copies a file in and returns what it holds.
  ///
  /// The name is kept unless something already has it, so the library reads
  /// like a folder of scores rather than a pile of identifiers.
  /// - Parameter url: The file the player picked.
  /// - Returns: The score it holds.
  /// - Throws: ``MusicXMLError`` if it cannot be read, or a file system error.
  @discardableResult
  public func add(_ url: URL) throws -> Score {
    // Parsed before it is kept: refusing an unreadable file is no use if the
    // library fills up with it anyway.
    let score = try MusicXMLImporter.score(at: url)

    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: destination(for: url))
    try FileManager.default.copyItem(at: url, to: destination(for: url))

    return score
  }

  /// Forgets a score, by the title it is listed under.
  /// - Parameter title: The title shown in the list.
  public func remove(titled title: String) {
    for file in files() where (try? MusicXMLImporter.score(at: file))?.title == title {
      try? FileManager.default.removeItem(at: file)
    }
  }

  /// Where a picked file is copied to.
  private func destination(for url: URL) -> URL {
    folder.appendingPathComponent(url.lastPathComponent)
  }
}

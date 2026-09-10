import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

/// Asks the player for a file.
///
/// SwiftUI's `.fileImporter` is the obvious answer and it is the one used on
/// iPad, where it opens the Files browser. On macOS it does nothing at all in
/// this app: the Mac build is a bundle assembled by a script with only an
/// ad-hoc signature, and the panel never appears — no error, no log, no window.
/// So the Mac asks `NSOpenPanel` directly, which works regardless.
enum FileChooser {
  /// Whether this platform can open a panel on the spot.
  ///
  /// When it cannot, the caller falls back to `.fileImporter`.
  static var opensDirectly: Bool {
    #if os(macOS)
    return true
    #else
    return false
    #endif
  }

  /// Opens a picker and waits for an answer.
  /// - Parameter types: What the player is allowed to pick.
  /// - Returns: The chosen file, or `nil` if the picker was dismissed.
  @MainActor
  static func choose(types: [UTType]) -> URL? {
    #if os(macOS)
    let panel = NSOpenPanel()
    panel.allowedContentTypes = types
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    return panel.runModal() == .OK ? panel.url : nil
    #else
    return nil
    #endif
  }
}

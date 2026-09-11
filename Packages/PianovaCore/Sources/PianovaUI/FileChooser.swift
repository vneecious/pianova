import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Asks the player for a file.
///
/// SwiftUI's `.fileImporter` is the obvious answer, and it failed silently on
/// both platforms: on macOS the panel never appeared at all, and on iPad
/// pressing the button did nothing. Twice was enough. Each platform now opens
/// its own picker directly — `NSOpenPanel` and `UIDocumentPickerViewController`
/// — which is what the modifier wraps anyway, minus whatever it was doing in
/// between.
enum FileChooser {
  /// Asks for a file, whichever way this platform does it.
  /// - Parameters:
  ///   - types: What the player is allowed to pick.
  ///   - completion: Called with the chosen file, or `nil` if dismissed.
  @MainActor
  static func pick(types: [UTType], completion: @escaping (URL?) -> Void) {
    #if os(macOS)
    let panel = NSOpenPanel()
    panel.allowedContentTypes = types
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    completion(panel.runModal() == .OK ? panel.url : nil)
    #else
    present(types: types, completion: completion)
    #endif
  }

  #if !os(macOS)
  /// Opens the Files browser from the window's own root controller.
  ///
  /// Presented directly rather than through a SwiftUI modifier, because the
  /// modifier is the part that was not working.
  @MainActor
  private static func present(types: [UTType], completion: @escaping (URL?) -> Void) {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }

    guard let root = scene?.keyWindow?.rootViewController else {
      completion(nil)
      return
    }

    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
    picker.allowsMultipleSelection = false

    let delegate = PickerDelegate(completion: completion)
    picker.delegate = delegate
    PickerDelegate.alive = delegate

    // Present from whatever is already on screen, or the sheet is asked to
    // appear over a controller that is itself covered and never shows.
    var top = root
    while let presented = top.presentedViewController { top = presented }
    top.present(picker, animated: true)
  }

  /// Holds the picker's answer until it arrives.
  ///
  /// A picker does not retain its delegate, so without keeping it here the
  /// callback never fires.
  private final class PickerDelegate: NSObject, UIDocumentPickerDelegate {
    static var alive: PickerDelegate?

    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
      self.completion = completion
    }

    func documentPicker(
      _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
    ) {
      completion(urls.first)
      PickerDelegate.alive = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      completion(nil)
      PickerDelegate.alive = nil
    }
  }
  #endif
}

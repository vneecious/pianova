#if canImport(UIKit)
import UIKit
#endif

/// The small taps that confirm a gesture landed.
///
/// A long press has no visible progress, so without a tap the finger leaves not
/// knowing whether anything happened. The Mac has no equivalent, and silence
/// there is the right behaviour rather than a missing feature.
enum Haptics {
  #if canImport(UIKit)
  /// One generator kept warm: creating one per tick costs more than the tick.
  @MainActor private static let generator = UISelectionFeedbackGenerator()
  #endif

  /// Confirms that something became selected.
  @MainActor static func selected() {
    #if canImport(UIKit)
    generator.selectionChanged()
    #endif
  }

  /// Marks a decision that stuck — entering study, finishing a passage.
  ///
  /// A different weight from the selection tick on purpose: adjusting and
  /// committing should not feel the same in the hand either.
  @MainActor static func confirmed() {
    #if canImport(UIKit)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif
  }
}

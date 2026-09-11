#if canImport(UIKit)
import UIKit
#endif

/// The small taps that confirm a gesture landed.
///
/// A long press has no visible progress, so without a tap the finger leaves not
/// knowing whether anything happened. The Mac has no equivalent, and silence
/// there is the right behaviour rather than a missing feature.
enum Haptics {
  /// Confirms that something became selected.
  @MainActor static func selected() {
    #if canImport(UIKit)
    UISelectionFeedbackGenerator().selectionChanged()
    #endif
  }
}

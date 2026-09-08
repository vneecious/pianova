import CoreGraphics
import SwiftUI

/// Colors used when drawing into a Core Graphics context, where SwiftUI's
/// adaptive `Color` is not available.
///
/// Every value takes the colour scheme, because Core Graphics colours are fixed
/// numbers: a near-black clef drawn on a dark background simply disappears.
enum PlatformColor {
  /// Regular staff and clef colour.
  /// - Parameter scheme: The colour scheme in force.
  /// - Returns: Ink that reads against that background.
  static func staffInk(_ scheme: ColorScheme) -> CGColor {
    scheme == .dark
      ? CGColor(red: 0.91, green: 0.92, blue: 0.94, alpha: 1)
      : CGColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)
  }

  /// Ink for a note head, by state.
  /// - Parameters:
  ///   - state: How the item should read.
  ///   - scheme: The colour scheme in force.
  /// - Returns: The colour to draw it in.
  static func ink(for state: ItemState, in scheme: ColorScheme) -> CGColor {
    let dark = scheme == .dark

    switch state {
    case .done:
      return dark
        ? CGColor(red: 0.36, green: 0.81, blue: 0.53, alpha: 1)
        : CGColor(red: 0.13, green: 0.55, blue: 0.33, alpha: 1)
    case .current:
      return dark
        ? CGColor(red: 0.44, green: 0.68, blue: 1.00, alpha: 1)
        : CGColor(red: 0.11, green: 0.38, blue: 0.85, alpha: 1)
    case .pending:
      return dark
        ? CGColor(red: 0.55, green: 0.58, blue: 0.63, alpha: 1)
        : CGColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1)
    case .failed:
      return dark
        ? CGColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 1)
        : CGColor(red: 0.80, green: 0.18, blue: 0.20, alpha: 1)
    }
  }
}

extension ItemState {
  /// SwiftUI colour matching ``PlatformColor/ink(for:in:)``.
  ///
  /// Mid-tone on purpose, so the same value reads on a light or a dark
  /// background without needing the environment.
  var color: Color {
    switch self {
    case .done: return Color(red: 0.20, green: 0.66, blue: 0.42)
    case .current: return Color(red: 0.25, green: 0.52, blue: 0.94)
    case .pending: return Color(red: 0.58, green: 0.61, blue: 0.66)
    case .failed: return Color(red: 0.89, green: 0.30, blue: 0.31)
    }
  }
}

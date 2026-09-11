import SwiftUI

/// Which theme the app uses.
///
/// A choice and not only the system's: reading music is done in whatever light
/// the room has, and the room does not always agree with the clock.
public enum Appearance: String, CaseIterable, Identifiable, Sendable {
  /// Follow the system.
  case system
  /// Always light.
  case light
  /// Always dark.
  case dark

  /// Stable identity for `ForEach`.
  public var id: String { rawValue }

  /// The name shown to the player.
  public var title: String {
    switch self {
    case .system: return "Sistema"
    case .light: return "Claro"
    case .dark: return "Escuro"
    }
  }

  /// The symbol shown on the switch.
  public var symbol: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .light: return "sun.max"
    case .dark: return "moon"
    }
  }

  /// What SwiftUI should force, or `nil` to follow the system.
  public var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  /// The next choice, for a switch that cycles.
  public var next: Appearance {
    let all = Appearance.allCases
    let index = all.firstIndex(of: self) ?? 0
    return all[(index + 1) % all.count]
  }
}

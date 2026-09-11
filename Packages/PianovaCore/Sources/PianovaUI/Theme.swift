import SwiftUI

/// The app's surfaces and colours, in one place.
///
/// The screen before this had the score edge to edge on the window's own
/// background, so page, chrome and keyboard were the same white — and what the
/// eye had to read competed with everything around it. Music on paper works
/// because the page is an object: bounded, lifted, and clearly not the desk.
public enum Theme {
  /// The colour that marks what matters: the note to play now.
  ///
  /// Warm rather than the system blue, so it reads as ink on a page instead of
  /// a control to be pressed.
  public static let accent = Color(red: 0.16, green: 0.42, blue: 0.86)

  /// The room the app sits in.
  ///
  /// Never pure white or pure black: on a flat white background the page, the
  /// chrome and the keyboard all read as the same surface.
  public static func background(_ scheme: ColorScheme) -> Color {
    scheme == .dark
      ? Color(red: 0.09, green: 0.09, blue: 0.11)
      : Color(red: 0.95, green: 0.94, blue: 0.92)
  }

  /// The page music is printed on, raised off the room.
  public static func paper(_ scheme: ColorScheme) -> Color {
    scheme == .dark
      ? Color(red: 0.14, green: 0.14, blue: 0.17)
      : Color(red: 0.99, green: 0.99, blue: 0.98)
  }

  /// Panels that are part of the furniture, not the page.
  public static func surface(_ scheme: ColorScheme) -> Color {
    scheme == .dark
      ? Color(red: 0.13, green: 0.13, blue: 0.16)
      : Color(red: 0.99, green: 0.98, blue: 0.97)
  }

  /// The hairline that separates one area from another.
  public static func border(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08)
  }

  /// How much a raised object lifts off what is behind it.
  public static func shadow(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.10)
  }

  /// Corner radius for a page.
  public static let pageRadius: CGFloat = 14

  /// Corner radius for a panel or a control.
  public static let panelRadius: CGFloat = 10
}

extension View {
  /// Presents this as a page: raised, bounded, and clearly not the desk.
  /// - Parameter scheme: The theme in force.
  /// - Returns: The view on a page.
  public func asPage(_ scheme: ColorScheme) -> some View {
    background(Theme.paper(scheme))
      .clipShape(RoundedRectangle(cornerRadius: Theme.pageRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.pageRadius, style: .continuous)
          .strokeBorder(Theme.border(scheme), lineWidth: 1)
      )
      .shadow(color: Theme.shadow(scheme), radius: 10, y: 3)
  }

  /// Presents this as a panel: part of the furniture, not the page.
  /// - Parameter scheme: The theme in force.
  /// - Returns: The view on a panel.
  public func asPanel(_ scheme: ColorScheme) -> some View {
    background(Theme.surface(scheme))
      .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
          .strokeBorder(Theme.border(scheme), lineWidth: 1)
      )
  }
}

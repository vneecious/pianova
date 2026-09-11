import Engraving
import SwiftUI

/// Where the screens find the engraver.
///
/// An environment value rather than an `EnvironmentObject`, because the
/// engraver is a service and has no published state to watch. Injecting it
/// this way also keeps the C++ target out of every view's imports: the screens
/// only ever see the protocol.
private struct ScoreEngraverKey: EnvironmentKey {
  static let defaultValue: ScoreEngraver? = nil
}

extension EnvironmentValues {
  /// The engraver, when the app provided one.
  public var scoreEngraver: ScoreEngraver? {
    get { self[ScoreEngraverKey.self] }
    set { self[ScoreEngraverKey.self] = newValue }
  }
}

/// Which renderer draws a piece.
///
/// Both exist while they are being compared: one is the app's own staff, the
/// other a real engraver. Same piece, same screen, one switch.
public enum ScoreRenderer: String, CaseIterable, Identifiable, Sendable {
  /// The staff this app draws itself.
  case own
  /// Verovio, the engraving tradition MuseScore and Finale follow.
  case engraved

  /// Stable identity for `ForEach`.
  public var id: String { rawValue }

  /// The name shown to the player.
  public var title: String {
    switch self {
    case .own: return "Pauta própria"
    case .engraved: return "Gravação"
    }
  }
}

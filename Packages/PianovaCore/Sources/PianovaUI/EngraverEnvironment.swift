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

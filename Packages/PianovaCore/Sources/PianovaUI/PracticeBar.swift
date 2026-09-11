import ScoreModel
import SwiftUI

/// The controls for working at a passage.
///
/// Appears only once something is selected, and leaves when nothing is — the
/// way a toolbar for a selection should. Nothing here is on screen while there
/// is nothing to apply it to.
struct PracticeBar: View {
  @Environment(\.colorScheme) private var colorScheme
  @ObservedObject var session: StudySession

  /// Whether the piece has a left hand to work at separately at all.
  let hasBothHands: Bool

  /// Whether the passage is sounding right now.
  var isPlaying = false

  /// Plays, or stops, the passage in study, where there is a preview to play
  /// it with.
  var onListen: (() -> Void)?

  /// Leaves the selection, where nothing else offers a way out.
  ///
  /// On the piece screen the title bar takes selection over and carries this
  /// itself; inside a lesson there is no such bar, and a selection with no exit
  /// is a trap.
  var onFinish: (() -> Void)?

  var body: some View {
    HStack(spacing: 14) {
      if hasBothHands {
        Picker("", selection: $session.hands) {
          ForEach(PracticeHands.allCases) { Text($0.shortTitle).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 190)
      }

      if let onListen {
        Button(action: onListen) {
          Label(isPlaying ? "Parar" : "Ouvir", systemImage: isPlaying ? "stop.fill" : "play.fill")
            .font(.system(size: 12, weight: .medium))
            .contentTransition(.symbolEffect(.replace))
        }
      }

      Toggle(isOn: $session.loops) {
        Label("Repetir", systemImage: "repeat")
          .font(.system(size: 12))
      }
      .toggleStyle(.button)

      Spacer(minLength: 0)

      Text(hint)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      if let onFinish {
        Button {
          withAnimation(.easeOut(duration: 0.22)) { onFinish() }
        } label: {
          Text("Concluir").font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .asPanel(colorScheme)
    .shadow(color: Theme.shadow(colorScheme), radius: 8, y: 2)
  }

  /// What the current choice actually does, said once so nobody has to guess.
  private var hint: String {
    switch session.hands {
    case .both: return "Toque noutro compasso para estender o trecho."
    case .right, .left: return "A outra mão fica na pauta, só não é avaliada."
    }
  }
}

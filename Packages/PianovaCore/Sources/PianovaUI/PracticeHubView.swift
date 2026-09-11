import Course
import SwiftUI

/// One place for everything that is practice and not a piece.
///
/// The app used to spread this over three top-level tabs — Livre, Treino,
/// Leitura — which put the modes of practising on the same footing as the
/// places of the app. Here the places stay three (play, practise, trail) and
/// the modes become cards inside this one.
struct PracticeHubView: View {
  @Environment(\.colorScheme) private var colorScheme

  /// How far the player has got, for the repeatable activities.
  let progress: CourseProgress

  /// Called to start the endless drill.
  let onDrill: () -> Void

  /// Called to start continuous reading.
  let onReading: () -> Void

  /// Called with a trail lesson to repeat.
  let onPick: (Lesson) -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        HStack(spacing: 16) {
          card(
            title: "Treino contínuo",
            detail: "Notas sem fim, cada vez mais rápidas. Para aquecer os dedos e a leitura.",
            symbol: "infinity",
            action: onDrill)
          card(
            title: "Leitura contínua",
            detail: "A linha não espera: leia adiante, toque no tempo. O metrônomo manda.",
            symbol: "text.line.first.and.arrowtriangle.forward",
            action: onReading)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Repetir uma atividade")
            .font(.system(size: 17, weight: .semibold))
          Text("Qualquer lição já aberta na trilha, sem mexer no seu progresso.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }

        FreePracticeView(progress: progress, onPick: onPick)
      }
      .padding(.horizontal, 32)
      .padding(.vertical, 26)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// One practice mode, sold in a sentence.
  private func card(
    title: String, detail: String, symbol: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: symbol)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(Theme.accent)
        Text(title)
          .font(.system(size: 16, weight: .semibold))
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      .asPanel(colorScheme)
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

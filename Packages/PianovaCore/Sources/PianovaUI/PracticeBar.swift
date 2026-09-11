import ScoreModel
import SwiftUI

/// The controls for working at a passage.
///
/// Appears only once something is selected, and leaves when nothing is — the
/// way a toolbar for a selection should. Nothing here is on screen while there
/// is nothing to apply it to.
struct PracticeBar: View {
  @Environment(\.colorScheme) private var colorScheme

  let range: PracticeRange
  @Binding var hands: PracticeHands
  @Binding var loops: Bool

  /// Whether the piece has a left hand to isolate at all.
  let hasBothHands: Bool

  let onClear: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 1) {
        Text(range.label)
          .font(.system(size: 14, weight: .semibold))
        Text(range.count == 1 ? "Em estudo" : "\(range.count) compassos em estudo")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Divider().frame(height: 26)

      if hasBothHands {
        Picker("", selection: $hands) {
          ForEach(PracticeHands.allCases) { Text($0.shortTitle).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 190)
      }

      Toggle(isOn: $loops) {
        Label("Repetir", systemImage: "repeat")
          .font(.system(size: 12))
      }
      .toggleStyle(.button)

      Spacer(minLength: 0)

      Button {
        onClear()
      } label: {
        Label("Peça inteira", systemImage: "xmark.circle.fill")
          .font(.system(size: 12, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .asPanel(colorScheme)
    .shadow(color: Theme.shadow(colorScheme), radius: 8, y: 2)
  }
}

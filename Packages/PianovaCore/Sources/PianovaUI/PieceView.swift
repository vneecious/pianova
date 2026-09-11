import Engraving
import ExerciseEngine
import ScoreModel
import Sound
import SwiftUI

/// One piece, engraved and played, with a preview to hear it first.
///
/// There is only one renderer now. The app drew its own staff for a while and
/// it was useful — it is what proved what a score needs — but a real engraver
/// does it better, and keeping two was keeping two of everything.
struct PieceView: View {
  @EnvironmentObject private var tones: TonePlayer
  @EnvironmentObject private var preview: ScorePlayer
  @Environment(\.colorScheme) private var colorScheme

  let score: Score
  let mode: PlayMode
  @ObservedObject var hub: MIDIHub
  let onFinished: () -> Void

  /// Where the preview begins, chosen by tapping a bar.
  @State private var startFrom = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      transport

      EngravedPieceView(
        hub: hub, score: score, onFinished: onFinished,
        onPickStart: { startFrom = $0 })
    }
    .onDisappear { preview.stop() }
  }

  /// What the listen button says, naming the bar when it will not start at the
  /// beginning.
  private var listenTitle: String {
    startFrom > 0
      ? "Ouvir do compasso \(score.measureNumber(atColumn: startFrom))"
      : "Ouvir a peça"
  }

  private var transport: some View {
    HStack(spacing: 12) {
      Button {
        preview.isPlaying
          ? preview.stop()
          : preview.play(score, tempo: Self.tempo(for: score), from: startFrom)
      } label: {
        Label(
          preview.isPlaying ? "Parar" : listenTitle,
          systemImage: preview.isPlaying ? "stop.fill" : "play.fill"
        )
        .font(.system(size: 13, weight: .medium))
      }

      if startFrom > 0 {
        Button("Do começo") { startFrom = 0 }
          .font(.system(size: 11))
      }

      Text(
        preview.isPlaying
          ? "Toque num compasso para ouvir dali."
          : "Toque num compasso para estudá-lo; noutro para estender o trecho."
      )
      .font(.system(size: 11))
      .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(.bottom, 14)
  }

  /// A tempo gentle enough to read at.
  ///
  /// An imported score is usually marked at performance speed, and reading
  /// speed is not performance speed.
  private static func tempo(for score: Score) -> Double {
    score.timeSignature.beatValue == .eighth ? 108 : 72
  }
}

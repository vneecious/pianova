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

  /// Leaves the piece, back to where it was opened from.
  let onBack: () -> Void

  /// What is being worked at, which also decides what the preview plays.
  @StateObject private var session = StudySession()

  /// Where the preview begins, chosen by tapping a bar.
  @State private var startFrom = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      titleBar

      if session.isSelecting {
        PracticeBar(
          session: session, hasBothHands: score.isTwoHanded,
          isPlaying: preview.isPlaying, onListen: listen
        )
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
      }

      EngravedPieceView(
        hub: hub, score: score, session: session, onFinished: onFinished,
        onPickStart: { startFrom = $0 })
    }
    .onDisappear { preview.stop() }
    // What is being studied changed, so whatever is sounding is no longer it.
    .onChange(of: session.study) { _, _ in preview.stop() }
  }

  /// The bar at the top, which selection takes over the way Photos does.
  ///
  /// While a passage is selected there is no way back to the list: leaving the
  /// piece and leaving the selection are different things, and a back button
  /// sitting there invites the wrong one.
  private var titleBar: some View {
    ZStack {
      VStack(spacing: 1) {
        Text(session.range?.label ?? score.title)
          .font(.system(size: 15, weight: .semibold))
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        if !session.isSelecting {
          Button(action: onBack) {
            Label("Repertório", systemImage: "chevron.left")
              .font(.system(size: 13, weight: .medium))
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        trailing
      }
    }
    .padding(.bottom, 12)
    .animation(.easeInOut(duration: 0.2), value: session.isSelecting)
  }

  @ViewBuilder private var trailing: some View {
    if session.isSelecting {
      Button {
        withAnimation(.easeOut(duration: 0.22)) { session.finish() }
      } label: {
        Text("Concluir").font(.system(size: 13, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Theme.accent)
    } else {
      HStack(spacing: 12) {
        if startFrom > 0 {
          Button("Do começo") { startFrom = 0 }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }

        Button(action: listen) {
          Label(
            preview.isPlaying ? "Parar" : listenTitle,
            systemImage: preview.isPlaying ? "stop.fill" : "play.fill"
          )
          .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
      }
    }
  }

  /// The line under the title: what selection is for, or what it is doing.
  private var subtitle: String {
    guard let range = session.range else {
      return "Segure num compasso para estudar um trecho."
    }

    return range.count == 1 ? "Em estudo" : "\(range.count) compassos em estudo"
  }

  /// What the listen button says, naming the bar when it will not start at the
  /// beginning.
  private var listenTitle: String {
    startFrom > 0
      ? "Ouvir do compasso \(score.measureNumber(atColumn: startFrom))"
      : "Ouvir a peça"
  }

  /// Plays what is in study, or stops it.
  private func listen() {
    guard !preview.isPlaying else { return preview.stop() }

    let study = session.study
    let bounds = score.columns(in: study.range)
    preview.play(
      score, tempo: Self.tempo(for: score),
      from: study.range == nil ? startFrom : bounds.lowerBound,
      through: bounds.upperBound, hands: study.hands)
  }

  /// A tempo gentle enough to read at.
  ///
  /// An imported score is usually marked at performance speed, and reading
  /// speed is not performance speed.
  private static func tempo(for score: Score) -> Double {
    score.timeSignature.beatValue == .eighth ? 108 : 72
  }
}

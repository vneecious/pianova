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

      if session.phase == .studying {
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

  /// The bar at the top, which selection and study take over in turn.
  ///
  /// While either is on there is no way back to the list: leaving the passage
  /// and leaving the piece are different gestures, and only one of them is
  /// shown at a time — a back button sitting there was being pressed all day
  /// in the hope of getting the score back.
  private var titleBar: some View {
    ZStack {
      VStack(spacing: 1) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 12) {
        if session.phase == .browsing {
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
    .animation(.easeInOut(duration: 0.2), value: session.phase)
  }

  @ViewBuilder private var trailing: some View {
    switch session.phase {
    case .browsing:
      HStack(spacing: 12) {
        annotateMenu
        fingeringToggle

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
          // The icon morphs instead of swapping — the button is one thing
          // changing state, not two buttons taking turns.
          .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
      }

    case .selecting:
      Button {
        withAnimation(.easeOut(duration: 0.22)) { session.finish() }
      } label: {
        Text("Cancelar").font(.system(size: 13, weight: .medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)

    case .studying:
      Button {
        withAnimation(.easeOut(duration: 0.22)) { session.finish() }
      } label: {
        Text("Concluir").font(.system(size: 13, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(Theme.accent)
    }
  }

  private var title: String {
    switch session.phase {
    case .browsing: return score.title
    case .selecting: return session.range?.label ?? "Escolhendo trecho"
    case .studying: return session.range?.label ?? score.title
    }
  }

  /// Whether written fingering is drawn, remembered between sessions.
  @AppStorage("pianova.showsFingering") private var showsFingering = true

  /// The tool the pencil holds, remembered between sessions.
  @AppStorage("pianova.annotationTool") private var annotationTool = "pen"

  /// Shows or hides the written fingering — stages of studying the same piece.
  private var fingeringToggle: some View {
    Button {
      showsFingering.toggle()
    } label: {
      Image(systemName: showsFingering ? "hand.raised.fill" : "hand.raised.slash")
        .font(.system(size: 13))
    }
    .buttonStyle(.plain)
    .foregroundStyle(showsFingering ? Theme.accent : .secondary)
    .help(showsFingering ? "Ocultar a digitação" : "Mostrar a digitação")
  }

  /// The pencil's tools: what it draws with, and the way out of a mess.
  private var annotateMenu: some View {
    Menu {
      #if canImport(UIKit) && canImport(PencilKit)
      ForEach(AnnotationTool.allCases, id: \.rawValue) { tool in
        Button {
          annotationTool = tool.rawValue
        } label: {
          Label(tool.title, systemImage: tool.symbol)
        }
      }

      Divider()
      #endif

      Button(role: .destructive) {
        AnnotationStore().clear(title: score.title)
      } label: {
        Label("Apagar anotações da peça", systemImage: "trash")
      }
    } label: {
      Image(systemName: "pencil.tip.crop.circle")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .help("Anotar com a caneta")
  }

  /// One line saying what the current gesture does, per phase.
  private var subtitle: String {
    switch session.phase {
    case .browsing:
      return "Segure num compasso para estudar um trecho."
    case .selecting:
      return "Arraste as alças ou toque noutro compasso. Estudar confirma."
    case .studying:
      return "O resto da partitura espera a vez. Conclua para voltar."
    }
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

    if session.phase == .studying {
      // A stretch of the piece itself, so the columns the preview announces
      // are the ones on the page and the highlight lands where the sound is.
      let bounds = score.columns(in: session.range)
      preview.play(
        score, tempo: Self.tempo(for: score),
        from: bounds.lowerBound, through: bounds.upperBound, hands: session.hands)
    } else {
      preview.play(score, tempo: Self.tempo(for: score), from: startFrom)
    }
  }

  /// A tempo gentle enough to read at.
  ///
  /// An imported score is usually marked at performance speed, and reading
  /// speed is not performance speed.
  private static func tempo(for score: Score) -> Double {
    score.timeSignature.beatValue == .eighth ? 108 : 72
  }
}

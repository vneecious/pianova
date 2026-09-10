import ExerciseEngine
import ScoreModel
import Sound
import SwiftUI

/// One piece, worked at freely or in time, with a preview to hear it first.
///
/// The preview is the part a beginner most needs and most methods assume away:
/// someone who has never heard the tune is decoding symbols with no idea what
/// they are aiming for.
struct PieceView: View {
  @EnvironmentObject private var tones: TonePlayer
  @StateObject private var preview: PreviewBox = PreviewBox()

  let score: Score
  let mode: PlayMode
  @ObservedObject var hub: MIDIHub
  let onFinished: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      transport

      switch mode {
      case .free:
        PlayStepView(
          exercise: Self.exercise(for: score),
          clef: score.clef,
          title: "\(score.title) — \(score.composer)",
          hub: hub,
          score: score,
          onFinished: onFinished)

      case .inTime:
        RhythmStepView(
          notes: Self.rhythm(for: score),
          clef: score.clef,
          tempo: Self.tempo(for: score),
          beatsPerBar: score.timeSignature.beatsPerBar,
          hub: hub,
          tones: tones,
          score: score,
          onFinished: onFinished)
      }
    }
    .onAppear { preview.attach(tones) }
    .onDisappear { preview.player?.stop() }
  }

  private var transport: some View {
    HStack(spacing: 14) {
      Button {
        guard let player = preview.player else { return }
        player.isPlaying ? player.stop() : player.play(score, tempo: Self.tempo(for: score))
      } label: {
        Label(
          preview.player?.isPlaying == true ? "Parar" : "Ouvir a peça",
          systemImage: preview.player?.isPlaying == true ? "stop.fill" : "play.fill"
        )
        .font(.system(size: 13, weight: .medium))
      }

      Text(mode.detail)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(.bottom, 14)
  }

  /// A piece becomes one item per onset, silences excluded.
  private static func exercise(for score: Score) -> Exercise {
    Exercise(items: score.onsets.map { ExerciseItem(pitches: Set($0.pitches)) })
  }

  /// The written page as a rhythm, silences included: the clock has to run
  /// through them or every bar after the first would land early.
  private static func rhythm(for score: Score) -> [RhythmicNote] {
    score.columns.map {
      RhythmicNote(pitches: Set($0.pitches), duration: $0.duration)
    }
  }

  /// A tempo gentle enough to read at.
  ///
  /// The file may carry one, but an imported score is usually marked at
  /// performance speed, and reading speed is not performance speed.
  private static func tempo(for score: Score) -> Double {
    score.timeSignature.beatValue == .eighth ? 108 : 72
  }
}

/// Holds the preview player, which needs the environment to exist first.
@MainActor
private final class PreviewBox: ObservableObject {
  @Published var player: ScorePlayer?

  func attach(_ tones: TonePlayer) {
    guard player == nil else { return }
    player = ScorePlayer(tones: tones)
  }
}

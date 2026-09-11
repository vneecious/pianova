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

  /// The shared preview player.
  ///
  /// Observed directly, not through a box that holds it: SwiftUI only watches
  /// the object it is given, so a nested `ObservableObject` publishes when the
  /// *box* changes and stays silent while the player inside it advances. That
  /// is why the page did not follow the sound.
  @EnvironmentObject private var preview: ScorePlayer

  /// Where the preview begins, chosen by tapping a system.
  @State private var startFrom = 0

  let score: Score
  let mode: PlayMode
  @ObservedObject var hub: MIDIHub
  let onFinished: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      transport

      switch mode {
      case .free:
        if preview.isPlaying {
          // While the preview runs, the page follows what is sounding rather
          // than the cursor: you are listening, not playing.
          ScoreSheetView(
            score: score,
            states: score.columns.indices.map { $0 == preview.column ? .current : .pending },
            focusColumn: preview.column,
            staffSpace: 16,
            playhead: PlayheadPosition(column: preview.column, progress: 0),
            onPickStart: { startFrom = $0 }
          )
          .frame(minHeight: 300)
          .padding(.horizontal, 8)
        } else {
          PlayStepView(
            exercise: Self.exercise(for: score),
            clef: score.clef,
            title: "\(score.title) — \(score.composer)",
            hub: hub,
            score: score,
            onFinished: onFinished)
        }

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
    HStack(spacing: 14) {
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

      Text(preview.isPlaying ? "Toque num sistema para ouvir dali." : mode.detail)
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

import Course
import ExerciseEngine
import MIDIInput
import ScoreModel
import Sound
import SwiftUI

/// Runs a guided technique drill, in the order the drill is meant to be taken.
///
/// The order is the guidance. Read what it trains, tap the rhythm against a
/// pulse, then play — a beginner handed the notes straight away practises the
/// shape and misses the point of the drill.
struct TechniqueStepView: View {
  /// Which stage of the drill is on screen.
  private enum Stage: Equatable {
    /// Goal, instructions and fingering, before anything is played.
    case briefing
    /// Tapping the rhythm against the metronome.
    case tapping
    /// Playing it on the instrument, judged in time.
    case playing
  }

  @ObservedObject var hub: MIDIHub

  private let exercise: TechniqueExercise
  private let tones: TonePlayer
  private let onFinished: () -> Void

  @State private var stage: Stage = .briefing

  init(
    exercise: TechniqueExercise,
    hub: MIDIHub,
    tones: TonePlayer,
    onFinished: @escaping () -> Void
  ) {
    self.exercise = exercise
    self.hub = hub
    self.tones = tones
    self.onFinished = onFinished
  }

  var body: some View {
    switch stage {
    case .briefing:
      briefing
    case .tapping:
      TapAlongView(
        exercise: exercise,
        tones: tones,
        onFinished: { stage = .playing })
    case .playing:
      RhythmStepView(
        notes: exercise.rhythmPattern.map {
          RhythmicNote($0.pitch, $0.value, dotted: $0.isDotted)
        },
        clef: exercise.clef,
        tempo: exercise.tempo,
        beatsPerBar: exercise.beatsPerBar,
        hub: hub,
        tones: tones,
        onFinished: onFinished)
    }
  }

  // MARK: - Briefing

  private var briefing: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Técnica")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)

        Text(exercise.title)
          .font(.system(size: 26, weight: .semibold, design: .serif))

        Text(exercise.goal)
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(exercise.hints.enumerated()), id: \.offset) { index, hint in
          HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .frame(width: 20, height: 20)
              .background(Color.accentColor, in: Circle())

            Text(hint)
              .font(.system(size: 14))
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      fingeringChart

      HStack(spacing: 14) {
        Text("\(Int(exercise.tempo)) bpm")
        Text("compasso \(exercise.beatsPerBar)/4")
        Text("\(exercise.barCount) compassos")
      }
      .font(.system(size: 12))
      .foregroundStyle(.secondary)

      Button("Bater o ritmo") { stage = .tapping }
        .keyboardShortcut(.defaultAction)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The staff, with the finger to use written under every note.
  ///
  /// Fingering shown apart from the notes is fingering nobody reads, so it goes
  /// directly beneath the note head it belongs to.
  private var fingeringChart: some View {
    VStack(alignment: .leading, spacing: 4) {
      StaffView(
        clef: exercise.clef,
        noteGroups: exercise.notes.map { [$0.pitch] },
        states: Array(repeating: .pending, count: exercise.notes.count),
        durations: exercise.notes.map(\.duration),
        staffSpace: 16)

      HStack(spacing: 0) {
        ForEach(Array(exercise.notes.enumerated()), id: \.offset) { _, note in
          VStack(spacing: 1) {
            Text("\(note.finger)")
              .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(note.hand == .right ? "D" : "E")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .foregroundStyle(note.hand == .right ? Color.accentColor : Color.orange)
        }
      }
      .padding(.horizontal, 8)
    }
  }
}

/// The tapping stage: the pulse sounds, the player claps the written rhythm.
///
/// Nothing is judged here on purpose. The point is to separate *when* from
/// *which key*, and a beginner asked to solve both at once solves neither.
private struct TapAlongView: View {
  let exercise: TechniqueExercise
  let tones: TonePlayer
  let onFinished: () -> Void

  @State private var beat: Int = 0
  @State private var ticker: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Antes de tocar")
          .font(.system(size: 22, weight: .semibold, design: .serif))
        Text(
          "Bata o ritmo na tampa do piano, contando alto. Só as durações — "
            + "as teclas vêm depois."
        )
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      StaffView(
        clef: exercise.clef,
        noteGroups: exercise.notes.map { [$0.pitch] },
        states: Array(repeating: .pending, count: exercise.notes.count),
        durations: exercise.notes.map(\.duration),
        staffSpace: 16)

      HStack(spacing: 10) {
        ForEach(1...max(exercise.beatsPerBar, 2), id: \.self) { number in
          Text("\(number)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .frame(width: 44, height: 44)
            .background(
              beat == number ? Color.accentColor : Color.primary.opacity(0.08),
              in: Circle()
            )
            .foregroundStyle(beat == number ? .white : .primary)
        }
      }

      Button(ticker == nil ? "Ligar o metrônomo" : "Parar") {
        ticker == nil ? start() : stop()
      }

      Button("Já bati — tocar agora") {
        stop()
        onFinished()
      }
      .keyboardShortcut(.defaultAction)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onDisappear { stop() }
  }

  private func start() {
    stop()
    let interval = 60 / exercise.tempo
    ticker = Task {
      var count = 0
      while !Task.isCancelled {
        count = count % exercise.beatsPerBar + 1
        beat = count
        tones.click(isAccent: count == 1)
        try? await Task.sleep(for: .seconds(interval))
      }
    }
  }

  private func stop() {
    ticker?.cancel()
    ticker = nil
    beat = 0
  }
}

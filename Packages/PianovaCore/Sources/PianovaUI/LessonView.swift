import Course
import ExerciseEngine
import NoteQuiz
import Progress
import ScoreModel
import Sound
import SwiftUI

/// Runs a lesson: its steps in order, with a progress bar across the top.
public struct LessonView: View {
  @ObservedObject private var controller: LessonController
  @ObservedObject private var hub: MIDIHub
  @EnvironmentObject private var tones: TonePlayer
  @EnvironmentObject private var profile: ProfileController

  /// Called when the player leaves, finished or not.
  public let onClose: (Bool) -> Void

  /// Creates the lesson screen.
  /// - Parameters:
  ///   - controller: The lesson being run.
  ///   - hub: The shared instrument connection.
  ///   - onClose: Called when the player leaves, with whether it was finished.
  public init(
    controller: LessonController,
    hub: MIDIHub,
    onClose: @escaping (Bool) -> Void
  ) {
    self.controller = controller
    self.hub = hub
    self.onClose = onClose
  }

  /// The lesson screen.
  public var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      header

      if controller.isFinished {
        completionPanel
      } else if let step = controller.currentStep {
        stepView(step)
          .id(controller.stepIndex)
      }

      Spacer()
    }
    .padding(32)
  }

  private var header: some View {
    HStack(spacing: 16) {
      Button {
        onClose(false)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.primary.opacity(0.08))
          Capsule()
            .fill(ItemState.done.color)
            .frame(width: proxy.size.width * fraction)
            .animation(.easeOut(duration: 0.25), value: fraction)
        }
      }
      .frame(height: 10)

      Text("\(controller.stepNumber)/\(controller.stepCount)")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  private var fraction: Double {
    controller.isFinished ? 1 : controller.fraction
  }

  private var completionPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Lição concluída")
        .font(.system(size: 26, weight: .semibold, design: .serif))
      Text(controller.lesson.subtitle)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)

      Button("Voltar à trilha") { onClose(true) }
        .keyboardShortcut(.defaultAction)
        .padding(.top, 8)
    }
    .frame(maxWidth: .infinity, minHeight: 300, alignment: .leading)
  }

  @ViewBuilder
  private func stepView(_ step: LessonStep) -> some View {
    switch step {
    case .reading(let noteIDs):
      ReadingStepView(noteIDs: noteIDs, onFinished: { controller.completeStep() })

    case .theory(let count):
      TheoryStepView(
        lesson: controller.lesson, count: count, profile: profile,
        onFinished: { controller.completeStep() })

    case .ear(let clef, let range, let count):
      CardStepView(
        clef: clef, range: range, count: count, profile: profile,
        direction: .hearTheNote,
        onFinished: { controller.completeStep() })

    case .cards(let clef, let range, let count):
      CardStepView(
        clef: clef, range: range, count: count, profile: profile,
        onFinished: { controller.completeStep() })

    case .play(let clef, let range, let length):
      PlayStepView(
        exercise: Self.exercise(clef: clef, range: range, length: length),
        clef: clef,
        title: nil,
        hub: hub,
        onFinished: { controller.completeStep() })

    case .harmony(let clef, let range, let length, let voices):
      PlayStepView(
        exercise: Self.harmony(clef: clef, range: range, length: length, voices: voices),
        clef: clef,
        title: voices > 2 ? "Toque o acorde" : "Toque as duas notas juntas",
        hub: hub,
        onFinished: { controller.completeStep() })

    case .chromatic(let clef, let range, let length):
      PlayStepView(
        exercise: Self.chromatic(clef: clef, range: range, length: length),
        clef: clef,
        title: "Inclui teclas pretas",
        hub: hub,
        onFinished: { controller.completeStep() })

    case .rhythm(let clef, let pattern, let tempo, let beatsPerBar):
      RhythmStepView(
        notes: pattern.map { RhythmicNote($0.pitch, $0.value, dotted: $0.isDotted) },
        clef: clef,
        tempo: tempo,
        beatsPerBar: beatsPerBar,
        hub: hub,
        tones: tones,
        onFinished: { controller.completeStep() })

    case .bothHands(let rightRange, let leftRange, let length):
      PlayStepView(
        exercise: Self.twoHands(right: rightRange, left: leftRange, length: length),
        clef: .treble,
        title: "As duas mãos, ao mesmo tempo",
        hub: hub,
        onFinished: { controller.completeStep() })

    case .song(let song):
      PlayStepView(
        exercise: Self.exercise(for: song),
        clef: song.clef,
        title: "\(song.title) — \(song.composer)",
        hub: hub,
        onFinished: { controller.completeStep() })
    }
  }

  private static func exercise(
    clef: Clef, range: ClosedRange<UInt8>, length: Int
  ) -> Exercise {
    var generator = SystemRandomNumberGenerator()
    return ExerciseGenerator.build(
      pitches: CardDeck.naturalPitches(in: range),
      length: length,
      maxLeap: 2,
      using: &generator)
  }

  private static func twoHands(
    right: ClosedRange<UInt8>, left: ClosedRange<UInt8>, length: Int
  ) -> Exercise {
    var generator = SystemRandomNumberGenerator()
    return ExerciseGenerator.buildTwoHands(
      rightHand: CardDeck.naturalPitches(in: right),
      leftHand: CardDeck.naturalPitches(in: left),
      length: length,
      using: &generator)
  }

  /// A two-handed piece pairs each melody note with the left hand note beside
  /// it, so both sound together.
  private static func exercise(for song: Song) -> Exercise {
    guard song.isTwoHanded else {
      return Exercise(items: song.notes.map { ExerciseItem($0) })
    }

    let pairs = zip(song.notes, song.leftHandNotes)
    return Exercise(items: pairs.map { ExerciseItem(pitches: [$0, $1]) })
  }

  private static func harmony(
    clef: Clef, range: ClosedRange<UInt8>, length: Int, voices: Int
  ) -> Exercise {
    var generator = SystemRandomNumberGenerator()
    return ExerciseGenerator.buildHarmony(
      pitches: CardDeck.naturalPitches(in: range),
      length: length,
      voices: voices,
      using: &generator)
  }

  /// Black keys included: the pool is the whole range, not just the naturals.
  private static func chromatic(
    clef: Clef, range: ClosedRange<UInt8>, length: Int
  ) -> Exercise {
    var generator = SystemRandomNumberGenerator()
    return ExerciseGenerator.build(
      pitches: range.map(Pitch.init),
      length: length,
      maxLeap: 3,
      using: &generator)
  }
}

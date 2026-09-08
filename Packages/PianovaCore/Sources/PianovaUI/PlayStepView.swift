import ExerciseEngine
import ScoreModel
import SwiftUI

/// A sequence played on the instrument inside a lesson.
///
/// The same view serves a generated exercise and a piece: both are a sequence
/// of notes with a cursor walking through them.
struct PlayStepView: View {
  @StateObject private var controller: PlayRoundController
  @ObservedObject private var hub: MIDIHub

  private let onFinished: () -> Void

  init(
    exercise: Exercise,
    clef: Clef,
    title: String?,
    hub: MIDIHub,
    onFinished: @escaping () -> Void
  ) {
    _controller = StateObject(
      wrappedValue: PlayRoundController(exercise: exercise, clef: clef, title: title))
    self.hub = hub
    self.onFinished = onFinished
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      if isGrandStaff {
        GrandStaffView(
          noteGroups: noteGroups,
          states: controller.itemStates,
          staffSpace: 16
        )
        .padding(.horizontal, 8)
      } else {
        StaffView(
          clef: controller.clef,
          noteGroups: noteGroups,
          states: controller.itemStates,
          staffSpace: 18
        )
        .padding(.horizontal, 8)
      }

      feedback

      if !hub.isConnected {
        onScreenKeyboard
      }
    }
    .onAppear {
      controller.onFinished = onFinished
      hub.setListener(owner: controller) { [controller] in controller.handle($0) }
    }
    .onDisappear { hub.clearListener(owner: controller) }
  }

  private var noteGroups: [[Pitch]] {
    controller.session.exercise.items.map { Array($0.pitches) }
  }

  /// A sequence that crosses middle C in the same group needs two staves.
  private var isGrandStaff: Bool {
    noteGroups.contains { group in
      Set(group.map(\.grandStaffClef)).count > 1
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(controller.title ?? "Toque a sequência")
        .font(.system(size: 22, weight: .semibold))

      Spacer()

      Text(progress)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  private var progress: String {
    let total = controller.session.exercise.items.count
    return "\(min(controller.session.cursorIndex, total))/\(total)"
  }

  /// Shown when no instrument is connected, so the lesson still works.
  private var onScreenKeyboard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(hub.connectionError ?? "Sem instrumento — toque aqui")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)

      PianoKeyboardView(onPress: { controller.playPitch($0) })
    }
  }

  private var feedback: some View {
    HStack(spacing: 12) {
      Circle().fill(indicatorColor).frame(width: 10, height: 10)
      Text(message)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(indicatorColor)
      Spacer()
    }
    .frame(height: 26)
    .animation(.easeOut(duration: 0.12), value: message)
  }

  private var indicatorColor: Color {
    switch controller.status {
    case .waiting: return ItemState.pending.color
    case .correct, .finished: return ItemState.done.color
    case .incomplete: return ItemState.current.color
    case .mistake: return ItemState.failed.color
    }
  }

  private var message: String {
    switch controller.status {
    case .waiting:
      return "Toque a nota azul"
    case .correct(let pitch):
      return "\(pitch.scientificName) — certo"
    case .incomplete(let pitch):
      return "\(pitch.scientificName) — falta completar o acorde"
    case .mistake(let played, let expected, let movedBack):
      let tail = movedBack ? " — voltou uma posição" : " — repita"
      return "\(played.scientificName), esperava \(expected)\(tail)"
    case .finished:
      return "Completo"
    }
  }
}

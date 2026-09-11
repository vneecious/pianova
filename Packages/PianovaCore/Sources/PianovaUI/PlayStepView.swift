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

  /// The written score behind the sequence, when there is one.
  ///
  /// A generated drill has no score: it is a row of notes to find, and drawing
  /// bar lines over it would claim a rhythm nobody wrote. A piece does have
  /// one, and then the staff shows its signatures and its bars.
  private let score: Score?

  init(
    exercise: Exercise,
    clef: Clef,
    title: String?,
    hub: MIDIHub,
    score: Score? = nil,
    onFinished: @escaping () -> Void
  ) {
    _controller = StateObject(
      wrappedValue: PlayRoundController(exercise: exercise, clef: clef, title: title))
    self.hub = hub
    self.score = score
    self.onFinished = onFinished
  }

  /// Durations to draw, when the sequence came from a written piece.
  private var durations: [Duration] {
    score?.columns.map(\.duration) ?? []
  }

  /// Visual state for each drawn column.
  ///
  /// The engine tracks items played, so its states have to be spread back over
  /// the page — a rest has no state of its own and takes the one before it, so
  /// a silence inside a finished bar does not read as still pending.
  private var columnStates: [ItemState] {
    guard let score else { return controller.itemStates }

    let played = controller.itemStates
    var next = 0
    var carried: ItemState = .pending

    return score.columns.map { column in
      guard !column.isRest else { return carried == .current ? .pending : carried }
      let state = next < played.count ? played[next] : ItemState.pending
      next += 1
      carried = state
      return state
    }
  }

  /// Which written column the cursor is on.
  ///
  /// The staff draws rests; the engine cannot ask for one. So the cursor counts
  /// items played, and this turns that back into a place on the page.
  private var focusColumn: Double {
    guard let score else { return Double(controller.session.cursorIndex) }

    let sounding = score.soundingColumns
    let index = min(controller.session.cursorIndex, sounding.count - 1)
    guard index >= 0 else { return 0 }

    return Double(sounding[index])
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      if isGrandStaff {
        // A generated two-handed drill has no written staves, so pitch is all
        // there is to go on — which is right here and wrong for real music.
        GrandStaffView(
          upperGroups: noteGroups.map { $0.filter { $0.grandStaffClef == .treble } },
          lowerGroups: noteGroups.map { $0.filter { $0.grandStaffClef == .bass } },
          states: columnStates,
          staffSpace: 16
        )
        .padding(.horizontal, 8)
      } else {
        StaffView(
          clef: controller.clef,
          noteGroups: noteGroups,
          states: columnStates,
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

  /// The columns to draw.
  ///
  /// For a written piece this is everything on the page, silences included. For
  /// a generated drill it is simply the items to find.
  private var noteGroups: [[Pitch]] {
    if let score { return score.columns.map(\.pitches) }
    return controller.session.exercise.items.map { Array($0.pitches) }
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
    PianoKeyboardView(onPress: { controller.playPitch($0) })
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

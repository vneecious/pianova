import ExerciseEngine
import MIDIInput
import ScoreModel
import Sound
import SwiftUI

/// Runs one rhythmic exercise: the right notes, at the right moments.
@MainActor
final class RhythmRoundController: ObservableObject {
  /// Where the run is.
  enum Phase: Equatable {
    /// Waiting for the player to start.
    case ready
    /// Counting the bar in, with the beat number shown.
    case countIn(Int)
    /// Under way.
    case playing
    /// Every note played.
    case finished
  }

  @Published private(set) var session: RhythmSession
  @Published private(set) var phase: Phase = .ready
  @Published private(set) var lastJudgement: RhythmJudgement?
  @Published private(set) var elapsed: TimeInterval = 0

  /// Called once the run is cleared.
  var onFinished: () -> Void = {}

  private let tones: TonePlayer
  private let beatsPerBar: Int
  private var startedAt: Date?
  private var ticker: Task<Void, Never>?

  init(notes: [RhythmicNote], tempo: Double, beatsPerBar: Int, tones: TonePlayer) {
    session = RhythmSession(notes: notes, tempo: tempo)
    self.beatsPerBar = beatsPerBar
    self.tones = tones
  }

  /// Beat the playhead is on, counting from 1.
  var currentBeat: Int { Int(elapsed / session.beatDuration) + 1 }

  /// How far through the run, from 0 to 1.
  var fraction: Double {
    guard session.totalDuration > 0 else { return 0 }
    return min(elapsed / session.totalDuration, 1)
  }

  /// Counts a bar in, then starts the clock.
  func begin() {
    guard phase == .ready || phase == .finished else { return }

    session = RhythmSession(notes: session.notes, tempo: session.tempo)
    lastJudgement = nil
    elapsed = 0

    ticker?.cancel()
    ticker = Task { [weak self] in
      guard let self else { return }
      let beat = session.beatDuration

      // A bar of clicks before anything counts: rhythm cannot be judged
      // against a pulse the player has not heard yet.
      for count in 1...beatsPerBar {
        phase = .countIn(count)
        tones.click(isAccent: count == 1)
        try? await Task.sleep(for: .seconds(beat))
        if Task.isCancelled { return }
      }

      phase = .playing
      startedAt = Date()

      while !Task.isCancelled, phase == .playing {
        if let startedAt {
          elapsed = Date().timeIntervalSince(startedAt)
        }
        if elapsed > session.totalDuration + beat { finish() }
        try? await Task.sleep(for: .milliseconds(16))
      }
    }
  }

  /// Stops the clock, when the screen goes away mid-run.
  func stop() {
    ticker?.cancel()
    ticker = nil
  }

  /// Applies one key event.
  /// - Parameter event: The event decoded from the instrument.
  func handle(_ event: MIDIKeyEvent) {
    guard case .pressed(let pitch, _) = event else { return }
    play(pitch)
  }

  /// Plays a key, from the instrument or the screen.
  /// - Parameter pitch: The key that was struck.
  func play(_ pitch: Pitch) {
    guard phase == .playing, let startedAt else { return }

    let judgement = session.press([pitch], at: Date().timeIntervalSince(startedAt))
    lastJudgement = judgement

    if judgement.isFinished { finish() }
  }

  private func finish() {
    ticker?.cancel()
    ticker = nil
    phase = .finished
    onFinished()
  }
}

/// The rhythmic exercise screen.
struct RhythmStepView: View {
  @EnvironmentObject private var tones: TonePlayer
  @ObservedObject var hub: MIDIHub
  @StateObject private var controller: RhythmRoundController

  private let clef: Clef
  private let onFinished: () -> Void

  init(
    notes: [RhythmicNote],
    clef: Clef,
    tempo: Double,
    beatsPerBar: Int,
    hub: MIDIHub,
    tones: TonePlayer,
    onFinished: @escaping () -> Void
  ) {
    _controller = StateObject(
      wrappedValue: RhythmRoundController(
        notes: notes, tempo: tempo, beatsPerBar: beatsPerBar, tones: tones))
    self.hub = hub
    self.clef = clef
    self.onFinished = onFinished
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      ZStack(alignment: .topLeading) {
        StaffView(
          clef: clef,
          noteGroups: controller.session.notes.map { Array($0.pitches) },
          states: states,
          durations: controller.session.notes.map(\.duration),
          staffSpace: 20)

        playhead
      }
      .padding(.horizontal, 8)

      feedback

      if !hub.isConnected {
        PianoKeyboardView(onPress: { controller.play($0) })
      }

      Spacer(minLength: 0)
    }
    .onAppear {
      controller.onFinished = onFinished
      hub.setListener(owner: controller) { [controller] in controller.handle($0) }
    }
    .onDisappear {
      hub.clearListener(owner: controller)
      controller.stop()
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("Toque no tempo")
        .font(.system(size: 22, weight: .semibold))

      Spacer()

      Text("\(Int(controller.session.tempo)) bpm")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .monospacedDigit()

      if controller.phase == .ready || controller.phase == .finished {
        Button(controller.phase == .finished ? "De novo" : "Começar") { controller.begin() }
          .keyboardShortcut(.defaultAction)
      }
    }
  }

  /// A line sweeping across the staff at the written tempo.
  ///
  /// Reading rhythm is reading time as space; the playhead makes that literal.
  @ViewBuilder
  private var playhead: some View {
    if controller.phase == .playing {
      GeometryReader { proxy in
        Rectangle()
          .fill(ItemState.current.color.opacity(0.55))
          .frame(width: 2)
          .offset(x: proxy.size.width * controller.fraction)
      }
    }
  }

  private var states: [ItemState] {
    controller.session.notes.indices.map { index in
      if index < controller.session.index { return .done }
      if index == controller.session.index && controller.phase == .playing { return .current }
      return .pending
    }
  }

  private var feedback: some View {
    HStack(spacing: 10) {
      Circle().fill(feedbackColor).frame(width: 10, height: 10)
      Text(message)
        .font(.system(size: 16, weight: .medium, design: .rounded))
        .foregroundStyle(feedbackColor)
        .monospacedDigit()
      Spacer()
    }
    .frame(height: 26)
  }

  private var feedbackColor: Color {
    switch controller.phase {
    case .ready: return ItemState.pending.color
    case .countIn: return ItemState.current.color
    case .finished: return ItemState.done.color
    case .playing:
      switch controller.lastJudgement?.verdict {
      case .onTime, .none: return ItemState.done.color
      default: return ItemState.failed.color
      }
    }
  }

  private var message: String {
    switch controller.phase {
    case .ready:
      return "Ouça a contagem e entre no primeiro tempo"
    case .countIn(let beat):
      return String(repeating: "• ", count: beat).trimmingCharacters(in: .whitespaces)
    case .finished:
      return summary
    case .playing:
      guard let judgement = controller.lastJudgement else { return "Tocando…" }
      switch judgement.verdict {
      case .onTime: return "No tempo"
      case .early: return "Adiantou \(milliseconds(judgement.offset)) ms"
      case .late: return "Atrasou \(milliseconds(judgement.offset)) ms"
      case .wrongNote: return "Nota errada"
      case .missed: return "Passou"
      }
    }
  }

  private var summary: String {
    let off = controller.session.offBeatCount
    let wrong = controller.session.wrongNoteCount

    if off == 0 && wrong == 0 { return "Perfeito — tudo no tempo" }
    return "\(off) fora do tempo, \(wrong) nota(s) errada(s)"
  }

  private func milliseconds(_ offset: TimeInterval) -> Int {
    Int(abs(offset) * 1000)
  }
}

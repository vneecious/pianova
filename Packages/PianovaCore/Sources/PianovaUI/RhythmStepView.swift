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
    /// Stopped on a mistake, about to retake the bar.
    case recovering
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

  /// Which note the guide line has reached, and how far past it.
  ///
  /// Time is what the run measures, but the staff is laid out in columns, so
  /// the clock has to be converted into a column before anything is drawn.
  var playheadPosition: (column: Int, progress: Double) {
    let notes = session.notes
    guard !notes.isEmpty else { return (0, 0) }

    for index in notes.indices {
      let start = session.onset(of: index)
      let end = session.onset(of: index + 1)
      if elapsed < end {
        let span = end - start
        return (index, span > 0 ? min(max((elapsed - start) / span, 0), 1) : 0)
      }
    }

    return (notes.count, 0)
  }

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
    start(from: 0)
  }

  /// Goes back to the bar the mistake happened in and retakes it.
  ///
  /// Letting the music carry on after an error is the worst of both worlds: the
  /// pulse is lost and the rest is played wrong anyway. Going back a bar is
  /// what anyone practising actually does.
  private func recover() {
    let landing = session.firstNote(
      ofBarContaining: session.index, beatsPerBar: beatsPerBar)

    ticker?.cancel()
    ticker = nil
    phase = .recovering

    ticker = Task { [weak self] in
      guard let self else { return }
      // A beat of silence so the mistake registers before the count starts.
      try? await Task.sleep(for: .seconds(session.beatDuration))
      if Task.isCancelled { return }
      session.rewind(to: landing)
      start(from: landing)
    }
  }

  /// Counts in, then runs the clock from a given note.
  private func start(from noteIndex: Int) {
    let resumeAt = session.onset(of: noteIndex)
    elapsed = resumeAt

    ticker?.cancel()
    ticker = Task { [weak self] in
      guard let self else { return }
      let beat = session.beatDuration

      // A bar of clicks before anything counts: rhythm cannot be judged
      // against a pulse the player has not heard yet. It happens again on
      // every retake, for the same reason.
      for count in 1...beatsPerBar {
        phase = .countIn(count)
        tones.click(isAccent: count == 1)
        try? await Task.sleep(for: .seconds(beat))
        if Task.isCancelled { return }
      }

      phase = .playing
      // Wound back so the clock reads as if the run had reached this note.
      startedAt = Date().addingTimeInterval(-resumeAt)

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

    if judgement.isFinished {
      finish()
    } else if judgement.verdict != .onTime {
      recover()
    }
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
  @EnvironmentObject private var metronome: Metronome
  @ObservedObject var hub: MIDIHub
  @StateObject private var controller: RhythmRoundController

  private let clef: Clef
  private let onFinished: () -> Void

  /// The written piece behind the rhythm, when there is one.
  ///
  /// With it the exercise is drawn exactly like the free mode — systems, bar
  /// numbers, signatures — because the same piece read two ways should not
  /// look like two different things.
  private let score: Score?

  init(
    notes: [RhythmicNote],
    clef: Clef,
    tempo: Double,
    beatsPerBar: Int,
    hub: MIDIHub,
    tones: TonePlayer,
    score: Score? = nil,
    onFinished: @escaping () -> Void
  ) {
    self.score = score
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

      if let score {
        ScoreSheetView(
          score: score,
          states: states,
          focusColumn: controller.session.index,
          staffSpace: 16,
          playhead: controller.phase == .playing
            ? PlayheadPosition(
              column: controller.playheadPosition.column,
              progress: controller.playheadPosition.progress)
            : nil
        )
        .frame(minHeight: 260)
        .padding(.horizontal, 8)
      } else {
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
      }

      feedback

      if !hub.isConnected {
        PianoKeyboardView(onPress: { controller.play($0) })
      }

      Spacer(minLength: 0)
    }
    .onAppear {
      controller.onFinished = onFinished
      hub.setListener(owner: controller) { [controller] in controller.handle($0) }
      // This exercise counts itself in. Two pulses at once is noise, and the
      // one being judged against is this one.
      metronome.suspend()
    }
    .onDisappear {
      metronome.resume()
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
  /// Reading rhythm is reading time as space, and the guide line makes that
  /// literal. Positioned through ``StaffLayout``, the same arithmetic that
  /// places the note heads: sweeping the view width instead starts the line at
  /// the far left edge — before the clef — so it points at nothing and reads as
  /// running ahead of the music.
  @ViewBuilder
  private var playhead: some View {
    if controller.phase == .playing {
      GeometryReader { proxy in
        let layout = StaffLayout(
          staffSpace: 20, width: proxy.size.width,
          columnCount: controller.session.notes.count)
        let position = controller.playheadPosition

        Rectangle()
          .fill(ItemState.current.color.opacity(0.55))
          .frame(width: 2)
          .offset(
            x: layout.playheadX(column: position.column, progress: position.progress))
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
    case .recovering: return ItemState.failed.color
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
    case .recovering:
      return "Vamos refazer este compasso"
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

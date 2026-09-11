import ExerciseEngine
import MIDIInput
import NoteQuiz
import Progress
import ScoreModel
import Sound
import SwiftUI

/// Continuous reading: the music does not wait.
///
/// Every other exercise in the app holds the cursor until the right key is
/// played. That is right for accuracy and wrong for flow — reading is
/// continuous, and an exercise that always waits trains hesitation. Here the
/// playhead keeps going and a note you miss is simply gone.
@MainActor
final class ReadingController: ObservableObject {
  /// Where the run is.
  enum Phase: Equatable {
    /// Waiting for the first note. Nothing is timed yet.
    case ready
    /// Under way.
    case playing
    /// Over.
    case finished
  }

  @Published private(set) var session: RhythmSession
  @Published private(set) var phase: Phase = .ready
  @Published private(set) var elapsed: TimeInterval = 0
  @Published var tempo: Double = 60
  @Published var clef: Clef = .treble

  private let tones: TonePlayer
  private var startedAt: Date?
  private var ticker: Task<Void, Never>?

  init(tones: TonePlayer) {
    self.tones = tones
    session = ReadingController.makeSession(clef: .treble, tempo: 60)
  }

  /// Which note the playhead has reached, and how far past it.
  ///
  /// Positioning by time through the note onsets, rather than sweeping the
  /// whole width, is what keeps the line and the note heads in step — and it
  /// stays correct when the figures have different lengths.
  var playheadPosition: (column: Int, progress: Double) {
    guard !session.notes.isEmpty else { return (0, 0) }

    var column = 0
    while column + 1 < session.notes.count, elapsed >= session.onset(of: column + 1) {
      column += 1
    }

    let start = session.onset(of: column)
    let span = session.notes[column].duration.beats * session.beatDuration
    let progress = span > 0 ? (elapsed - start) / span : 0

    return (column, min(max(progress, 0), 1))
  }

  /// Notes played in time, out of the notes that went by.
  var score: (hit: Int, total: Int) {
    let resolved = session.outcomes.compactMap { $0 }
    return (resolved.filter { $0 == .onTime }.count, resolved.count)
  }

  /// How many notes went by untouched.
  var missed: Int { session.missedCount }

  /// How many were played, but off the beat.
  var offBeat: Int {
    session.outcomes.compactMap { $0 }.filter { $0 == .early || $0 == .late }.count
  }

  /// Deals a new line and waits for the player.
  ///
  /// Nothing is timed until the first note is played. Hands are on the
  /// instrument, so the instrument should be what starts the line — and the
  /// player's own first note becomes beat one, which is why no count-in is
  /// needed here.
  func deal() {
    ticker?.cancel()
    ticker = nil
    startedAt = nil
    elapsed = 0
    session = Self.makeSession(clef: clef, tempo: tempo)
    phase = .ready
  }

  /// The note that will start the line.
  var openingNote: Pitch? {
    phase == .ready ? session.notes.first?.pitches.first : nil
  }

  private func startClock() {
    startedAt = Date()
    phase = .playing

    ticker = Task { [weak self] in
      guard let self else { return }
      let beat = session.beatDuration
      var nextClick = 0.0

      while !Task.isCancelled, phase == .playing {
        guard let startedAt else { break }
        elapsed = Date().timeIntervalSince(startedAt)

        // A pulse from the first note on, so the tempo is heard, not guessed.
        if elapsed >= nextClick {
          tones.click(isAccent: Int(nextClick / beat) % 4 == 0)
          nextClick += beat
        }

        // The line moves whether or not the player keeps up.
        session.advance(to: elapsed)

        if session.isFinished || elapsed > session.totalDuration + beat {
          phase = .finished
          ticker = nil
          return
        }
        try? await Task.sleep(for: .milliseconds(16))
      }
    }
  }

  /// Stops the clock.
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

  /// Plays a key.
  /// - Parameter pitch: The key struck.
  func play(_ pitch: Pitch) {
    switch phase {
    case .ready:
      // The first note is the downbeat: it starts the clock and is on time by
      // definition. A wrong key simply does not start anything.
      guard session.currentNote?.pitches == [pitch] else { return }
      startClock()
      _ = session.press([pitch], at: 0)

    case .playing:
      guard let startedAt else { return }
      _ = session.press([pitch], at: Date().timeIntervalSince(startedAt))

    case .finished:
      break
    }
  }

  /// A line of even quarter notes, so only the pitches have to be read.
  private static func makeSession(clef: Clef, tempo: Double) -> RhythmSession {
    var generator = SystemRandomNumberGenerator()
    let range: ClosedRange<UInt8> = clef == .treble ? 60...79 : 43...60
    let exercise = ExerciseGenerator.build(
      pitches: CardDeck.naturalPitches(in: range),
      length: 16, maxLeap: 3, using: &generator)

    return RhythmSession(
      notes: exercise.items.compactMap { item in
        item.pitches.first.map { RhythmicNote($0, .quarter) }
      },
      tempo: tempo)
  }
}

/// The continuous reading screen.
struct ReadingView: View {
  @EnvironmentObject private var tones: TonePlayer
  @ObservedObject var hub: MIDIHub
  @StateObject private var controller: ReadingController

  /// Called when the player leaves.
  let onExit: () -> Void

  init(hub: MIDIHub, tones: TonePlayer, onExit: @escaping () -> Void) {
    _controller = StateObject(wrappedValue: ReadingController(tones: tones))
    self.hub = hub
    self.onExit = onExit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      settingsBar
      Divider()
      header

      // The staff draws its own guide line: it is the only one who knows the
      // real layout. A line drawn outside was built without the durations and
      // without the preamble, so it ran in equal columns from the page edge —
      // misaligned with every note and reading as far too fast.
      StaffView(
        clef: controller.clef,
        noteGroups: controller.session.notes.map { Array($0.pitches) },
        states: states,
        durations: controller.session.notes.map(\.duration),
        staffSpace: 18,
        playhead: playheadPosition
      )
      .padding(.horizontal, 8)

      if !hub.isConnected {
        PianoKeyboardView(onPress: { controller.play($0) })
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 20)
    .onAppear {
      hub.setListener(owner: controller) { [controller] in controller.handle($0) }
      controller.deal()
    }
    .onDisappear {
      hub.clearListener(owner: controller)
      controller.stop()
    }
  }

  private var settingsBar: some View {
    HStack(spacing: 18) {
      Picker("", selection: $controller.clef) {
        Text("Sol").tag(Clef.treble)
        Text("Fá").tag(Clef.bass)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 130)
      .onChange(of: controller.clef) { controller.deal() }

      Picker("", selection: $controller.tempo) {
        Text("40 bpm").tag(40.0)
        Text("60 bpm").tag(60.0)
        Text("80 bpm").tag(80.0)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 240)
      .onChange(of: controller.tempo) { controller.deal() }

      Spacer()

      Button("Nova linha") { controller.deal() }
        .keyboardShortcut(.defaultAction)

      Button {
        onExit()
      } label: {
        Label("Sair", systemImage: "xmark")
      }
      .buttonStyle(.borderless)
      .keyboardShortcut(.cancelAction)
    }
    .font(.system(size: 12))
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.system(size: 20, weight: .semibold))

      Spacer()

      let score = controller.score
      if score.total > 0 {
        HStack(spacing: 14) {
          tally("\(score.hit)", "no tempo", ItemState.done.color)
          if controller.offBeat > 0 {
            tally("\(controller.offBeat)", "fora do tempo", ItemState.failed.color)
          }
          if controller.missed > 0 {
            tally("\(controller.missed)", "perdidas", ItemState.failed.color)
          }
        }
      }
    }
  }

  private func tally(_ value: String, _ label: String, _ color: Color) -> some View {
    HStack(spacing: 4) {
      Text(value)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(color)
        .monospacedDigit()
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
  }

  private var title: String {
    switch controller.phase {
    case .ready:
      guard let opening = controller.openingNote else { return "Pronto" }
      return "Toque \(opening.solfegeWithOctave) para começar"
    case .playing:
      return "Acompanhe — a linha não espera"
    case .finished:
      let score = controller.score
      return score.hit == score.total ? "Linha inteira no tempo" : "Fim da linha"
    }
  }

  /// Where the guide line is, while the line is being played.
  private var playheadPosition: PlayheadPosition? {
    guard controller.phase == .playing else { return nil }
    let position = controller.playheadPosition
    return PlayheadPosition(column: position.column, progress: position.progress)
  }

  /// Colour every note by what actually happened to it.
  ///
  /// Without this a note the line left behind looks exactly like one played in
  /// time, which is the same as showing no feedback at all.
  private var states: [ItemState] {
    controller.session.notes.indices.map { index in
      switch controller.session.outcome(of: index) {
      case .onTime: return .done
      case .early, .late, .missed, .wrongNote: return .failed
      case nil:
        let isNext = index == controller.session.index
        let isWaiting = controller.phase == .ready && index == 0
        return isNext && (controller.phase == .playing || isWaiting) ? .current : .pending
      }
    }
  }
}

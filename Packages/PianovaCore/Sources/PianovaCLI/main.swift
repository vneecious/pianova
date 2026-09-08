// Pianova CLI — plays one exercise against the real instrument.
//
// A throwaway harness to feel the interaction model before any UI exists:
// it wires Core MIDI straight into ExerciseSession and prints the cursor.
//
//   swift run --package-path Packages/PianovaCore PianovaCLI
//   swift run --package-path Packages/PianovaCore PianovaCLI 120
//
// The number is how many seconds to listen for.

import ExerciseEngine
import Foundation
import MIDIInput
import ScoreModel

/// ANSI escapes, so the cursor and mistakes are readable at a glance.
enum Style {
  static let reset = "\u{1B}[0m"
  static let bold = "\u{1B}[1m"
  static let dim = "\u{1B}[2m"
  static let green = "\u{1B}[32m"
  static let red = "\u{1B}[31m"
  static let cyan = "\u{1B}[36m"
}

/// Holds the session and prints it, guarded by a lock because Core MIDI
/// delivers on its own thread.
final class ExerciseRunner: @unchecked Sendable {
  private let lock = NSLock()
  private var session: ExerciseSession

  init(exercise: Exercise) {
    session = ExerciseSession(exercise: exercise)
  }

  /// Prints the starting state.
  func begin() {
    lock.lock()
    let line = Self.render(session)
    lock.unlock()
    print("\n\(line)")
    print("\(Style.dim)toque a nota entre colchetes\(Style.reset)\n")
    fflush(stdout)
  }

  /// Feeds one event to the session and reports what happened.
  /// - Parameter event: The event decoded from the instrument.
  /// - Returns: `true` once the exercise is complete.
  func handle(_ event: MIDIKeyEvent) -> Bool {
    guard case .pressed(let pitch, _) = event else { return false }

    lock.lock()
    let expected = session.currentItem
    let outcome = session.press(pitch, at: Date().timeIntervalSinceReferenceDate)
    let line = Self.render(session)
    let finished = session.isFinished
    let landedOn = session.currentItem
    lock.unlock()

    let status: String
    switch outcome {
    case .advanced:
      status = "\(Style.green)✓ \(pitch.scientificName)\(Style.reset)"
    case .incomplete:
      status = "\(Style.dim)… \(pitch.scientificName) (falta completar o acorde)\(Style.reset)"
    case .wrong:
      let wanted = expected.map(Self.name(of:)) ?? "?"
      let back = landedOn.map(Self.name(of:)) ?? "?"
      status =
        "\(Style.red)✗ \(pitch.scientificName) — esperava \(wanted), voltou para \(back)"
        + "\(Style.reset)"
    case .finished:
      status = "\(Style.green)✓ \(pitch.scientificName)\(Style.reset)"
    }

    print("\(line)   \(status)")
    fflush(stdout)
    return finished
  }

  private static func name(of item: ExerciseItem) -> String {
    item.pitches.map(\.scientificName).sorted().joined(separator: "+")
  }

  private static func render(_ session: ExerciseSession) -> String {
    session.exercise.items.enumerated()
      .map { index, item in
        let name = name(of: item)
        if index < session.cursorIndex {
          return "\(Style.green)\(name)\(Style.reset)"
        }
        if index == session.cursorIndex {
          return "\(Style.bold)\(Style.cyan)[\(name)]\(Style.reset)"
        }
        return "\(Style.dim)\(name)\(Style.reset)"
      }
      .joined(separator: " ")
  }
}

/// A C major scale, C4 up to C5, one note per item.
let scale = [60, 62, 64, 65, 67, 69, 71, 72].map { ExerciseItem(Pitch(UInt8($0))) }

func run() {
  let seconds = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 120 : 120
  let runner = ExerciseRunner(exercise: Exercise(items: scale))
  let source = CoreMIDIEventSource()

  do {
    let names = source.sourceNames
    try source.start { event in
      if runner.handle(event) {
        print("\n\(Style.green)\(Style.bold)exercício completo\(Style.reset)\n")
        fflush(stdout)
        exit(0)
      }
    }
    print("conectado a: \(names.joined(separator: ", "))")
  } catch {
    print("erro ao abrir o MIDI: \(error)")
    exit(1)
  }

  runner.begin()
  RunLoop.current.run(until: Date().addingTimeInterval(seconds))
  print("\n\(Style.dim)tempo esgotado\(Style.reset)")
  source.stop()
}

run()

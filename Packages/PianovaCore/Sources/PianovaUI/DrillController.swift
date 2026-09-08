import ExerciseEngine
import Foundation
import MIDIInput
import ScoreModel
import Sound
import SwiftUI

/// Runs the endless drill: a new prompt the moment the last one is cleared.
///
/// Holds no rules of its own: ``DrillGenerator`` builds prompts,
/// ``ExerciseSession`` tracks the cursor and ``DrillStats`` keeps the tally,
/// all covered by tests.
@MainActor
public final class DrillController: ObservableObject {
  /// What the drill draws from.
  ///
  /// Changing it starts a fresh prompt.
  @Published public var settings: DrillSettings {
    didSet {
      guard settings != oldValue else { return }
      newPrompt()
    }
  }

  /// What is being asked right now.
  @Published public private(set) var prompt: DrillPrompt

  /// The run through the current prompt.
  @Published public private(set) var session: ExerciseSession

  /// Running tally, since a drill has no end to report.
  @Published public private(set) var stats = DrillStats()

  /// The last key played wrongly, shown until the next press.
  @Published public private(set) var lastWrong: Pitch?

  /// Sounds ear prompts.
  ///
  /// Attached by the view, which is where the environment is available.
  private weak var tones: TonePlayer?

  /// Creates a drill.
  /// - Parameter settings: What to draw from.
  public init(settings: DrillSettings = DrillSettings()) {
    var generator = SystemRandomNumberGenerator()
    let first = DrillGenerator.next(settings: settings, using: &generator)

    self.settings = settings
    prompt = first
    session = ExerciseSession(exercise: Self.exercise(for: first))
  }

  /// Gives the drill a voice, so an ear prompt can be heard.
  /// - Parameter tones: The player to sound notes through.
  public func attach(_ tones: TonePlayer) {
    guard self.tones !== tones else { return }
    self.tones = tones
    if prompt.style == .ear { soundPrompt() }
  }

  /// Plays the current prompt aloud, one note after another.
  public func soundPrompt() {
    guard prompt.style == .ear, let tones else { return }

    let pitches = prompt.pitches
    Task {
      for (index, pitch) in pitches.enumerated() {
        if index > 0 { try? await Task.sleep(for: .milliseconds(520)) }
        tones.play(pitch)
      }
    }
  }

  /// Visual state for each note of the prompt.
  public var itemStates: [ItemState] {
    session.exercise.items.indices.map { index in
      if index < session.cursorIndex { return .done }
      if index == session.cursorIndex { return lastWrong == nil ? .current : .failed }
      return .pending
    }
  }

  /// Throws the current prompt away and draws another.
  public func skip() {
    stats.record(wasClean: false)
    newPrompt()
  }

  /// Plays a key from the on-screen keyboard.
  /// - Parameter pitch: The key that was pressed.
  public func playPitch(_ pitch: Pitch) {
    handle(.pressed(pitch, velocity: 80))
  }

  /// Applies one key event.
  /// - Parameter event: The event decoded from the instrument.
  public func handle(_ event: MIDIKeyEvent) {
    guard case .pressed(let pitch, _) = event else { return }

    switch session.press(pitch, at: Date().timeIntervalSinceReferenceDate) {
    case .advanced, .incomplete:
      lastWrong = nil
    case .wrong:
      lastWrong = pitch
    case .finished:
      lastWrong = nil
      stats.record(wasClean: session.mistakeCount == 0)
      newPrompt()
    }
  }

  private func newPrompt() {
    var generator = SystemRandomNumberGenerator()
    let next = DrillGenerator.next(settings: settings, using: &generator)

    prompt = next
    session = ExerciseSession(exercise: Self.exercise(for: next))
    lastWrong = nil

    // An ear prompt is the sound: it has to be heard the moment it comes up.
    if next.style == .ear { soundPrompt() }
  }

  private static func exercise(for prompt: DrillPrompt) -> Exercise {
    Exercise(items: prompt.pitches.map { ExerciseItem($0) })
  }
}

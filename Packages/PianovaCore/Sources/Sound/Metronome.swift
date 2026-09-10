import Foundation
import SwiftUI

/// A metronome that can be left running, on any screen.
///
/// Separate from the count-in an exercise plays for itself: this one is the
/// player's, kept on while working at a piece, and it has to survive changing
/// screens.
@MainActor
public final class Metronome: ObservableObject {
  /// Slowest and fastest the dial goes.
  nonisolated public static let range: ClosedRange<Double> = 40...208

  /// Whether the player asked for it.
  @Published public private(set) var isOn = false

  // Clamping happens in the setter, never in a `didSet`. Assigning to an
  // `@Published` property from inside its own `didSet` goes back through the
  // wrapper's setter and calls the observer again — infinite recursion and a
  // dead process, which is exactly how this crashed the whole test suite.
  @Published private var storedTempo: Double = 72
  @Published private var storedBeatsPerBar: Int = 4

  /// Beats per minute, held inside what a metronome can mean.
  public var tempo: Double {
    get { storedTempo }
    set {
      storedTempo = min(max(newValue, Self.range.lowerBound), Self.range.upperBound)
      if isOn { restart() }
    }
  }

  /// Beats to the bar, so the first one can be accented.
  public var beatsPerBar: Int {
    get { storedBeatsPerBar }
    set {
      storedBeatsPerBar = max(newValue, 1)
      if isOn { restart() }
    }
  }

  /// A binding for controls that edit the bar length.
  public var beatsPerBarBinding: Binding<Int> {
    Binding(get: { self.beatsPerBar }, set: { self.beatsPerBar = $0 })
  }

  /// Which beat is sounding, counting from 1, or `0` when silent.
  @Published public private(set) var beat = 0

  /// What actually makes the sound, given whether the beat is accented.
  ///
  /// A closure rather than the whole player: a metronome needs one click, not
  /// an audio engine, and taking the engine made it impossible to test without
  /// booting real audio and loading fifty-five megabytes of samples.
  private let click: @MainActor (Bool) -> Void
  private var ticker: Task<Void, Never>?

  /// Whether an exercise has taken the pulse over for itself.
  private var isSuspended = false

  /// Creates a metronome.
  /// - Parameter click: Makes one sound; the flag says whether it is the accent.
  public init(click: @escaping @MainActor (Bool) -> Void) {
    self.click = click
  }

  /// Creates a metronome that clicks through a player.
  /// - Parameter tones: Where the click comes from.
  public convenience init(tones: TonePlayer) {
    self.init { isAccent in tones.click(isAccent: isAccent) }
  }

  /// Whether a click is actually sounding right now.
  public var isSounding: Bool { isOn && !isSuspended }

  /// Turns it on or off.
  public func toggle() {
    isOn.toggle()
    isOn ? restart() : silence()
  }

  /// Silences the metronome while an exercise runs its own pulse.
  ///
  /// Two pulses at once is noise, and the exercise's own count is the one being
  /// judged against.
  public func suspend() {
    isSuspended = true
    stopTicker()
  }

  /// Gives the pulse back once the exercise is done.
  public func resume() {
    isSuspended = false
    if isOn { restart() }
  }

  private func silence() {
    stopTicker()
    beat = 0
  }

  private func stopTicker() {
    ticker?.cancel()
    ticker = nil
  }

  private func restart() {
    stopTicker()
    guard isSounding else { return }

    let interval = 60 / max(tempo, 1)
    let started = Date()

    ticker = Task { [weak self] in
      var count = 0

      while !Task.isCancelled {
        guard let self else { return }

        count += 1
        beat = (count - 1) % beatsPerBar + 1
        click(beat == 1)

        // Scheduled against the start, never by adding up sleeps: adding up
        // accumulates the error of every wake-up, and a metronome that drifts
        // is worse than none.
        let target = started.addingTimeInterval(Double(count) * interval)
        let wait = target.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
      }
    }
  }
}

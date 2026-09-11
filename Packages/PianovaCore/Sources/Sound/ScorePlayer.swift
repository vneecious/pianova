import Foundation
import ScoreModel

/// Plays a score back, as a reference for how it should sound.
///
/// Nothing here is judged. Hearing the piece before working at it is how anyone
/// learns a tune, and a beginner who has never heard it is decoding symbols
/// with no idea what they are aiming for.
@MainActor
public final class ScorePlayer: ObservableObject {
  /// Whether playback is running.
  @Published public private(set) var isPlaying = false

  /// Which column is sounding, for the staff to follow.
  @Published public private(set) var column = 0

  private let tones: TonePlayer
  private var task: Task<Void, Never>?

  /// Creates a player.
  /// - Parameter tones: Where the sound comes from.
  public init(tones: TonePlayer) {
    self.tones = tones
  }

  /// How long a score lasts at a tempo.
  /// - Parameters:
  ///   - score: The piece.
  ///   - tempo: Beats per minute.
  /// - Returns: Its length in seconds.
  public nonisolated static func duration(of score: Score, tempo: Double) -> TimeInterval {
    let beats = score.columns.reduce(0.0) { $0 + $1.duration.beats }
    return beats * (60 / max(tempo, 1))
  }

  /// Plays the piece, or a stretch of it, on one hand or both.
  ///
  /// A passage is played as part of the piece rather than as a piece of its
  /// own, so the column reported here is the column the page has engraved and
  /// the highlight lands where the sound is.
  /// - Parameters:
  ///   - score: The piece to play.
  ///   - tempo: Beats per minute.
  ///   - start: The column to begin at. Studying is repeating a passage, not
  ///     the whole piece, so going back to the top every time is the wrong
  ///     default.
  ///   - end: One past the last column, or `nil` to play to the end.
  ///   - hands: Which hands should sound.
  public func play(
    _ score: Score, tempo: Double = 72, from start: Int = 0, through end: Int? = nil,
    hands: PracticeHands = .both
  ) {
    stop()

    let beat = 60 / max(tempo, 1)
    let last = min(end ?? score.columns.count, score.columns.count)
    let first = min(max(start, 0), max(last - 1, 0))
    isPlaying = true
    column = first

    task = Task { [weak self] in
      guard let self else { return }

      for index in first..<max(last, first) {
        if Task.isCancelled { break }
        let event = score.columns[index]
        column = index

        for pitch in event.pitches(for: hands) {
          tones.play(pitch, velocity: 74)
        }

        try? await Task.sleep(for: .seconds(event.duration.beats * beat))
      }

      if !Task.isCancelled { finish() }
    }
  }

  /// Stops playback, leaving nothing ringing.
  public func stop() {
    task?.cancel()
    task = nil
    tones.stopAll()
    isPlaying = false
  }

  private func finish() {
    task = nil
    isPlaying = false
  }
}

/// How a piece is worked at.
public enum PlayMode: String, CaseIterable, Sendable, Identifiable {
  /// The staff waits for you: right note, any moment.
  case free
  /// The staff does not wait: right note, right moment.
  case inTime

  /// Stable identity for `ForEach`.
  public var id: String { rawValue }

  /// The name shown to the player.
  public var title: String {
    switch self {
    case .free: return "Livre"
    case .inTime: return "No tempo"
    }
  }

  /// One line on what it asks of you.
  public var detail: String {
    switch self {
    case .free: return "A pauta espera por você. Nota certa, no seu ritmo."
    case .inTime: return "A pauta não espera. Nota certa, no momento certo."
    }
  }
}

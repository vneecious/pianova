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

  /// How hard each written dynamic strikes (rule 141).
  ///
  /// The scale every keyboardist carries: piano soft, forte firm, the rest
  /// in between. No mark plays the usual middle touch.
  /// - Parameter dynamic: The mark in force, or `nil` for none.
  /// - Returns: The MIDI velocity to strike with.
  public nonisolated static func velocity(for dynamic: String?) -> UInt8 {
    switch dynamic {
    case "ppp": return 24
    case "pp": return 34
    case "p": return 46
    case "mp": return 58
    case "mf": return 70
    case "f": return 84
    case "ff": return 98
    case "fff": return 110
    case "sf", "sfz", "fp": return 90
    default: return 74
    }
  }

  /// The touch of every column, written marks and ramps applied (rule 141).
  ///
  /// Steps come from the dynamic in force. A written "cresc." (or "dim.")
  /// ramps from there: linearly into the next explicit mark when one exists;
  /// with no target written, a step and a half over up to four bars — the
  /// usual editorial reading — and the new level holds.
  /// - Parameter score: The piece.
  /// - Returns: One velocity per column.
  public nonisolated static func touches(for score: Score) -> [UInt8] {
    let dynamics = score.columnDynamics
    let words = score.columnWords
    let beats = score.columns.map(\.beats)
    var touches = dynamics.map { Int(velocity(for: $0)) }

    for index in touches.indices {
      guard let word = words[index]?.lowercased(),
        word.contains("cresc") || word.contains("dim") || word.contains("decresc")
      else { continue }
      let rising = word.contains("cresc") && !word.contains("decresc")
      let from = touches[index]

      // The ramp runs to the next explicit mark; without one, it grows a
      // step and a half over up to four bars and the level holds.
      var end = touches.count
      var goal: Int
      if let marked = ((index + 1)..<touches.count)
        .first(where: { dynamics[$0] != dynamics[index] }
        )
      {
        end = marked
        goal = Int(velocity(for: dynamics[marked]))
      } else {
        goal = max(20, min(112, from + (rising ? 16 : -16)))
        let horizon = beats[index] + 4 * score.timeSignature.barBeats
        end = ((index + 1)..<touches.count).first(where: { beats[$0] >= horizon }) ?? touches.count
        for later in end..<touches.count { touches[later] = goal }
      }

      let span = end - index
      guard span > 1 else { continue }
      for step in 1..<span {
        let fraction = Double(step) / Double(span)
        touches[index + step] = Int(
          (Double(from) + (Double(goal) - Double(from)) * fraction).rounded())
      }
    }

    return touches.map { UInt8(max(1, min(127, $0))) }
  }

  /// One thing to sound, at its instant on the wall clock (rule 139).
  public struct PlaybackNote: Equatable, Sendable {
    /// Seconds from the start of playback.
    public let time: TimeInterval

    /// What sounds together.
    public let pitches: [Pitch]

    /// How hard it is struck.
    public let velocity: UInt8

    /// The column it belongs to — `nil` for an ornament, which the page
    /// does not follow.
    public let column: Int?
  }

  /// The whole run, note by note, each with its absolute instant.
  ///
  /// Computed up front so playing is only "sleep until, then sound" — adding
  /// relative waits accumulates scheduling slack and the rhythm drifts. The
  /// ornament sounds BEFORE the beat, as quick pickups in the tail of the
  /// previous column; the decorated note lands exactly on the grid (rule 139).
  /// - Parameters:
  ///   - score: The piece.
  ///   - order: The columns in playing order.
  ///   - tempo: Beats per minute.
  ///   - hands: Which hands should sound.
  /// - Returns: The notes to play, in time order.
  public nonisolated static func schedule(
    for score: Score, order: [Int], tempo: Double, hands: PracticeHands
  ) -> [PlaybackNote] {
    let beat = 60 / max(tempo, 1)
    let columns = score.columns
    let graces = score.columnGraces
    let touches = touches(for: score)

    var notes: [PlaybackNote] = []
    var time = 0.0
    var previousStart = 0.0

    for index in order {
      guard columns.indices.contains(index) else { continue }
      let touch = touches.indices.contains(index) ? touches[index] : 74

      if hands != .left, graces.indices.contains(index), !graces[index].isEmpty {
        let pickups = graces[index]
        let lead = min(0.08, beat * 0.15)
        let earliest = max(previousStart + 0.02, time - Double(pickups.count) * lead)

        if earliest < time {
          for (offset, pitch) in pickups.enumerated() {
            let when = earliest + (time - earliest) * Double(offset) / Double(pickups.count)
            notes.append(
              PlaybackNote(
                time: when, pitches: [pitch],
                velocity: max(touch, 12) - 8, column: nil))
          }
        }
      }

      notes.append(
        PlaybackNote(
          time: time, pitches: columns[index].pitches(for: hands),
          velocity: touch, column: index))
      previousStart = time
      time += columns[index].duration.beats * beat
    }

    return notes
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

    // A full play-through honours the ritornello (rule 137); a passage under
    // study is the player's own loop and stays as chosen.
    let order =
      (first == 0 && end == nil)
      ? score.playbackColumns
      : Array(first..<max(last, first))
    let notes = Self.schedule(for: score, order: order, tempo: tempo, hands: hands)
    let total = order.reduce(0.0) { $0 + score.columns[$1].duration.beats * beat }

    task = Task { [weak self] in
      guard let self else { return }
      let clock = ContinuousClock()
      let started = clock.now

      for note in notes {
        if Task.isCancelled { break }
        try? await clock.sleep(
          until: started + .seconds(note.time), tolerance: .milliseconds(5))
        if Task.isCancelled { break }

        if let column = note.column { self.column = column }
        for pitch in note.pitches {
          tones.play(pitch, velocity: note.velocity)
        }
      }

      try? await clock.sleep(
        until: started + .seconds(total), tolerance: .milliseconds(10))
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

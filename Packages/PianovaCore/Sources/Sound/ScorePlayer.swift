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

    /// What stops sounding here, let go before anything is struck (rule 142).
    public let releases: [Pitch]

    /// Creates a note of the schedule.
    public init(
      time: TimeInterval, pitches: [Pitch], velocity: UInt8, column: Int?,
      releases: [Pitch] = []
    ) {
      self.time = time
      self.pitches = pitches
      self.velocity = velocity
      self.column = column
      self.releases = releases
    }
  }

  /// One key going down: where its tie chain starts and how long it holds.
  private struct Strike {
    let pitch: Pitch
    let sustainBeats: Double
  }

  /// Every strike of a part, keyed by its column moment.
  ///
  /// A tie chain is one strike: the continuation never re-attacks, and the
  /// sustain runs to the chain's end (rule 142). Quantised to the same
  /// 720-per-crotchet grid the columns use, so the keys meet.
  private nonisolated static func strikes(of part: Part) -> [Double: [Strike]] {
    var strikes: [Double: [Strike]] = [:]
    var open: [Pitch: (start: Double, beats: Double)] = [:]
    var carried: Set<Pitch> = []
    var elapsed = 0.0

    for note in part.notes {
      let time = (elapsed * 720).rounded() / 720

      for pitch in note.pitches {
        if carried.contains(pitch), let chain = open[pitch] {
          open[pitch] = (chain.start, chain.beats + note.beats)
        } else {
          open[pitch] = (time, note.beats)
        }
      }

      if note.isTiedToNext {
        carried = Set(note.pitches)
      } else {
        for pitch in note.pitches {
          if let chain = open.removeValue(forKey: pitch) {
            strikes[chain.start, default: []]
              .append(
                Strike(pitch: pitch, sustainBeats: chain.beats))
          }
        }
        carried = []
      }
      elapsed += note.beats
    }

    // A tie into nothing still has to let go somewhere: at its chain's end.
    for (pitch, chain) in open {
      strikes[chain.start, default: []]
        .append(
          Strike(pitch: pitch, sustainBeats: chain.beats))
    }

    return strikes
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
    let pedals = score.columnPedals
    let touches = touches(for: score)
    let upperStrikes = strikes(of: score.rightHand)
    let lowerStrikes = score.leftHand.map(strikes(of:)) ?? [:]

    var notes: [PlaybackNote] = []
    var offs: [(pitch: Pitch, strike: TimeInterval, off: TimeInterval)] = []
    var pedalSpans: [(down: TimeInterval, lift: TimeInterval)] = []
    var pedalDownAt: TimeInterval?
    var time = 0.0
    var previousStart = 0.0

    for index in order {
      guard columns.indices.contains(index) else { continue }
      let touch = touches.indices.contains(index) ? touches[index] : 74

      // The written damper opens and closes spans of held sound (rule 142).
      if let mark = pedals.indices.contains(index) ? pedals[index] : nil {
        if mark != .down, let down = pedalDownAt {
          pedalSpans.append((down, time))
          pedalDownAt = nil
        }
        if mark != .up { pedalDownAt = time }
      }

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
            offs.append((pitch, when, time))
          }
        }
      }

      // A tie continuation is not struck again: only chains that start here
      // sound, each carrying its own written sustain (rule 142).
      let moment = columns[index].beats
      var struck: [Strike] = []
      if hands != .left { struck += upperStrikes[moment] ?? [] }
      if hands != .right { struck += lowerStrikes[moment] ?? [] }

      notes.append(
        PlaybackNote(
          time: time, pitches: struck.map(\.pitch),
          velocity: touch, column: index))
      for strike in struck {
        offs.append((strike.pitch, time, time + strike.sustainBeats * beat))
      }

      previousStart = time
      time += columns[index].duration.beats * beat
    }
    if let down = pedalDownAt { pedalSpans.append((down, time)) }

    // The damper holds a note past its written end, until the star (rule 142);
    // and a pitch struck again while ringing is let go right at the restrike.
    let restrikes = offs.map { (pitch: $0.pitch, at: $0.strike) }
    for index in offs.indices {
      var off = offs[index].off
      if let span = pedalSpans.first(where: { $0.down < off && off < $0.lift }) {
        off = span.lift
      }
      let next =
        restrikes
        .filter { $0.pitch == offs[index].pitch && $0.at > offs[index].strike }
        .map(\.at).min()
      if let next, next < off { off = next }
      offs[index].off = off
    }

    // Releases join the event already at their instant, or get one of their
    // own; within an event everything lets go before anything is struck.
    func slot(_ time: TimeInterval) -> Int64 { Int64((time * 1_000_000).rounded()) }
    var releasesAt: [Int64: [Pitch]] = [:]
    for off in offs { releasesAt[slot(off.off), default: []].append(off.pitch) }

    notes = notes.map { note in
      guard let releases = releasesAt.removeValue(forKey: slot(note.time)) else { return note }
      return PlaybackNote(
        time: note.time, pitches: note.pitches, velocity: note.velocity,
        column: note.column, releases: releases)
    }
    for (key, pitches) in releasesAt {
      notes.append(
        PlaybackNote(
          time: Double(key) / 1_000_000, pitches: [], velocity: 0,
          column: nil, releases: pitches))
    }

    return notes.sorted { $0.time < $1.time }
  }

  /// The tempo a piece is heard at: the written one, or a reading pace.
  ///
  /// A score that declares its tempo — the number behind the "Allegretto" —
  /// is heard at it (rule 138). One that does not gets a pace to read at:
  /// reading speed is not performance speed, and eighth-based metres count
  /// faster beats.
  /// - Parameter score: The piece.
  /// - Returns: Beats per minute.
  public nonisolated static func readingTempo(for score: Score) -> Double {
    score.tempo ?? (score.timeSignature.beatValue == .eighth ? 108 : 72)
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
        for pitch in note.releases {
          tones.release(pitch)
        }
        for pitch in note.pitches {
          tones.strike(pitch, velocity: note.velocity)
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

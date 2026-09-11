import Foundation

/// Why a MusicXML file could not be read.
///
/// Refusing with a reason is the point. A half-read import produces a score
/// that looks right and is silently wrong, which is worse than no import at
/// all — the player would practise the mistake.
public enum MusicXMLError: Error, Equatable, Sendable {
  /// The bytes were not XML at all.
  case notXML
  /// No `score-partwise` element: probably timewise, or not MusicXML.
  case notPartwise
  /// The file has no measures.
  case empty
  /// A note gave no duration, so its place in time cannot be known.
  case noteWithoutDuration(measure: Int)
  /// The divisions-per-quarter was missing or nonsense.
  case badDivisions
  /// The file is for an ensemble, not for a keyboard.
  case notForPiano(instruments: Int)

  /// What to tell the player.
  public var message: String {
    switch self {
    case .notXML:
      return "Este arquivo não é XML."
    case .notPartwise:
      return "Só leio MusicXML no formato score-partwise."
    case .empty:
      return "O arquivo não tem compasso nenhum."
    case .noteWithoutDuration(let measure):
      return "O compasso \(measure) tem uma nota sem duração."
    case .badDivisions:
      return "O arquivo não diz quantas divisões valem uma semínima."
    case .notForPiano(let instruments):
      return "Esta partitura tem \(instruments) instrumentos. Só leio piano."
    }
  }
}

/// Reads a MusicXML file into a ``Score``.
///
/// Deliberately narrow: one part, one voice per staff, notes, rests, dots, ties
/// and chords. That is everything the course needs and everything a beginner's
/// sheet contains. Anything else is refused by name rather than guessed at.
public enum MusicXMLImporter {
  /// Reads a score from MusicXML data.
  /// - Parameter data: The file contents.
  /// - Returns: The score.
  /// - Throws: ``MusicXMLError`` when the file cannot be read faithfully.
  public static func score(from data: Data) throws -> Score {
    let parser = Parser()
    guard parser.parse(data) else { throw MusicXMLError.notXML }
    guard parser.sawPartwise else { throw MusicXMLError.notPartwise }
    guard !parser.measures.isEmpty else { throw MusicXMLError.empty }
    if let failure = parser.failure { throw failure }

    return try build(from: parser)
  }

  /// Reads a score from a file.
  /// - Parameter url: Where the file is.
  /// - Returns: The score.
  /// - Throws: ``MusicXMLError``, or whatever reading the file threw.
  public static func score(at url: URL) throws -> Score {
    let data = try Data(contentsOf: url)
    var score = try score(from: data)

    if score.title.isEmpty {
      score = score.retitled(url.deletingPathExtension().lastPathComponent)
    }
    return score
  }

  /// Turns the parsed events into a score.
  private static func build(from parser: Parser) throws -> Score {
    guard parser.divisions > 0 else { throw MusicXMLError.badDivisions }

    // A piano score reaches us one of two ways: one part with two staves, or
    // two parts with one staff each. Both are common, and the difference is
    // the publisher's, not the music's.
    let byPart = parser.measuresByPart
    let names = parser.partNames

    /// Parts that call themselves a keyboard.
    let keyboards = names.indices.filter {
      let lowered = names[$0].lowercased()
      return ["piano", "keyboard", "harpsichord", "cravo", "teclado"]
        .contains {
          lowered.contains($0)
        }
    }

    /// Two parts of equal length are the two hands of one piece.
    func pair(_ a: Int, _ b: Int) -> ([RawMeasure], [RawMeasure])? {
      guard let first = byPart[a], let second = byPart[b], first.count == second.count,
        !first.isEmpty
      else { return nil }
      return (first, second)
    }

    let upper: [RawMeasure]
    let lower: [RawMeasure]

    // Order matters, and getting it wrong is what made a two-part sonatina come
    // out as one hand: a small file is a piano piece whatever its parts are
    // called, and only a large one needs the names to pick a keyboard out.
    if byPart.count <= 1 {
      upper = parser.measures
      lower = []
    } else if byPart.count == 2, let (first, second) = pair(0, 1) {
      upper = first
      lower = second
    } else if keyboards.count >= 2, let (first, second) = pair(keyboards[0], keyboards[1]) {
      upper = first
      lower = second
    } else if let single = keyboards.first, let only = byPart[single] {
      // One keyboard part inside a larger score: its own two staves are split
      // out below, by the staff number on each note.
      upper = only
      lower = []
    } else {
      // Reading the first two instruments of an ensemble as two hands gives a
      // score that looks plausible and is nonsense. Refuse instead.
      throw MusicXMLError.notForPiano(instruments: byPart.count)
    }

    var right: [Measure] = []
    var left: [Measure] = []

    for (index, raw) in upper.enumerated() {
      let staffTwo = lower.isEmpty ? raw.events.filter { $0.staff == 2 } : lower[index].events
      let staffOne = lower.isEmpty ? raw.events.filter { $0.staff != 2 } : raw.events

      right.append(
        try measure(
          from: staffOne, parser: parser, number: index + 1,
          repeatStart: raw.repeatStart, repeatEnd: raw.repeatEnd))
      if !staffTwo.isEmpty {
        left.append(try measure(from: staffTwo, parser: parser, number: index + 1))
      }
    }

    let hasLeft = !left.isEmpty && left.count == right.count

    return Score(
      title: parser.title,
      composer: parser.composer.isEmpty ? "—" : parser.composer,
      timeSignature: TimeSignature(
        beatsPerBar: max(parser.beatsPerBar, 1),
        beatValue: noteValue(forBeatType: parser.beatType)),
      key: KeySignature(fifths: parser.fifths),
      rightHand: Part(clef: .treble, measures: right),
      leftHand: hasLeft ? Part(clef: .bass, measures: left) : nil,
      hasPickup: isPickup(right.first, parser: parser))
  }

  /// Builds one bar from events that may overlap and may be out of order.
  ///
  /// Several voices can share a staff, each written as its own pass over the
  /// bar. Rather than try to keep them independent — which this app has nowhere
  /// to draw — every moment where anything begins becomes one column holding
  /// whatever starts there, lasting until the next moment.
  ///
  /// That is the same shape the rest of the app already uses, it keeps every
  /// note, and it makes the bar add up by construction.
  private static func measure(
    from events: [RawEvent],
    parser: Parser,
    number: Int,
    repeatStart: Bool = false,
    repeatEnd: Bool = false
  ) throws -> Measure {
    let sounding = events.filter { !$0.pitches.isEmpty }

    for event in events where event.divisions <= 0 && !event.isChord {
      throw MusicXMLError.noteWithoutDuration(measure: number)
    }

    // Every moment anything starts — silences included, or a bar ending in a
    // rest would simply lose it. A moment where no voice sounds becomes a rest
    // column; a moment where one voice rests while another plays does not.
    var moments = Set(events.filter { !$0.isChord }.map(\.start))
    let barLength =
      events.map { $0.start + $0.divisions }.max()
      ?? Int(
        Double(parser.divisions) * Double(parser.beatsPerBar)
          * noteValue(forBeatType: parser.beatType).beats)

    // A bar that begins in silence keeps that silence.
    if let first = moments.min(), first > 0 { moments.insert(0) }
    if moments.isEmpty { moments.insert(0) }

    let ordered = moments.sorted()
    var notes: [ScoreNote] = []

    for (index, moment) in ordered.enumerated() {
      let next = index + 1 < ordered.count ? ordered[index + 1] : barLength
      let span = max(next - moment, 1)
      let struck = sounding.filter { $0.start == moment }
      // Marks come from every event at the moment, rests included: a dynamic
      // or a pedal written over a rest rides that rest, and gathering marks
      // only from sounding events silently dropped them.
      let marked = events.filter { $0.start == moment && !$0.isChord } + struck
      let pitches = struck.flatMap(\.pitches)

      // Fingering rides its pitch through the merge and the sort. Zero means
      // "none written on this one", which keeps a partially fingered chord
      // aligned.
      var fingerOfPitch: [Pitch: Int] = [:]
      for raw in struck {
        for (index, pitch) in raw.pitches.enumerated()
        where raw.fingers.indices.contains(index) {
          fingerOfPitch[pitch] = raw.fingers[index]
        }
      }

      let orderedPitches = Array(Set(pitches)).sorted { $0.midiNoteNumber < $1.midiNoteNumber }
      let fingers = orderedPitches.map { fingerOfPitch[$0] ?? 0 }

      notes.append(
        ScoreNote(
          pitches: orderedPitches,
          duration: duration(divisions: span, perQuarter: parser.divisions),
          isTiedToNext: struck.first?.isTiedToNext ?? false,
          fingers: fingers.allSatisfy { $0 == 0 } ? [] : fingers,
          pedal: marked.compactMap(\.pedal).first,
          pedalLine: marked.contains { $0.pedalLine },
          ottava: marked.compactMap(\.ottava).first,
          slurStart: marked.contains { $0.slurStart },
          slurStop: marked.contains { $0.slurStop },
          dynamic: marked.compactMap(\.dynamic).first,
          words: marked.compactMap(\.words).first,
          articulations: marked.reduce(into: Set<Articulation>()) {
            $0.formUnion($1.articulations)
          }))
    }

    return Measure(notes, repeatStart: repeatStart, repeatEnd: repeatEnd)
  }

  /// Whether the opening bar is short, which is what an upbeat is.
  private static func isPickup(_ first: Measure?, parser: Parser) -> Bool {
    guard let first, parser.beatsPerBar > 0 else { return false }

    let full = Double(parser.beatsPerBar) * noteValue(forBeatType: parser.beatType).beats
    return first.beats > 0 && first.beats < full - 0.001
  }

  /// Turns MusicXML divisions into a written figure.
  ///
  /// Divisions are however many units the file chose to call a crotchet, so the
  /// ratio is what matters and the absolute number never does.
  static func duration(divisions: Int, perQuarter: Int) -> Duration {
    let quarters = Double(divisions) / Double(perQuarter)

    // Dotted first: a dotted minim is three quarters, which would otherwise be
    // rounded to whichever plain figure happens to be nearer.
    for value in NoteValue.allCases {
      if abs(quarters - value.beats * 1.5) < 0.01 { return Duration(value, dotted: true) }
      if abs(quarters - value.beats) < 0.01 { return Duration(value) }
    }

    // Nothing matched: fall back to the nearest plain figure rather than refuse,
    // since an unusual tuplet still has to land somewhere on the page.
    let nearest =
      NoteValue.allCases.min { abs($0.beats - quarters) < abs($1.beats - quarters) } ?? .quarter
    return Duration(nearest)
  }

  /// The figure one beat lasts, from the lower number of the time signature.
  static func noteValue(forBeatType beatType: Int) -> NoteValue {
    switch beatType {
    case 1: return .whole
    case 2: return .half
    case 8: return .eighth
    default: return .quarter
    }
  }
}

extension Score {
  /// The same score under another name, for when the file supplied none.
  /// - Parameter title: The title to use.
  /// - Returns: A copy with the new title.
  public func retitled(_ title: String) -> Score {
    Score(
      title: title, composer: composer, timeSignature: timeSignature, key: key,
      rightHand: rightHand, leftHand: leftHand, hasPickup: hasPickup)
  }
}

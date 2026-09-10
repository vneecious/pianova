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

    var right: [Measure] = []
    var left: [Measure] = []

    for (index, raw) in parser.measures.enumerated() {
      var top: [ScoreNote] = []
      var bottom: [ScoreNote] = []

      for event in raw.events {
        guard event.divisions > 0 else {
          throw MusicXMLError.noteWithoutDuration(measure: index + 1)
        }

        let note = ScoreNote(
          pitches: event.pitches,
          duration: duration(divisions: event.divisions, perQuarter: parser.divisions),
          isTiedToNext: event.isTiedToNext)

        // A chord shares the previous event's moment rather than following it.
        if event.isChord, let previous = (event.staff == 2 ? bottom : top).last {
          let merged = ScoreNote(
            pitches: previous.pitches + event.pitches,
            duration: previous.duration,
            isTiedToNext: previous.isTiedToNext)
          if event.staff == 2 {
            bottom[bottom.count - 1] = merged
          } else {
            top[top.count - 1] = merged
          }
          continue
        }

        if event.staff == 2 { bottom.append(note) } else { top.append(note) }
      }

      right.append(Measure(top))
      if !bottom.isEmpty { left.append(Measure(bottom)) }
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

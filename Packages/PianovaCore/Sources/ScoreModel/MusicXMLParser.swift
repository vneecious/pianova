import Foundation

extension MusicXMLImporter {
  /// One written event as the file states it, before it becomes a ``ScoreNote``.
  struct RawEvent {
    /// The pitches, empty for a rest.
    var pitches: [Pitch] = []
    /// How long it lasts, in the file's own divisions.
    var divisions = 0
    /// Which staff it belongs to: 1 is the upper, 2 the lower.
    var staff = 1
    /// Whether it sounds with the event before it rather than after.
    var isChord = false
    /// Whether it is tied into what follows.
    var isTiedToNext = false
  }

  /// One bar as the file states it.
  struct RawMeasure {
    var events: [RawEvent] = []
  }

  /// Pulls the handful of MusicXML elements the course needs out of the file.
  ///
  /// `XMLParser` rather than a full document model: the files are streamed once
  /// and only a dozen element names matter, so there is nothing to gain from
  /// holding the whole tree.
  final class Parser: NSObject, XMLParserDelegate {
    private(set) var sawPartwise = false
    private(set) var measures: [RawMeasure] = []
    private(set) var divisions = 0
    private(set) var beatsPerBar = 4
    private(set) var beatType = 4
    private(set) var fifths = 0
    private(set) var title = ""
    private(set) var composer = ""
    private(set) var failure: MusicXMLError?

    private var element = ""
    private var text = ""
    private var creatorType = ""

    private var measure = RawMeasure()
    private var event = RawEvent()
    private var inNote = false

    // The pitch being assembled, since step, alter and octave arrive apart.
    private var step = ""
    private var alter = 0
    private var octave = 4

    /// Reads the data.
    /// - Parameter data: The file contents.
    /// - Returns: Whether it parsed as XML at all.
    func parse(_ data: Data) -> Bool {
      let parser = XMLParser(data: data)
      parser.delegate = self
      return parser.parse()
    }

    func parser(
      _ parser: XMLParser,
      didStartElement name: String,
      namespaceURI: String?,
      qualifiedName: String?,
      attributes: [String: String]
    ) {
      element = name
      text = ""

      switch name {
      case "score-partwise":
        sawPartwise = true
      case "measure":
        measure = RawMeasure()
      case "note":
        inNote = true
        event = RawEvent()
        step = ""
        alter = 0
        octave = 4
      case "chord":
        event.isChord = true
      case "rest":
        event.pitches = []
      case "tie":
        if attributes["type"] == "start" { event.isTiedToNext = true }
      case "creator":
        creatorType = attributes["type"] ?? ""
      default:
        break
      }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
      text += string
    }

    func parser(
      _ parser: XMLParser,
      didEndElement name: String,
      namespaceURI: String?,
      qualifiedName: String?
    ) {
      let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

      switch name {
      case "divisions":
        divisions = Int(value) ?? divisions
      case "beats":
        beatsPerBar = Int(value) ?? beatsPerBar
      case "beat-type":
        beatType = Int(value) ?? beatType
      case "fifths":
        fifths = Int(value) ?? fifths
      case "work-title", "movement-title":
        if title.isEmpty { title = value }
      case "creator":
        if creatorType == "composer" && composer.isEmpty { composer = value }
      case "step":
        step = value
      case "alter":
        alter = Int(value) ?? 0
      case "octave":
        octave = Int(value) ?? 4
      case "staff":
        event.staff = Int(value) ?? 1
      case "duration":
        if inNote { event.divisions = Int(value) ?? 0 }
      case "pitch":
        if let pitch = Self.pitch(step: step, alter: alter, octave: octave) {
          event.pitches = [pitch]
        }
      case "note":
        inNote = false
        measure.events.append(event)
      case "measure":
        measures.append(measure)
      default:
        break
      }

      text = ""
    }

    /// Turns a step, alteration and octave into a MIDI pitch.
    ///
    /// MusicXML octave 4 is the one containing middle C, and middle C is MIDI
    /// 60 — so the arithmetic is fixed and needs no configuration.
    static func pitch(step: String, alter: Int, octave: Int) -> Pitch? {
      let semitones: [String: Int] = [
        "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
      ]
      guard let base = semitones[step.uppercased()] else { return nil }

      let number = (octave + 1) * 12 + base + alter
      guard (0...127).contains(number) else { return nil }

      return Pitch(UInt8(number))
    }
  }
}

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
    /// Whether it is a grace note — an ornament with no time of its own.
    var isGrace = false
    /// A pedal instruction written just before this note.
    var pedal: PedalMark?
    /// Whether that pedal is the line style rather than the sign style.
    var pedalLine = false
    /// An octave line starting or stopping at this note.
    var ottava: OttavaMark?
    /// Whether a phrase slur begins here.
    var slurStart = false
    /// Whether a phrase slur ends here.
    var slurStop = false
    /// A dynamic written at this note.
    var dynamic: String?
    /// A word written at this note.
    var words: String?
    /// The articulations written on this note.
    var articulations: Set<Articulation> = []
    /// Written fingering, one number per pitch of this raw note.
    var fingers: [Int] = []
    /// When it begins, in divisions from the start of its bar.
    ///
    /// Real files do not write a bar in playing order. A piano part writes the
    /// upper staff, rewinds with `<backup>`, writes the lower one, rewinds
    /// again for a second voice. Without a cursor those all pile up end to end
    /// and every bar comes out several times too long.
    var start = 0
    /// Which part of the file it came from, for scores split across parts.
    var part = 0
  }

  /// One bar as the file states it.
  struct RawMeasure {
    var events: [RawEvent] = []
    /// Whether a repeat begins at this bar's opening barline.
    var repeatStart = false
    /// Whether a repeat closes at this bar's final barline.
    var repeatEnd = false
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

    /// One `<direction>` being read: its marks and, at the end, its staff.
    ///
    /// A buffer per direction, folded into the pendings only when it closes —
    /// sharing one target staff let a later direction's staff overwrite an
    /// earlier one's, and the dynamic sailed into the wrong hand.
    private struct OpenDirection {
      var pedal: PedalMark?
      var pedalLine = false
      var ottava: OttavaMark?
      var dynamic: String?
      var words: String?
      var staff: Int?
    }

    private var direction: OpenDirection?

    /// Directions read but not yet attached, each with its own target staff.
    private var pendingPedal: (mark: PedalMark, line: Bool, staff: Int?)?
    private var pendingOttava: (mark: OttavaMark, staff: Int?)?
    private var pendingDynamic: (mark: String, staff: Int?)?
    private var pendingWords: String?
    private var inWords = false
    private var inDynamics = false

    /// Where in the bar the next note falls, in divisions.
    private var cursor = 0

    /// Where the note just written began, so a chord can join it.
    private var lastStart = 0

    /// How many `<part>` elements have been seen.
    private var partIndex = -1

    /// Bars indexed by part, so parts become staves instead of a longer piece.
    private(set) var measuresByPart: [Int: [RawMeasure]] = [:]

    /// The name of each part, in the order the file declares them.
    ///
    /// What tells a piano score from an orchestral one. Reading the first two
    /// instruments of an orchestral file as two hands produces a score that
    /// looks plausible and is nonsense.
    private(set) var partNames: [String] = []
    private var inPartList = false

    /// Duration read inside `<backup>` or `<forward>`, which are not notes.
    private var shiftDivisions = 0
    private var inShift = false

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
      case "part-list":
        inPartList = true
      case "part":
        if !inPartList { partIndex += 1 }
      case "measure":
        measure = RawMeasure()
        cursor = 0
        lastStart = 0
      case "backup", "forward":
        inShift = true
        shiftDivisions = 0
      case "note":
        inNote = true
        event = RawEvent()
        step = ""
        alter = 0
        octave = 4
      case "chord":
        event.isChord = true
      case "repeat":
        if attributes["direction"] == "forward" { measure.repeatStart = true }
        if attributes["direction"] == "backward" { measure.repeatEnd = true }
      case "grace":
        event.isGrace = true
      case "slur":
        if attributes["type"] == "start" { event.slurStart = true }
        if attributes["type"] == "stop" { event.slurStop = true }
      case "staccato":
        event.articulations.insert(.staccato)
      case "accent":
        event.articulations.insert(.accent)
      case "tenuto":
        event.articulations.insert(.tenuto)
      case "trill-mark":
        event.articulations.insert(.trill)
      case "direction":
        direction = OpenDirection()
      case "pedal":
        direction?.pedalLine = attributes["line"] == "yes"
        switch attributes["type"] {
        case "start", "resume": direction?.pedal = .down
        case "stop": direction?.pedal = .up
        case "change": direction?.pedal = .change
        default: break
        }
      case "octave-shift":
        switch attributes["type"] {
        case "down": direction?.ottava = .startAbove
        case "up": direction?.ottava = .startBelow
        case "stop": direction?.ottava = .stop
        default: break
        }
      case "dynamics":
        inDynamics = true
      case "words":
        inWords = true
        text = ""
      case "p", "pp", "ppp", "f", "ff", "fff", "mp", "mf", "sf", "fp", "sfz":
        if inDynamics { direction?.dynamic = name }
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
      case "part-name":
        if inPartList { partNames.append(value) }
      case "part-list":
        inPartList = false
      case "step":
        step = value
      case "alter":
        alter = Int(value) ?? 0
      case "octave":
        octave = Int(value) ?? 4
      case "staff":
        // Inside a note it names the note's staff; inside a direction it
        // names the staff the direction is FOR — the pedal written under the
        // bass must not ride a treble note into the wrong hand.
        if inNote {
          event.staff = Int(value) ?? 1
        } else if direction != nil {
          direction?.staff = Int(value)
        }
      case "duration":
        if inNote {
          event.divisions = Int(value) ?? 0
        } else if inShift {
          shiftDivisions = Int(value) ?? 0
        }
      case "backup":
        cursor = max(cursor - shiftDivisions, 0)
        inShift = false
      case "forward":
        cursor += shiftDivisions
        inShift = false
      case "pitch":
        if let pitch = Self.pitch(step: step, alter: alter, octave: octave) {
          event.pitches = [pitch]
        }
      case "fingering":
        if let finger = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
          event.fingers.append(finger)
        }
      case "note":
        inNote = false
        event.part = max(partIndex, 0)

        // An ornament has no time of its own and is not judged (rule 127).
        // It is kept — anchored where the cursor stands, so the importer can
        // hang it on the note it decorates — but it takes no pending
        // directions and moves no cursor: the dynamic, the pedal and the
        // octave line written before it belong to the real note after it.
        if event.isGrace {
          event.start = cursor
          measure.events.append(event)
          break
        }

        // Whatever direction was read since the last note belongs to the next
        // note on the direction's own staff — a pedal written under the bass
        // must not ride a treble note into the wrong hand.
        if let pending = pendingPedal, pending.staff == nil || pending.staff == event.staff {
          event.pedal = pending.mark
          event.pedalLine = pending.line
          pendingPedal = nil
        }
        if let pending = pendingOttava, pending.staff == nil || pending.staff == event.staff {
          event.ottava = pending.mark
          pendingOttava = nil
        }
        if let pending = pendingDynamic, pending.staff == nil || pending.staff == event.staff {
          event.dynamic = pending.mark
          pendingDynamic = nil
        }
        if pendingWords != nil {
          event.words = pendingWords
          pendingWords = nil
        }

        // A chord shares the moment of the note it hangs off, and does not move
        // the cursor; anything else starts where the cursor is and advances it.
        if event.isChord {
          event.start = lastStart
        } else {
          event.start = cursor
          lastStart = cursor
          cursor += event.divisions
        }

        measure.events.append(event)
      case "measure":
        measures.append(measure)
        measuresByPart[max(partIndex, 0), default: []].append(measure)
      case "dynamics":
        inDynamics = false
      case "direction":
        // The direction folds into the pendings only now, staff and all.
        if let closed = direction {
          if let pedal = closed.pedal {
            // A release still waiting when the next press arrives is one
            // motion: up-and-down again, the pedal change.
            let merged: PedalMark =
              (pendingPedal?.mark == .up && pedal == .down) ? .change : pedal
            pendingPedal = (merged, closed.pedalLine, closed.staff)
          }
          if let ottava = closed.ottava { pendingOttava = (ottava, closed.staff) }
          if let dynamic = closed.dynamic { pendingDynamic = (dynamic, closed.staff) }
          if let words = closed.words { pendingWords = words }
        }
        direction = nil
      case "words":
        inWords = false
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { direction?.words = words }
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

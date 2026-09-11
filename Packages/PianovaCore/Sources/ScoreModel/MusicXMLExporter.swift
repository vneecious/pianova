import Foundation

/// Writes a score out as MusicXML.
///
/// Needed because the pieces of the course are written in Swift, and an
/// engraver reads files. It is also the same format the importer reads, so a
/// piece can make the round trip and be compared with itself.
public enum MusicXMLExporter {
  /// How many divisions one crotchet is split into.
  ///
  /// Sixty keeps every figure whole, tuplets included: a triplet quaver is 20,
  /// a quintuplet semiquaver 12. Four sufficed until tuplets arrived; a
  /// fraction rounded on the way out is a bar that does not add up.
  public static let divisions = 60

  /// Writes a score.
  ///
  /// One part, one or two staves. A piano is one instrument: written as two
  /// parts, the engraver refuses it the brace, floats the pedal between the
  /// staves, and spaces the systems as if two players shared the page.
  /// - Parameter score: The piece.
  /// - Returns: The MusicXML for it.
  public static func musicXML(for score: Score) -> String {
    let bars = score.rightHand.measures.indices
      .map { measure($0, score: score) }
      .joined()

    return """
      <?xml version="1.0" encoding="UTF-8"?>
      <score-partwise version="4.0">
      <work><work-title>\(escape(score.title))</work-title></work>
      <identification><creator type="composer">\(escape(score.composer))</creator></identification>
      <part-list><score-part id="P1"><part-name></part-name></score-part></part-list>
      <part id="P1">\(bars)</part>
      </score-partwise>
      """
  }

  /// Which alteration the key and the bar so far imply for each written line.
  ///
  /// The classic reading rule (rule 133): the key signature alters its letter
  /// in every octave, an accidental alters its own line until the barline, and
  /// only a note that contradicts what is in force prints one.
  private struct AccidentalState {
    private var inForce: [String: Int] = [:]
    private let fromKey: [String: Int]

    init(key: KeySignature) {
      let alter = key.usesSharps ? 1 : -1
      fromKey = Dictionary(
        uniqueKeysWithValues: key.alteredLetters.map {
          (String(describing: $0).uppercased(), alter)
        })
    }

    /// The accidental this note must print, if the reading needs one.
    mutating func accidental(letter: String, octave: Int, alter: Int) -> String? {
      let line = "\(letter)\(octave)"
      let implied = inForce[line] ?? fromKey[letter] ?? 0
      inForce[line] = alter
      guard alter != implied else { return nil }
      switch alter {
      case 1: return "sharp"
      case -1: return "flat"
      default: return "natural"
      }
    }
  }

  private static func measure(_ index: Int, score: Score) -> String {
    let bar = score.rightHand.measures[index]
    let lower = score.leftHand.flatMap {
      $0.measures.indices.contains(index) ? $0.measures[index] : nil
    }
    var body = ""

    if index == 0 {
      let beatType = Int((4 / score.timeSignature.beatValue.beats).rounded())
      let clefs =
        lower == nil
        ? clef(score.rightHand.clef, number: nil)
        : "<staves>2</staves>" + clef(score.rightHand.clef, number: 1) + clef(.bass, number: 2)
      body += """
        <attributes><divisions>\(divisions)</divisions>
        <key><fifths>\(score.key.fifths)</fifths></key>
        <time><beats>\(score.timeSignature.beatsPerBar)</beats>\
        <beat-type>\(beatType)</beat-type></time>
        \(clefs)</attributes>
        """
    }

    if bar.repeatStart {
      body +=
        "<barline location=\"left\"><bar-style>heavy-light</bar-style>"
        + "<repeat direction=\"forward\"/></barline>"
    }

    // Each staff reads its own accidentals, and each bar starts clean.
    var upperState = AccidentalState(key: score.key)
    let upperBeams = beamMarks(for: bar, beat: score.timeSignature.beatValue.beats)
    body += bar.notes.enumerated()
      .map { index, event in
        note(
          event, staff: lower == nil ? nil : 1, voice: 1, beam: upperBeams[index],
          accidentals: &upperState)
      }
      .joined()

    if let lower {
      // Rewind to the bar's start and write the second staff over the same
      // time — which is how one instrument's two staves share a measure.
      let barLength = Int((bar.beats * Double(divisions)).rounded())
      body += "<backup><duration>\(barLength)</duration></backup>"
      var lowerState = AccidentalState(key: score.key)
      let lowerBeams = beamMarks(for: lower, beat: score.timeSignature.beatValue.beats)
      body += lower.notes.enumerated()
        .map { index, event in
          note(event, staff: 2, voice: 2, beam: lowerBeams[index], accidentals: &lowerState)
        }
        .joined()
    }

    if bar.repeatEnd {
      body +=
        "<barline location=\"right\"><bar-style>light-heavy</bar-style>"
        + "<repeat direction=\"backward\"/></barline>"
    }

    return "<measure number=\"\(index + 1)\">\(body)</measure>"
  }

  private static func clef(_ clef: Clef, number: Int?) -> String {
    let sign = clef == .treble ? "<sign>G</sign><line>2</line>" : "<sign>F</sign><line>4</line>"
    let attribute = number.map { " number=\"\($0)\"" } ?? ""
    return "<clef\(attribute)>\(sign)</clef>"
  }

  /// The beam grouping a bar goes out with (rule 135).
  ///
  /// The edition's own marks win when the bar carries any; a bar without them
  /// gets what a typesetter would do — beamable figures grouped by beat, a
  /// rest or a longer figure breaking the group, a group of one left alone.
  private static func beamMarks(for bar: Measure, beat: Double) -> [BeamMark?] {
    if bar.notes.contains(where: { $0.beam != nil }) { return bar.notes.map(\.beam) }

    var marks = [BeamMark?](repeating: nil, count: bar.notes.count)
    var group: [Int] = []

    func close() {
      if group.count >= 2, let first = group.first, let last = group.last {
        marks[first] = .begin
        marks[last] = .end
        for index in group.dropFirst().dropLast() { marks[index] = .middle }
      }
      group = []
    }

    var time = 0.0
    for (index, event) in bar.notes.enumerated() {
      let intoBeat = time.truncatingRemainder(dividingBy: beat)
      if intoBeat < 0.001 || beat - intoBeat < 0.001 { close() }

      if !event.isRest && event.duration.value.beats <= 0.5 {
        group.append(index)
      } else {
        close()
      }
      time += event.duration.beats
    }
    close()

    return marks
  }

  private static func note(
    _ event: ScoreNote, staff: Int?, voice: Int, beam: BeamMark?,
    accidentals: inout AccidentalState
  ) -> String {
    let length = Int((event.duration.beats * Double(divisions)).rounded())
    let type = typeName(event.duration.value)
    let dot = event.duration.isDotted ? "<dot/>" : ""
    let voiceTag = "<voice>\(voice)</voice>"
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""

    // The tuplet's ratio rides every note of it (rule 134).
    let timeMod = event.duration.tuplet.map {
      "<time-modification><actual-notes>\($0.actual)</actual-notes>"
        + "<normal-notes>\($0.normal)</normal-notes></time-modification>"
    }
    let timeModTag = timeMod ?? ""

    guard !event.isRest else {
      return directions(before: event, staff: staff)
        + "<note><rest/><duration>\(length)</duration>\(voiceTag)"
        + "<type>\(type)</type>\(dot)\(timeModTag)\(staffTag)</note>"
    }

    // The beam mark rides the note (rule 135) — but only on a figure short
    // enough to carry a beam: merging voices into columns can hang the mark
    // on a longer figure, and writing it would be nonsense.
    let beamTag: String
    if let beam, event.duration.value.beats <= 0.5 {
      let word: String
      switch beam {
      case .begin: word = "begin"
      case .middle: word = "continue"
      case .end: word = "end"
      }
      beamTag = "<beam number=\"1\">\(word)</beam>"
    } else {
      beamTag = ""
    }

    // A chord is written as one note followed by others marked `<chord/>`,
    // which is how MusicXML says "these share a moment".
    let graces = graceNotes(of: event, staff: staff, voice: voice, accidentals: &accidentals)
    var body = directions(before: event, staff: staff) + graces

    for (index, pitch) in event.pitches.enumerated() {
      let chord = index == 0 ? "" : "<chord/>"
      let spelled = self.spelled(pitch)
      let accidental =
        accidentals.accidental(
          letter: spelled.letter, octave: spelled.octave, alter: spelled.alter
        )
        .map { "<accidental>\($0)</accidental>" } ?? ""

      body +=
        "<note>\(chord)\(pitchXML(spelled))<duration>\(length)</duration>\(voiceTag)"
        + "<type>\(type)</type>\(dot)\(accidental)\(timeModTag)\(staffTag)"
        + "\(index == 0 ? beamTag : "")"
        + "\(notations(of: event, pitchIndex: index))</note>"
    }

    return body
  }

  /// What is written before the note: pedal, octave line, dynamic, words.
  private static func directions(before event: ScoreNote, staff: Int?) -> String {
    var parts: [String] = []
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""

    if let words = event.words {
      // Tempo and expression words sit above the staff, as printed (rule 136).
      parts.append(
        "<direction placement=\"above\"><direction-type><words>\(words)</words>"
          + "</direction-type></direction>")
    }
    if let dynamic = event.dynamic {
      parts.append(
        "<direction placement=\"below\"><direction-type><dynamics><\(dynamic)/></dynamics>"
          + "</direction-type>\(staffTag)</direction>")
    }
    if let ottava = event.ottava {
      let attributes: String
      switch ottava {
      case .startAbove: attributes = "type=\"down\" size=\"8\""
      case .startBelow: attributes = "type=\"up\" size=\"8\""
      case .stop: attributes = "type=\"stop\" size=\"8\""
      }
      parts.append(
        "<direction><direction-type><octave-shift \(attributes)/></direction-type>"
          + "\(staffTag)</direction>")
    }
    if let pedal = event.pedal {
      // The style the edition chose: a line with corner hooks, or Ped. with
      // the release star. The engraver pairs a line's start and stop by their
      // staff, so the staff tag below is what keeps the lane alive.
      let line = event.pedalLine ? "yes" : "no"

      func mark(_ kind: String) -> String {
        "<direction placement=\"below\"><direction-type>"
          + "<pedal type=\"\(kind)\" line=\"\(line)\"/>"
          + "</direction-type>\(staffTag)</direction>"
      }

      // A change goes out as the release-press pair, which is how engravers
      // and the files themselves write it — the engraver refused a bare
      // change on a line pedal and dropped the whole lane.
      switch pedal {
      case .down: parts.append(mark("start"))
      case .up: parts.append(mark("stop"))
      case .change: parts.append(mark("stop") + mark("start"))
      }
    }

    return parts.joined()
  }

  /// The ornament notes drawn small before the note (rule 127).
  ///
  /// Written as `<grace/>` sixteenths — the figure ornament pairs are engraved
  /// in — beamed as one group, fingered as the edition fingered them, and
  /// slurred into the note they decorate. The slur takes number 2 so it never
  /// collides with the phrase slur riding number 1.
  private static func graceNotes(
    of event: ScoreNote, staff: Int?, voice: Int, accidentals: inout AccidentalState
  ) -> String {
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""
    let count = event.graces.count
    var body = ""

    for (index, grace) in event.graces.enumerated() {
      var beams = ""
      if count > 1 {
        let position = index == 0 ? "begin" : (index == count - 1 ? "end" : "continue")
        beams = "<beam number=\"1\">\(position)</beam><beam number=\"2\">\(position)</beam>"
      }

      var inner = index == 0 ? "<slur type=\"start\" number=\"2\"/>" : ""
      if grace.finger > 0 {
        inner += "<technical><fingering>\(grace.finger)</fingering></technical>"
      }
      let notations = inner.isEmpty ? "" : "<notations>\(inner)</notations>"

      // A grace reads like any note: it prints the accidental it needs, and
      // the note it decorates then need not repeat it.
      let spelled = self.spelled(grace.pitch)
      let accidental =
        accidentals.accidental(
          letter: spelled.letter, octave: spelled.octave, alter: spelled.alter
        )
        .map { "<accidental>\($0)</accidental>" } ?? ""

      body +=
        "<note><grace/>\(pitchXML(spelled))<voice>\(voice)</voice>"
        + "<type>16th</type>\(accidental)\(staffTag)\(beams)\(notations)</note>"
    }

    return body
  }

  /// What is written on the note itself: fingering, slur, articulations.
  ///
  /// Slur and articulations ride the first note of a chord; fingering rides
  /// each note that has one.
  private static func notations(of event: ScoreNote, pitchIndex index: Int) -> String {
    var inner = ""

    if event.fingers.indices.contains(index) && event.fingers[index] > 0 {
      inner += "<technical><fingering>\(event.fingers[index])</fingering></technical>"
    }

    if index == 0 {
      // Start and stop on the same note is an artifact of merging voices into
      // columns — a slur to nowhere. The engraver warns and draws nothing, so
      // writing it out only buys noise.
      let slurBoth = event.slurStart && event.slurStop
      if event.slurStart && !slurBoth { inner += "<slur type=\"start\" number=\"1\"/>" }
      if event.slurStop && !slurBoth { inner += "<slur type=\"stop\" number=\"1\"/>" }

      // The ornament's little slur closes on the note it decorates.
      if !event.graces.isEmpty { inner += "<slur type=\"stop\" number=\"2\"/>" }

      // The tuplet's bracket opens and closes with its notes (rule 134).
      if event.tupletStart { inner += "<tuplet type=\"start\" number=\"1\"/>" }
      if event.tupletStop { inner += "<tuplet type=\"stop\" number=\"1\"/>" }

      // The trill is an ornament and lives in its own container; mixing it
      // into <articulations> makes engravers drop it.
      let marks = event.articulations
        .compactMap { articulation -> String? in
          switch articulation {
          case .staccato: return "<staccato/>"
          case .accent: return "<accent/>"
          case .tenuto: return "<tenuto/>"
          case .trill: return nil
          }
        }
        .sorted()
        .joined()
      if !marks.isEmpty { inner += "<articulations>\(marks)</articulations>" }
      if event.articulations.contains(.trill) { inner += "<ornaments><trill-mark/></ornaments>" }
    }

    return inner.isEmpty ? "" : "<notations>\(inner)</notations>"
  }

  /// How a key is written: letter, alteration, octave.
  ///
  /// The model carries sounding keys, not spellings, so black keys are spelt
  /// as sharps — the reading every key signature this app teaches implies.
  private static func spelled(_ pitch: Pitch) -> (letter: String, alter: Int, octave: Int) {
    let letters = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    let sharps = [false, true, false, true, false, false, true, false, true, false, true, false]

    let number = Int(pitch.midiNoteNumber)
    let index = number % 12

    return (letters[index], sharps[index] ? 1 : 0, number / 12 - 1)
  }

  private static func pitchXML(_ spelled: (letter: String, alter: Int, octave: Int)) -> String {
    let alter = spelled.alter != 0 ? "<alter>\(spelled.alter)</alter>" : ""
    return "<pitch><step>\(spelled.letter)</step>\(alter)<octave>\(spelled.octave)</octave></pitch>"
  }

  private static func typeName(_ value: NoteValue) -> String {
    switch value {
    case .whole: return "whole"
    case .half: return "half"
    case .quarter: return "quarter"
    case .eighth: return "eighth"
    case .sixteenth: return "16th"
    }
  }

  private static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}

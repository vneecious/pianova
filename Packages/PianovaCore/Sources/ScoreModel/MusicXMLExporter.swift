import Foundation

/// Writes a score out as MusicXML.
///
/// Needed because the pieces of the course are written in Swift, and an
/// engraver reads files. It is also the same format the importer reads, so a
/// piece can make the round trip and be compared with itself.
public enum MusicXMLExporter {
  /// How many divisions one crotchet is split into.
  ///
  /// Four lets a semiquaver be a whole number, which is the shortest figure the
  /// model has. Writing fractions instead would force rounding on the way out.
  public static let divisions = 4

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

    body += bar.notes.map { note($0, staff: lower == nil ? nil : 1, voice: 1) }.joined()

    if let lower {
      // Rewind to the bar's start and write the second staff over the same
      // time — which is how one instrument's two staves share a measure.
      let barLength = Int((bar.beats * Double(divisions)).rounded())
      body += "<backup><duration>\(barLength)</duration></backup>"
      body += lower.notes.map { note($0, staff: 2, voice: 2) }.joined()
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

  private static func note(_ event: ScoreNote, staff: Int?, voice: Int) -> String {
    let length = Int((event.duration.beats * Double(divisions)).rounded())
    let type = typeName(event.duration.value)
    let dot = event.duration.isDotted ? "<dot/>" : ""
    let voiceTag = "<voice>\(voice)</voice>"
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""

    guard !event.isRest else {
      return directions(before: event, staff: staff)
        + "<note><rest/><duration>\(length)</duration>\(voiceTag)"
        + "<type>\(type)</type>\(dot)\(staffTag)</note>"
    }

    // A chord is written as one note followed by others marked `<chord/>`,
    // which is how MusicXML says "these share a moment".
    return directions(before: event, staff: staff)
      + graceNotes(of: event, staff: staff, voice: voice)
      + event.pitches.enumerated()
      .map { index, pitch in
        let chord = index == 0 ? "" : "<chord/>"
        return "<note>\(chord)\(self.pitch(pitch))<duration>\(length)</duration>\(voiceTag)"
          + "<type>\(type)</type>\(dot)\(staffTag)\(notations(of: event, pitchIndex: index))</note>"
      }
      .joined()
  }

  /// What is written before the note: pedal, octave line, dynamic, words.
  private static func directions(before event: ScoreNote, staff: Int?) -> String {
    var parts: [String] = []
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""

    if let words = event.words {
      parts.append(
        "<direction><direction-type><words>\(words)</words></direction-type></direction>")
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
  private static func graceNotes(of event: ScoreNote, staff: Int?, voice: Int) -> String {
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""
    let count = event.graces.count

    return event.graces.enumerated()
      .map { index, grace in
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

        return "<note><grace/>\(pitch(grace.pitch))<voice>\(voice)</voice>"
          + "<type>16th</type>\(staffTag)\(beams)\(notations)</note>"
      }
      .joined()
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

  private static func pitch(_ pitch: Pitch) -> String {
    let letters = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    let sharps = [false, true, false, true, false, false, true, false, true, false, true, false]

    let number = Int(pitch.midiNoteNumber)
    let index = number % 12
    let octave = number / 12 - 1

    let alter = sharps[index] ? "<alter>1</alter>" : ""
    return "<pitch><step>\(letters[index])</step>\(alter)<octave>\(octave)</octave></pitch>"
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

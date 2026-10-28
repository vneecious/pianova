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

    /// The signature in force, which also decides how pitches are named
    /// (rule 133).
    let key: KeySignature

    init(key: KeySignature) {
      self.key = key
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

      // The declared tempo appears on the page, as every edition prints it
      // (rule 138) — as plain words with the unicode crotchet, because the
      // engraver's own metronome glyphs live in a music font the native
      // text renderer does not carry, and a tofu box is not a tempo.
      if let tempo = score.tempo {
        let shown =
          tempo == tempo.rounded()
          ? String(Int(tempo)) : String(tempo)
        body +=
          "<direction placement=\"above\"><direction-type>"
          + "<words>♩ = \(shown)</words>"
          + "</direction-type><staff>1</staff>"
          + "<sound tempo=\"\(shown)\"/></direction>"
      }
    }

    if bar.repeatStart {
      body +=
        "<barline location=\"left\"><bar-style>heavy-light</bar-style>"
        + "<repeat direction=\"forward\"/></barline>"
    }

    // Each staff reads its own accidentals, and each bar starts clean.
    // A release the next bar opens with is written here instead, anchored to
    // this bar's last beat — under the last chord, not squeezed at the
    // barline (rule 128).
    func staffBody(
      _ notes: [Measure], part: Part?, staff: Int?, voice: Int,
      state: inout AccidentalState
    ) -> String {
      let events = notes[0].notes
      let beams = beamMarks(for: notes[0], beat: score.timeSignature.beatValue.beats)
      let release = nextBarOpensWithRelease(part, after: index)

      var text = events.enumerated()
        .map { position, event in
          let stop =
            release && events.count > 1 && position == events.count - 1
            ? pedalStop(staff: staff) : ""
          // The tie's far end: the event before this one, even across the
          // barline (rule 148).
          let previous =
            position > 0
            ? events[position - 1]
            : (index > 0 ? part?.measures[index - 1].notes.last : nil)
          return stop
            + note(
              event, staff: staff, voice: voice, beam: beams[position],
              suppressPedalStop: position == 0 && index > 0,
              previous: previous,
              accidentals: &state)
        }
        .joined()
      if release && events.count <= 1 { text += pedalStop(staff: staff) }
      return text
    }

    var upperState = AccidentalState(key: score.key)
    body += staffBody(
      [bar], part: score.rightHand, staff: lower == nil ? nil : 1, voice: 1, state: &upperState)

    if let lower {
      // Rewind to the bar's start and write the second staff over the same
      // time — which is how one instrument's two staves share a measure.
      let barLength = Int((bar.beats * Double(divisions)).rounded())
      body += "<backup><duration>\(barLength)</duration></backup>"
      var lowerState = AccidentalState(key: score.key)
      body += staffBody([lower], part: score.leftHand, staff: 2, voice: 2, state: &lowerState)
    }

    if bar.repeatEnd {
      body +=
        "<barline location=\"right\"><bar-style>light-heavy</bar-style>"
        + "<repeat direction=\"backward\"/></barline>"
    } else if bar.sectionEnd {
      // A virada de seção (regra 155): duas linhas finas, nem repetição
      // nem fim.
      body += "<barline location=\"right\"><bar-style>light-light</bar-style></barline>"
    } else if index == score.rightHand.measures.count - 1 {
      // The piece closes with the final barline (rule 148) — a score ending
      // on a plain line looks torn off.
      body += "<barline location=\"right\"><bar-style>light-heavy</bar-style></barline>"
    }

    return "<measure number=\"\(index + 1)\">\(body)</measure>"
  }

  /// Whether the next bar opens on a release that belongs at THIS bar's end.
  ///
  /// The importer anchors a bar-final release to the next bar's first note —
  /// there is nothing later to hang it on. Writing it back there would glue
  /// the star to the next Ped. (rule 128), so the exporter looks one bar
  /// ahead and puts the stop where the edition had it.
  private static func nextBarOpensWithRelease(_ part: Part?, after index: Int) -> Bool {
    guard let part, part.measures.indices.contains(index + 1),
      let pedal = part.measures[index + 1].notes.first?.pedal
    else { return false }
    return pedal == .up || pedal == .change
  }

  /// A pedal release, written at the current point of the bar.
  private static func pedalStop(staff: Int?) -> String {
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""
    return "<direction placement=\"below\"><direction-type>"
      + "<pedal type=\"stop\" line=\"no\"/></direction-type>\(staffTag)</direction>"
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
    suppressPedalStop: Bool = false,
    previous: ScoreNote? = nil,
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
      return directions(before: event, staff: staff, suppressPedalStop: suppressPedalStop)
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
    var body =
      directions(before: event, staff: staff, suppressPedalStop: suppressPedalStop) + graces

    for (index, pitch) in event.pitches.enumerated() {
      let chord = index == 0 ? "" : "<chord/>"
      let spelled = self.spelled(pitch, in: accidentals.key)
      let accidental =
        accidentals.accidental(
          letter: spelled.letter, octave: spelled.octave, alter: spelled.alter
        )
        .map { "<accidental>\($0)</accidental>" } ?? ""

      // The tie is written out, both ends (rule 148): sound in <tie>,
      // drawing in <tied>.
      let tieStarts = event.isTiedToNext
      let tieStops = previous?.isTiedToNext == true && previous?.pitches.contains(pitch) == true
      let tie =
        (tieStops ? "<tie type=\"stop\"/>" : "")
        + (tieStarts ? "<tie type=\"start\"/>" : "")

      let marks = notations(
        of: event, pitchIndex: index, staff: staff,
        tieStarts: tieStarts, tieStops: tieStops)
      let head = "<note>\(chord)\(pitchXML(spelled))<duration>\(length)</duration>"
      let middle = "\(tie)\(voiceTag)<type>\(type)</type>\(dot)\(accidental)"
      let tail = "\(timeModTag)\(staffTag)\(index == 0 ? beamTag : "")\(marks)</note>"
      body += head + middle + tail
    }

    return body
  }

  /// What is written before the note: pedal, octave line, dynamic, words.
  private static func directions(
    before event: ScoreNote, staff: Int?, suppressPedalStop: Bool = false
  ) -> String {
    var parts: [String] = []
    let staffTag = staff.map { "<staff>\($0)</staff>" } ?? ""

    if let words = event.words {
      // The word sits where the edition put it (rule 136): tempo above,
      // expression like "cresc." below, with the dynamics.
      let placement = event.wordsBelow ? "below" : "above"
      parts.append(
        "<direction placement=\"\(placement)\"><direction-type><words>\(words)</words>"
          + "</direction-type></direction>")
    }
    if let dynamic = event.dynamic {
      // Piano dynamics live between the staves (rule 136): below the upper
      // staff for the melody's, above the lower one for the bass's.
      let placement = staff == 2 ? "above" : "below"
      parts.append(
        "<direction placement=\"\(placement)\"><direction-type>"
          + "<dynamics><\(dynamic)/></dynamics>"
          + "</direction-type>\(staffTag)</direction>")
    }
    if let chord = event.chord {
      // The chord label is a guide, not a headline (rule 149): smaller type,
      // between the staves where the book prints it.
      parts.append(
        "<direction placement=\"below\"><direction-type>"
          + "<words font-size=\"x-small\">\(chord)</words>"
          + "</direction-type><staff>1</staff></direction>")
    }
    if let wedge = event.wedge {
      // The hairpin lives with the dynamics, between the staves (rule 147).
      parts.append(
        "<direction placement=\"below\"><direction-type>"
          + "<wedge type=\"\(wedge.rawValue)\"/>"
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
      // Classic signs, whatever style the file used (rule 128): Ped. where
      // it goes down, the star where it lifts. A release the importer
      // anchored to this bar's FIRST note really belongs at the previous
      // bar's end — the caller suppresses it here and the previous bar
      // writes it in place, so star and Ped. never glue.
      func mark(_ kind: String) -> String {
        "<direction placement=\"below\"><direction-type>"
          + "<pedal type=\"\(kind)\" line=\"no\"/>"
          + "</direction-type>\(staffTag)</direction>"
      }

      // A change goes out as the release-press pair, which is how engravers
      // and the files themselves write it — the engraver refused a bare
      // change on a line pedal and dropped the whole lane.
      switch pedal {
      case .down:
        parts.append(mark("start"))
      case .up:
        if !suppressPedalStop { parts.append(mark("stop")) }
      case .change:
        parts.append(suppressPedalStop ? mark("start") : mark("stop") + mark("start"))
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
      let spelled = self.spelled(grace.pitch, in: accidentals.key)
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
  private static func notations(
    of event: ScoreNote, pitchIndex index: Int, staff: Int? = nil,
    tieStarts: Bool = false, tieStops: Bool = false
  ) -> String {
    var inner = ""

    if tieStops { inner += "<tied type=\"stop\"/>" }
    if tieStarts { inner += "<tied type=\"start\"/>" }

    if event.fingers.indices.contains(index) && event.fingers[index] > 0 {
      // The bass hand reads its numbers under the staff, as editions print
      // them; the melody keeps them above.
      let placement = staff == 2 ? " placement=\"below\"" : ""
      inner +=
        "<technical><fingering\(placement)>\(event.fingers[index])</fingering></technical>"
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
  /// How a pitch is written down, as the key would write it (rule 133).
  ///
  /// The model keeps height, not name: the same black key is A♯ in one piece
  /// and B♭ in another. The scale answers first — a note of the key takes the
  /// name the key gives it. A note from outside is the **cheapest alteration
  /// of a neighbouring degree**: that is why D minor's leading tone is C♯,
  /// which pulls upward, and not D♭, which would say the opposite with the
  /// same key under the finger. A tie goes to the sharp, because the raised
  /// degrees — leading tone, raised fourth — are what minor music actually
  /// uses.
  /// - Parameters:
  ///   - pitch: The key.
  ///   - key: The piece's signature.
  /// - Returns: Letter, alteration and octave, ready for `<pitch>`.
  private static func spelled(
    _ pitch: Pitch, in key: KeySignature
  )
    -> (letter: String, alter: Int, octave: Int)
  {
    let number = Int(pitch.midiNoteNumber)
    let target = number % 12

    // The seven letters as this key sounds them.
    let letters = ["C", "D", "E", "F", "G", "A", "B"]
    let naturals = [0, 2, 4, 5, 7, 9, 11]
    let altered = Set(key.alteredLetters.map { String(describing: $0).uppercased() })
    let keyAlter = key.usesSharps ? 1 : -1

    var best: (letter: String, alter: Int, cost: Int, prefersSharp: Bool)?
    for (index, letter) in letters.enumerated() {
      let diatonic = naturals[index] + (altered.contains(letter) ? keyAlter : 0)
      // Distance on the circle of twelve, the short way round.
      var step = (target - diatonic + 12) % 12
      if step > 6 { step -= 12 }
      guard abs(step) <= 1 else { continue }

      let alter = (altered.contains(letter) ? keyAlter : 0) + step
      guard abs(alter) <= 1 else { continue }

      // Cheapest first: a note of the scale as written, then a plain
      // natural, then a single accidental. Ties go to the sharp.
      let cost = abs(step) * 2 + abs(alter)
      let better =
        best.map {
          cost < $0.cost || (cost == $0.cost && step > 0 && !$0.prefersSharp)
        } ?? true
      if better { best = (letter, alter, cost, step > 0) }
    }

    guard let chosen = best else {
      // Nothing within a semitone of any degree cannot happen in twelve
      // notes, but a spelling has to come out either way.
      let fallback = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
      let sharps = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]
      return (fallback[target], sharps[target], number / 12 - 1)
    }

    // The octave follows the letter, not the pitch: B♯ belongs to the octave
    // below its sounding C, and C♭ to the one above its sounding B.
    let letterIndex = letters.firstIndex(of: chosen.letter) ?? 0
    let sounding = naturals[letterIndex] + chosen.alter
    var octave = number / 12 - 1
    if sounding < 0 { octave += 1 }
    if sounding > 11 { octave -= 1 }

    return (chosen.letter, chosen.alter, octave)
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

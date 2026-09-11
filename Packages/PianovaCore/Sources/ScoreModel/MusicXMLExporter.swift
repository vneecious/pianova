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
  /// - Parameter score: The piece.
  /// - Returns: The MusicXML for it.
  public static func musicXML(for score: Score) -> String {
    let parts = [("P1", score.rightHand)] + (score.leftHand.map { [("P2", $0)] } ?? [])

    let declarations =
      parts.map { id, _ in
        "<score-part id=\"\(id)\"><part-name>Piano</part-name></score-part>"
      }
      .joined()

    let bodies = parts.enumerated()
      .map { index, pair in
        part(id: pair.0, pair.1, score: score, isFirst: index == 0)
      }
      .joined()

    return """
      <?xml version="1.0" encoding="UTF-8"?>
      <score-partwise version="4.0">
      <work><work-title>\(escape(score.title))</work-title></work>
      <identification><creator type="composer">\(escape(score.composer))</creator></identification>
      <part-list>\(declarations)</part-list>
      \(bodies)
      </score-partwise>
      """
  }

  private static func part(id: String, _ part: Part, score: Score, isFirst: Bool) -> String {
    let bars = part.measures.enumerated()
      .map { index, bar in
        measure(index + 1, bar, score: score, clef: part.clef, isOpening: index == 0)
      }
      .joined()

    return "<part id=\"\(id)\">\(bars)</part>"
  }

  private static func measure(
    _ number: Int, _ bar: Measure, score: Score, clef: Clef, isOpening: Bool
  ) -> String {
    var body = ""

    if isOpening {
      let sign = clef == .treble ? "<sign>G</sign><line>2</line>" : "<sign>F</sign><line>4</line>"
      let lower = Int((4 / score.timeSignature.beatValue.beats).rounded())
      body += """
        <attributes><divisions>\(divisions)</divisions>
        <key><fifths>\(score.key.fifths)</fifths></key>
        <time><beats>\(score.timeSignature.beatsPerBar)</beats>\
        <beat-type>\(lower)</beat-type></time>
        <clef>\(sign)</clef></attributes>
        """
    }

    body += bar.notes.map { note(_: $0) }.joined()
    return "<measure number=\"\(number)\">\(body)</measure>"
  }

  private static func note(_ event: ScoreNote) -> String {
    let length = Int((event.duration.beats * Double(divisions)).rounded())
    let type = typeName(event.duration.value)
    let dot = event.duration.isDotted ? "<dot/>" : ""

    guard !event.isRest else {
      return "<note><rest/><duration>\(length)</duration><type>\(type)</type>\(dot)</note>"
    }

    // A chord is written as one note followed by others marked `<chord/>`,
    // which is how MusicXML says "these share a moment".
    return event.pitches.enumerated()
      .map { index, pitch in
        let chord = index == 0 ? "" : "<chord/>"
        return "<note>\(chord)\(self.pitch(pitch))<duration>\(length)</duration>"
          + "<type>\(type)</type>\(dot)</note>"
      }
      .joined()
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

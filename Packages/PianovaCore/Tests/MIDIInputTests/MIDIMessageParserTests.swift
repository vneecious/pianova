import ScoreModel
import Testing

@testable import MIDIInput

/// Note On with a positive velocity is a key going down.
@Test func noteOnBecomesPressed() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x90, 60, 64])

  #expect(events == [.pressed(Pitch(60), velocity: 64)])
}

/// Note On with velocity zero means a key coming up.
///
/// This is standard MIDI: many instruments never send a real Note Off.
@Test func noteOnWithZeroVelocityBecomesReleased() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x90, 60, 0])

  #expect(events == [.released(Pitch(60))])
}

/// A real Note Off is a key coming up.
@Test func noteOffBecomesReleased() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x80, 60, 64])

  #expect(events == [.released(Pitch(60))])
}

/// Controller 64 is the sustain pedal, with 64 as the halfway threshold.
@Test func sustainPedalReportsDownAndUp() {
  var parser = MIDIMessageParser()

  let down = parser.parse([0xB0, 64, 127])
  let up = parser.parse([0xB0, 64, 0])

  #expect(down == [.sustainPedal(isDown: true)])
  #expect(up == [.sustainPedal(isDown: false)])
}

/// Running status: a message may omit its status byte and reuse the last one.
@Test func runningStatusReusesThePreviousStatusByte() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x90, 60, 64, 62, 70])

  #expect(events == [.pressed(Pitch(60), velocity: 64), .pressed(Pitch(62), velocity: 70)])
}

/// Running status carries across packets, not just within one.
@Test func runningStatusCarriesAcrossPackets() {
  var parser = MIDIMessageParser()

  _ = parser.parse([0x90, 60, 64])
  let events = parser.parse([64, 70])

  #expect(events == [.pressed(Pitch(64), velocity: 70)])
}

/// One packet can carry several complete messages.
@Test func severalMessagesInOnePacketAreAllDecoded() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x90, 60, 64, 0x80, 60, 0, 0xB0, 64, 127])

  #expect(
    events == [
      .pressed(Pitch(60), velocity: 64),
      .released(Pitch(60)),
      .sustainPedal(isDown: true),
    ])
}

/// Controllers other than sustain produce no key events, but must still be
/// consumed so the bytes after them decode correctly.
@Test func unrelatedControlChangesAreSkippedWithoutBreakingTheStream() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0xB0, 7, 100, 0x90, 60, 64])

  #expect(events == [.pressed(Pitch(60), velocity: 64)])
}

/// Pitch bend carries two data bytes and no key event; skipping the wrong
/// number of bytes would corrupt everything after it.
@Test func pitchBendIsSkippedWithoutBreakingTheStream() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0xE0, 0x00, 0x40, 0x90, 60, 64])

  #expect(events == [.pressed(Pitch(60), velocity: 64)])
}

/// Program change carries a single data byte, unlike most channel messages.
@Test func programChangeIsSkippedWithoutBreakingTheStream() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0xC0, 0x05, 0x90, 60, 64])

  #expect(events == [.pressed(Pitch(60), velocity: 64)])
}

/// A truncated message at the end of a packet must not crash the parser.
@Test func truncatedMessageIsDiscarded() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x90, 60])

  #expect(events.isEmpty)
}

/// The channel nibble is ignored: the piano sends on channel 1, and the app
/// treats every channel the same.
@Test func eventsAreDecodedOnAnyChannel() {
  var parser = MIDIMessageParser()

  let events = parser.parse([0x95, 60, 64])

  #expect(events == [.pressed(Pitch(60), velocity: 64)])
}

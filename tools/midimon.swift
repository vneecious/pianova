// midimon — Core MIDI input monitor.
//
// Diagnostic tool: shows, in real time, everything the instrument sends.
// Use it to tell "the instrument is not sending" apart from "the app is not
// reading".
//
//   swift tools/midimon.swift          # listen for 30s
//   swift tools/midimon.swift 60       # listen for 60s
//
// Core MIDI is the same API on macOS and iPadOS, so what works here works in
// the iPad app.

import CoreMIDI
import Foundation

let defaultDuration = 30.0
let duration =
  CommandLine.arguments.count > 1
  ? Double(CommandLine.arguments[1]) ?? defaultDuration
  : defaultDuration

let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

func noteName(for number: UInt8) -> String {
  "\(noteNames[Int(number) % 12])\(Int(number) / 12 - 1)"
}

func endpointName(_ endpoint: MIDIObjectRef) -> String {
  var value: Unmanaged<CFString>?
  guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &value) == noErr,
    let name = value?.takeRetainedValue()
  else { return "?" }
  return name as String
}

// Timebase for converting mach ticks into milliseconds.
var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)

func milliseconds(_ ticks: UInt64) -> Double {
  Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
}

let startTime = mach_absolute_time()
let counterLock = NSLock()
var eventCount = 0
var runningStatus: UInt8 = 0

func emit(_ line: String, at timestamp: MIDITimeStamp) {
  let elapsed =
    timestamp == 0
    ? milliseconds(mach_absolute_time() - startTime)
    : milliseconds(timestamp &- startTime)
  print(String(format: "%8.1f ms  %@", elapsed, line))
  fflush(stdout)
}

func countEvent() {
  counterLock.lock()
  eventCount += 1
  counterLock.unlock()
}

func handle(_ bytes: [UInt8], at timestamp: MIDITimeStamp) {
  var index = 0
  while index < bytes.count {
    var status = bytes[index]
    if status & 0x80 != 0 {
      index += 1
      if status < 0xF0 {
        runningStatus = status
      }
    } else {
      guard runningStatus != 0 else {
        index += 1
        continue
      }
      // Running status: the sender omitted the status byte, reuse the last one.
      status = runningStatus
    }

    let kind = status & 0xF0
    let channel = (status & 0x0F) + 1

    switch kind {
    case 0x90, 0x80:
      guard index + 1 < bytes.count else { return }
      let note = bytes[index]
      let velocity = bytes[index + 1]
      index += 2
      countEvent()
      if kind == 0x90 && velocity > 0 {
        let bar = String(repeating: "█", count: max(1, Int(velocity) / 6))
        let name = noteName(for: note).padding(toLength: 4, withPad: " ", startingAt: 0)
        let level = String(format: "%3d", velocity)
        emit("NOTE ON   ch\(channel)  \(name) (#\(note))  vel=\(level) \(bar)", at: timestamp)
      } else {
        emit("note off  ch\(channel)  \(noteName(for: note)) (#\(note))", at: timestamp)
      }
    case 0xB0:
      guard index + 1 < bytes.count else { return }
      let controller = bytes[index]
      let value = bytes[index + 1]
      index += 2
      countEvent()
      let label =
        controller == 64
        ? "PEDAL sustain \(value >= 64 ? "PRESSIONADO" : "solto")"
        : "CC \(controller)"
      emit("CONTROL   ch\(channel)  \(label)  val=\(value)", at: timestamp)
    case 0xA0, 0xE0:
      index += 2
    case 0xC0, 0xD0:
      index += 1
    default:
      if status == 0xF0 {
        // System exclusive: skip through the end-of-exclusive byte.
        while index < bytes.count && bytes[index] != 0xF7 {
          index += 1
        }
        index += 1
      } else {
        index += 1
      }
    }
  }
}

var client = MIDIClientRef()
guard MIDIClientCreate("PianoStudyProbe" as CFString, nil, nil, &client) == noErr else {
  print("erro: MIDIClientCreate falhou")
  exit(1)
}

var inputPort = MIDIPortRef()
let portStatus = MIDIInputPortCreateWithBlock(client, "in" as CFString, &inputPort) {
  packetList, _ in
  let list = packetList.pointee
  var packet = list.packet
  for _ in 0..<list.numPackets {
    let length = Int(packet.length)
    var bytes = [UInt8]()
    bytes.reserveCapacity(length)
    withUnsafeBytes(of: packet.data) { raw in
      for offset in 0..<min(length, 256) {
        bytes.append(raw[offset])
      }
    }
    handle(bytes, at: packet.timeStamp)
    packet = MIDIPacketNext(&packet).pointee
  }
}
guard portStatus == noErr else {
  print("erro: porta de entrada falhou")
  exit(1)
}

let sourceCount = MIDIGetNumberOfSources()
guard sourceCount > 0 else {
  print("nenhuma fonte MIDI encontrada — o piano está ligado e conectado?")
  exit(1)
}

print("Escutando \(sourceCount) fonte(s) MIDI por \(Int(duration))s:")
for index in 0..<sourceCount {
  let source = MIDIGetSource(index)
  MIDIPortConnectSource(inputPort, source, nil)
  print("  • \(endpointName(source))")
}
print("--- toque algumas teclas e pise no pedal ---")
fflush(stdout)

RunLoop.current.run(until: Date().addingTimeInterval(duration))
print("--- fim: \(eventCount) mensagens capturadas ---")

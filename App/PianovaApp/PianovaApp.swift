// Pianova on iPad.
//
// The whole app lives in PianovaCore: this target only starts it. Views,
// engine and Core MIDI are shared byte for byte with the macOS build, which is
// why developing against the real instrument on a Mac was worth doing first.

import EngravingVerovio
import MIDIInput
import PianovaUI
import Sound
import SwiftUI

@main
struct PianovaApp: App {
  @StateObject private var hub = MIDIHub(source: CoreMIDIEventSource())
  @StateObject private var tones: TonePlayer
  @StateObject private var profile = ProfileController()
  @StateObject private var metronome: Metronome
  @StateObject private var preview: ScorePlayer
  private let engraver = Engraver()

  init() {
    let tones = TonePlayer()
    _tones = StateObject(wrappedValue: tones)
    _metronome = StateObject(wrappedValue: Metronome(tones: tones))
    _preview = StateObject(wrappedValue: ScorePlayer(tones: tones))
  }

  var body: some Scene {
    WindowGroup {
      RootView(hub: hub)
        .environmentObject(tones)
        .environmentObject(profile)
        .environmentObject(metronome)
        .environmentObject(preview)
        // The only place the C++ engraver is named. Everything above it sees
        // the protocol, so no other module is built for interop.
        .environment(\.scoreEngraver, engraver)
    }
  }
}

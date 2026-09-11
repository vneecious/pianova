// Pianova on iPad.
//
// The whole app lives in PianovaCore: this target only starts it. Views,
// engine and Core MIDI are shared byte for byte with the macOS build, which is
// why developing against the real instrument on a Mac was worth doing first.

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
    }
  }
}

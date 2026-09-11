// Pianova on macOS.
//
// The same views, engine and Core MIDI code the iPad app will use. Running on
// the Mac only changes where the window opens, and lets the real instrument be
// used during development without provisioning anything.

import MIDIInput
import PianovaUI
import Sound
import SwiftUI

@main
struct PianovaApp: App {
  @StateObject private var hub = MIDIHub(source: CoreMIDIEventSource())
  @StateObject private var tones: TonePlayer
  @StateObject private var metronome: Metronome
  @StateObject private var preview: ScorePlayer
  @StateObject private var profile = ProfileController()

  init() {
    let tones = TonePlayer()
    _tones = StateObject(wrappedValue: tones)
    _metronome = StateObject(wrappedValue: Metronome(tones: tones))
    _preview = StateObject(wrappedValue: ScorePlayer(tones: tones))
  }

  var body: some Scene {
    WindowGroup("Pianova") {
      RootView(hub: hub)
        .environmentObject(tones)
        .environmentObject(profile)
        .environmentObject(metronome)
        .environmentObject(preview)
    }
  }
}

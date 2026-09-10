import Foundation
import Testing

@testable import Sound

/// The iPad case: the output node reports nothing at all before the engine is
/// running, and the format has to survive it.
///
/// This is not hypothetical. Passing the reported zero straight through made
/// `AVAudioFormat` return `nil`, the synthesiser was connected to nothing, and
/// the app was silent on device while working perfectly on the Mac.
@Test func silentHardwareStillYieldsAUsableFormat() {
  let format = TonePlayer.renderFormat(hardwareSampleRate: 0, hardwareChannels: 0)

  #expect(format.sampleRate == TonePlayer.fallbackSampleRate)
  #expect(format.channels >= 1, "zero canais faz o AVAudioFormat virar nil")
}

/// A channel count is never zero, whatever the hardware claims.
@Test func thereIsAlwaysAtLeastOneChannel() {
  #expect(TonePlayer.renderFormat(hardwareSampleRate: 48_000, hardwareChannels: 0).channels == 1)
  #expect(TonePlayer.renderFormat(hardwareSampleRate: 0, hardwareChannels: 0).channels == 1)
}

/// What the hardware does report is respected.
@Test func realHardwareIsUsedAsGiven() {
  let format = TonePlayer.renderFormat(hardwareSampleRate: 48_000, hardwareChannels: 2)

  #expect(format.sampleRate == 48_000)
  #expect(format.channels == 2)
}

/// A rate the hardware cannot mean is replaced rather than passed on.
@Test func anImpossibleRateFallsBack() {
  #expect(
    TonePlayer.renderFormat(hardwareSampleRate: -1, hardwareChannels: 2).sampleRate
      == TonePlayer.fallbackSampleRate)
}

/// Rendering at the wrong rate does not silence anything, but it does transpose
/// the whole app, so the reported rate must win when there is one.
@Test func theHardwareRateIsPreferredOverTheFallback() {
  let format = TonePlayer.renderFormat(hardwareSampleRate: 96_000, hardwareChannels: 2)

  #expect(format.sampleRate == 96_000)
  #expect(format.sampleRate != TonePlayer.fallbackSampleRate)
}

// MARK: - Restarting after the audio configuration changes

/// Nothing to do while audio is already flowing.
@Test func aRunningEngineIsLeftAlone() {
  #expect(TonePlayer.startAction(engineRunning: true, graphBuilt: true) == .nothing)
  #expect(TonePlayer.startAction(engineRunning: true, graphBuilt: false) == .nothing)
}

/// The first start has to build the graph before running it.
@Test func theFirstStartBuildsTheGraph() {
  #expect(TonePlayer.startAction(engineRunning: false, graphBuilt: false) == .buildAndStart)
}

/// Plugging the piano in stops the engine but leaves the graph attached, so the
/// engine only needs starting again.
///
/// The bug this replaces cached "running" in a flag. The engine stops itself on
/// a configuration change, the flag went on saying otherwise, and every later
/// `start()` returned early — so the app went silent the moment the instrument
/// was connected, and stayed silent.
@Test func aStoppedEngineWithAnIntactGraphIsRestarted() {
  #expect(TonePlayer.startAction(engineRunning: false, graphBuilt: true) == .startOnly)
}

/// Whatever the state, starting is never a no-op unless audio is really
/// flowing.
@Test func startingIsOnlySkippedWhenAudioIsReallyFlowing() {
  for graphBuilt in [true, false] {
    #expect(
      TonePlayer.startAction(engineRunning: false, graphBuilt: graphBuilt) != .nothing,
      "engine parada nunca deveria ser ignorada")
  }
}

// MARK: - Which sound bank is used

/// The player's own choice wins over anything shipped.
@Test func aPlayerInstalledBankWinsOverTheBundledOne() {
  let mine = URL(fileURLWithPath: "/tmp/meu.sf2")
  let shipped = URL(fileURLWithPath: "/tmp/embarcado.sf2")

  #expect(
    TonePlayer.bankToLoad(installed: [mine], bundled: [shipped], systemExists: true) == mine)
}

/// With nothing installed, the bank that ships with the app is used.
///
/// This is what makes the app sound like a piano on first launch, with nothing
/// for the player to do — the samples are public domain, so they travel with it.
@Test func theBundledBankIsUsedByDefault() {
  let shipped = URL(fileURLWithPath: "/tmp/embarcado.sf2")

  #expect(
    TonePlayer.bankToLoad(installed: [], bundled: [shipped], systemExists: true) == shipped)
}

/// The system bank is the last resort: on macOS it is two megabytes of General
/// MIDI, a few kilobytes per instrument, and it sounds like it.
@Test func theSystemBankIsOnlyALastResort() {
  let chosen = TonePlayer.bankToLoad(installed: [], bundled: [], systemExists: true)

  #expect(chosen != nil)
  #expect(chosen?.pathExtension == "dls")
}

/// With no bank anywhere, the synthesiser takes over rather than silence.
@Test func noBankAnywhereFallsBackToTheSynthesiser() {
  #expect(TonePlayer.bankToLoad(installed: [], bundled: [], systemExists: false) == nil)
}

/// A fresh clone with an empty folder still builds and still runs.
@Test @MainActor func anEmptyBundledFolderIsHarmless() {
  #expect(TonePlayer.bankToLoad(installed: [], bundled: [], systemExists: false) == nil)
  #expect(TonePlayer.bundledBanks().allSatisfy { ["sf2", "dls"].contains($0.pathExtension) })
}

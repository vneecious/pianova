import Foundation
import Testing

@testable import Sound

/// A metronome whose click goes nowhere, so the tests need no audio hardware.
@MainActor
private func metronome() -> Metronome {
  Metronome { _ in }
}

// MARK: - Rule 75: it can be left running

/// Rule 75 — the switch turns it on and off.
@Test @MainActor func theSwitchTurnsItOnAndOff() {
  let click = metronome()
  #expect(click.isOn == false)

  click.toggle()
  #expect(click.isOn)

  click.toggle()
  #expect(click.isOn == false)
  #expect(click.beat == 0, "desligado não deveria marcar tempo nenhum")
}

/// Rule 75 — the dial stays inside what a metronome can mean.
@Test @MainActor func theTempoIsClamped() {
  let click = metronome()

  click.tempo = 5
  #expect(click.tempo == Metronome.range.lowerBound)

  click.tempo = 5_000
  #expect(click.tempo == Metronome.range.upperBound)
}

/// The dial covers the range a beginner actually practises in.
@Test func theRangeCoversPracticeTempi() {
  #expect(Metronome.range.contains(40), "estudo lento precisa existir")
  #expect(Metronome.range.contains(60))
  #expect(Metronome.range.contains(120))
}

/// A bar of fewer than one beat is not a bar.
@Test @MainActor func theBarIsAtLeastOneBeat() {
  let click = metronome()

  click.beatsPerBar = 0
  #expect(click.beatsPerBar == 1)

  click.beatsPerBar = -3
  #expect(click.beatsPerBar == 1)
}

// MARK: - Rule 78: an exercise takes the pulse over

/// Rule 78 — suspending silences it without forgetting it was wanted.
@Test @MainActor func suspendingSilencesButRemembers() {
  let click = metronome()
  click.toggle()

  click.suspend()
  #expect(click.isOn, "o usuário continua querendo o metrônomo")
  #expect(click.isSounding == false, "mas ele não pode soar por cima do exercício")

  click.resume()
  #expect(click.isSounding, "e volta sozinho quando o exercício acaba")
}

/// Rule 78 — resuming does not turn on a metronome nobody asked for.
@Test @MainActor func resumingDoesNotStartWhatWasOff() {
  let click = metronome()

  click.suspend()
  click.resume()

  #expect(click.isOn == false)
  #expect(click.isSounding == false)
}

/// Turning it off while suspended leaves it off.
@Test @MainActor func turningOffDuringAnExerciseSticks() {
  let click = metronome()
  click.toggle()
  click.suspend()

  click.toggle()
  click.resume()

  #expect(click.isOn == false)
  #expect(click.isSounding == false)
}

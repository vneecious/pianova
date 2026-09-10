// Pianova Ping — sends notes to the connected instrument.
//
// Verifies the one thing unit tests cannot: that `MIDIOutput` really finds the
// piano and that the piano really sounds. Run it and listen.
//
//   swift run --package-path Packages/PianovaCore PianovaPing

import Foundation
import MIDIInput
import ScoreModel

// Entrada primeiro: é o que decide se o app "reconhece" o piano.
let input = CoreMIDIEventSource()
print("Fontes visíveis: \(input.sourceNames)")
do {
  try input.start { _ in }
  print("Entrada: abriu ✓")
  input.stop()
} catch {
  print("Entrada: FALHOU — \(error)")
}

let output = MIDIOutput()

print("Destinos visíveis: \(output.destinationNames)")

guard output.start() else {
  print("Nenhum destino encontrado. O piano está conectado e ligado?")
  exit(1)
}

print("Conectado. Tocando Dó–Mi–Sol–Dó e depois o acorde.")

for pitch in [60, 64, 67, 72] {
  output.noteOn(Pitch(UInt8(pitch)), velocity: 80)
  Thread.sleep(forTimeInterval: 0.45)
  output.noteOff(Pitch(UInt8(pitch)))
}

Thread.sleep(forTimeInterval: 0.3)

for pitch in [60, 64, 67] {
  output.noteOn(Pitch(UInt8(pitch)), velocity: 70)
}
Thread.sleep(forTimeInterval: 1.6)
for pitch in [60, 64, 67] {
  output.noteOff(Pitch(UInt8(pitch)))
}

output.stop()
print("Pronto. Ouviu quatro notas e um acorde de Dó no piano?")

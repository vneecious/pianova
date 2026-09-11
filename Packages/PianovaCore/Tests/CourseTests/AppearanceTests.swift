import Testing

@testable import PianovaUI

/// O tema ciclo passa por todas as opções e volta ao começo.
@Test func theThemeCyclesThroughAll() {
  var seen: [Appearance] = []
  var current = Appearance.system

  for _ in Appearance.allCases {
    seen.append(current)
    current = current.next
  }

  #expect(Set(seen).count == Appearance.allCases.count, "deveria passar por todas")
  #expect(current == .system, "e voltar ao começo")
}

/// Só "sistema" deixa a decisão para fora.
@Test func onlySystemDefersToTheSystem() {
  #expect(Appearance.system.colorScheme == nil)
  #expect(Appearance.light.colorScheme == .light)
  #expect(Appearance.dark.colorScheme == .dark)
}

/// Cada opção se apresenta, para o botão poder dizer qual está valendo.
@Test func everyThemeNamesItself() {
  for theme in Appearance.allCases {
    #expect(!theme.title.isEmpty)
    #expect(!theme.symbol.isEmpty)
  }
}

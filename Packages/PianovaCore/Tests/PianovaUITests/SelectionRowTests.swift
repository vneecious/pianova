import CoreGraphics
import Testing

@testable import PianovaUI

// MARK: - Rule 106: a seleção é uma mancha contínua por sistema

/// Rule 106 — compassos vizinhos do mesmo sistema fundem numa caixa só;
/// sistemas diferentes ganham cada um a sua.
@Test func neighbouringBarsMergeIntoOneRowPerSystem() {
  let system1 = [
    CGRect(x: 100, y: 50, width: 200, height: 300),
    CGRect(x: 310, y: 40, width: 220, height: 310),
    CGRect(x: 540, y: 55, width: 180, height: 295),
  ]
  let system2 = [
    CGRect(x: 90, y: 600, width: 250, height: 320),
    CGRect(x: 350, y: 590, width: 240, height: 330),
  ]

  let rows = SelectionWash.rows(system1 + system2)

  #expect(rows.count == 2, "dois sistemas, duas manchas")
  let sorted = rows.sorted { $0.minY < $1.minY }
  #expect(sorted[0] == system1[0].union(system1[1]).union(system1[2]))
  #expect(sorted[1] == system2[0].union(system2[1]))
}

/// Rule 106 — um compasso sozinho é a própria caixa.
@Test func aLoneBarIsItsOwnRow() {
  let box = CGRect(x: 10, y: 20, width: 100, height: 200)
  #expect(SelectionWash.rows([box]) == [box])
}

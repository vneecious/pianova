import EngravingVerovio
import Foundation
import ScoreModel
import Testing

@testable import Engraving
@testable import PianovaUI

/// Probe: o pedal da valsa chega ao desenho?
@MainActor
@Test func probeWaltzPedalReachesThePage() async throws {
  let url = URL(fileURLWithPath: "/Users/I550329/Downloads/waltz-in-a-minorchopin.mxl")
  let score = try MusicXMLImporter.score(at: url)

  let controller = EngravedPlayController()
  controller.load(score, using: Engraver())
  for _ in 0..<400 where controller.pages.isEmpty {
    try await Task.sleep(for: .milliseconds(50))
  }

  let kinds = controller.pages.flatMap(\.shapes).compactMap(\.kind)
  let pedalish = kinds.filter { $0.lowercased().contains("pedal") }
  let histogram = Dictionary(grouping: kinds, by: { $0 }).mapValues(\.count)
    .sorted { $0.value > $1.value }.prefix(12)
  print("PROBE-PAGE pedal=\(pedalish.count) kinds=\(histogram)")
  #expect(!controller.pages.isEmpty)
}

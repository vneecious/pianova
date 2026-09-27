import ScoreModel
import Testing

@testable import Sound

// MARK: - Rule 141: cada marca escrita tem sua força

/// Rule 141 — p toca mais piano que mf, que toca mais piano que f.
@Test func writtenDynamicsOrderTheirVelocities() {
  let p = ScorePlayer.velocity(for: "p")
  let mf = ScorePlayer.velocity(for: "mf")
  let f = ScorePlayer.velocity(for: "f")

  #expect(p < mf)
  #expect(mf < f)
}

/// Rule 141 — sem marca, o toque médio de sempre.
@Test func noMarkPlaysTheUsualTouch() {
  #expect(ScorePlayer.velocity(for: nil) == 74)
}

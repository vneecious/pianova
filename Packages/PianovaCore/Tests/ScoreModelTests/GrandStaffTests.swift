import Testing

@testable import ScoreModel

/// Notes above middle C are written on the upper staff.
@Test func notesAboveMiddleCGoOnTheTrebleStaff() {
  #expect(Pitch(62).grandStaffClef == .treble)
  #expect(Pitch(77).grandStaffClef == .treble)
}

/// Notes below middle C are written on the lower staff.
@Test func notesBelowMiddleCGoOnTheBassStaff() {
  #expect(Pitch(59).grandStaffClef == .bass)
  #expect(Pitch(43).grandStaffClef == .bass)
}

/// Middle C is the hinge, and is resolved to the upper staff so the split has
/// exactly one answer.
@Test func middleCResolvesToTheTrebleStaff() {
  #expect(Pitch(60).grandStaffClef == .treble)
}

/// Middle C sits the same distance outside each staff, which is what makes a
/// grand staff line up.
@Test func middleCSitsSymmetricallyBetweenTheStaves() {
  let aboveBass = Pitch(60).staffStep(in: .bass) - 8
  let belowTreble = -Pitch(60).staffStep(in: .treble)

  #expect(aboveBass == 2)
  #expect(belowTreble == 2)
}

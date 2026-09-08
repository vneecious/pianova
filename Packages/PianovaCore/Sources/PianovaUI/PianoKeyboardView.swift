import ScoreModel
import Sound
import SwiftUI

/// A playable piano keyboard, for when the real instrument is not connected.
///
/// Two deliberate choices, both aimed at an iPad in the hands:
///
/// - The span is **fixed**, not derived from the exercise. Finding the note is
///   part of the exercise; a keyboard showing only the needed keys answers it.
/// - Keys never shrink below a comfortable touch size. When they do not fit,
///   the keyboard scrolls instead of squeezing.
public struct PianoKeyboardView: View {
  /// Which keys the keyboard covers.
  public let layout: KeyboardLayout

  /// Called with the key that was pressed.
  public let onPress: (Pitch) -> Void

  @EnvironmentObject private var tones: TonePlayer
  @State private var pressed: Pitch?

  /// Creates a keyboard.
  /// - Parameters:
  ///   - layout: Which keys the keyboard covers. Defaults to the fixed
  ///     three-octave window.
  ///   - onPress: Called with the key that was pressed.
  public init(
    layout: KeyboardLayout = .standard,
    onPress: @escaping (Pitch) -> Void
  ) {
    self.layout = layout
    self.onPress = onPress
  }

  private var keyWidth: CGFloat { KeyboardLayout.preferredWhiteKeyWidth }
  private var height: CGFloat { KeyboardLayout.preferredHeight }
  private var blackWidth: CGFloat { keyWidth * KeyboardLayout.blackKeyWidthRatio }
  private var blackHeight: CGFloat { height * KeyboardLayout.blackKeyHeightRatio }

  /// The keyboard.
  public var body: some View {
    ScrollView(.horizontal, showsIndicators: true) {
      ZStack(alignment: .topLeading) {
        whiteKeys
        blackKeys
      }
      .frame(width: layout.preferredWidth, height: height)
      .padding(.horizontal, 1)
    }
    .frame(height: height + 10)
    // Opens around the middle of the span rather than at the far left, so the
    // hand starts near middle C without the keyboard pointing at an answer.
    .defaultScrollAnchor(.center)
  }

  private var whiteKeys: some View {
    HStack(spacing: 0) {
      ForEach(layout.whiteKeys, id: \.midiNoteNumber) { pitch in
        whiteKey(pitch)
      }
    }
  }

  private func whiteKey(_ pitch: Pitch) -> some View {
    ZStack(alignment: .bottom) {
      UnevenRoundedRectangle(
        bottomLeadingRadius: 6, bottomTrailingRadius: 6
      )
      .fill(pressed == pitch ? Color(white: 0.80) : .white)
      .overlay(
        UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
          .strokeBorder(Color(white: 0.62), lineWidth: 0.5))

      // Only the C keys are labelled: they are the landmark a hand orients by,
      // the way the groups of black keys are on a real piano.
      if pitch.letter == .c {
        Text(pitch.solfegeWithOctave)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(Color(white: 0.42))
          .padding(.bottom, 8)
      }
    }
    .frame(width: keyWidth, height: height)
    .contentShape(Rectangle())
    .onTapGesture { strike(pitch) }
  }

  private var blackKeys: some View {
    ForEach(layout.blackKeys, id: \.midiNoteNumber) { pitch in
      if let centre = layout.blackKeyCentre(for: pitch) {
        UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
          .fill(pressed == pitch ? Color(white: 0.42) : Color(white: 0.11))
          .frame(width: blackWidth, height: blackHeight)
          .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
          .offset(x: centre * keyWidth - blackWidth / 2)
          .contentShape(Rectangle())
          .onTapGesture { strike(pitch) }
      }
    }
  }

  private func strike(_ pitch: Pitch) {
    tones.play(pitch)
    onPress(pitch)
    pressed = pitch

    Task {
      try? await Task.sleep(for: .milliseconds(120))
      if pressed == pitch { pressed = nil }
    }
  }
}

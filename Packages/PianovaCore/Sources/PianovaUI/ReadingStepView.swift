import CoreText
import Course
import ScoreModel
import SwiftUI

/// The teaching pages of a lesson, one at a time.
///
/// Comes before the questions on purpose: a quiz can check what you know, but
/// it cannot teach it to you.
struct ReadingStepView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var pageIndex = 0

  private let notes: [TheoryNote]
  private let onFinished: () -> Void

  init(noteIDs: [String], onFinished: @escaping () -> Void) {
    notes = TheoryNotes.notes(noteIDs)
    self.onFinished = onFinished
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let note = notes.indices.contains(pageIndex) ? notes[pageIndex] : nil {
        page(note)
      }

      Spacer(minLength: 0)

      HStack {
        if notes.count > 1 {
          Text("\(pageIndex + 1) de \(notes.count)")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }

        Spacer()

        Button(isLastPage ? "Entendi" : "Continuar") { advance() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .onAppear {
      if notes.isEmpty { onFinished() }
    }
  }

  private var isLastPage: Bool { pageIndex >= notes.count - 1 }

  private func advance() {
    if isLastPage {
      onFinished()
    } else {
      pageIndex += 1
    }
  }

  @ViewBuilder
  private func page(_ note: TheoryNote) -> some View {
    Text(note.title)
      .font(.system(size: 26, weight: .semibold, design: .serif))

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        ForEach(Array(note.body.enumerated()), id: \.offset) { _, paragraph in
          Text(paragraph)
            .font(.system(size: 15))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 640, alignment: .leading)
        }

        if !note.glyphs.isEmpty {
          glyphRow(note.glyphs)
        }

        ForEach(Array(note.illustrations.enumerated()), id: \.offset) { _, illustration in
          IllustrationView(illustration: illustration)
            .padding(.top, 6)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func glyphRow(_ glyphs: [GlyphLabel]) -> some View {
    HStack(alignment: .top, spacing: 22) {
      ForEach(Array(glyphs.enumerated()), id: \.offset) { _, label in
        VStack(spacing: 6) {
          SymbolView(glyph: label.glyph)
          Text(label.caption)
            .font(.system(size: 12, weight: .medium))
          if !label.detail.isEmpty {
            Text(label.detail)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
        }
        .frame(minWidth: 92)
      }
      Spacer()
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
  }

  private func staffExample(_ example: StaffExample) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      StaffView(
        clef: example.clef,
        noteGroups: example.pitches.map { [$0] },
        states: example.pitches.map { _ in .current },
        staffSpace: 16)

      Text(example.caption)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
    .padding(.top, 6)
  }
}

/// One music symbol, drawn in Bravura.
private struct SymbolView: View {
  @Environment(\.colorScheme) private var colorScheme

  let glyph: String

  var body: some View {
    Canvas { context, size in
      let font = Bravura.font(staffSpace: 15)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: PlatformColor.staffInk(colorScheme),
      ]
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: glyph, attributes: attributes))
      let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

      context.withCGContext { cgContext in
        cgContext.saveGState()
        cgContext.textMatrix = .identity
        cgContext.translateBy(x: 0, y: size.height)
        cgContext.scaleBy(x: 1, y: -1)
        cgContext.textPosition = CGPoint(x: max((size.width - width) / 2, 0), y: 20)
        CTLineDraw(line, cgContext)
        cgContext.restoreGState()
      }
    }
    .frame(width: 70, height: 76)
  }
}

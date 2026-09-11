import Engraving
import ScoreModel
import SwiftUI

/// A piece drawn by a real engraver and played on the instrument.
///
/// Same rules as everywhere else — the cursor marks what to play, right
/// advances, wrong steps back. What changed is only who drew the page.
struct EngravedPieceView: View {
  @Environment(\.scoreEngraver) private var engraver
  @StateObject private var controller = EngravedPlayController()
  @ObservedObject var hub: MIDIHub

  let score: Score
  let onFinished: () -> Void

  var body: some View {
    Group {
      if let failure = controller.failure {
        Text(failure)
          .font(.system(size: 13))
          .foregroundStyle(ItemState.failed.color)
          .frame(maxWidth: .infinity, minHeight: 200)
      } else if controller.pages.isEmpty {
        Text("Gravando…")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 200)
      } else {
        pages
      }

      if !hub.isConnected {
        PianoKeyboardView { controller.play($0) }
      }
    }
    .onAppear {
      controller.onFinished = onFinished
      if let engraver { controller.load(score, using: engraver) }
      hub.setListener(owner: controller) { [controller] event in
        guard case .pressed(let pitch, _) = event else { return }
        controller.play(pitch)
      }
    }
    .onDisappear { hub.clearListener(owner: controller) }
  }

  /// How tall one scroll anchor band is, in page units.
  ///
  /// The page is banded so the cursor can be followed *within* a page. Scrolling
  /// to the page itself centres the whole thing, which on the very first note
  /// means jumping to the middle of the piece.
  private static let bandHeight: CGFloat = 400

  /// Every page, stacked, with the cursor kept in view.
  private var pages: some View {
    ScrollViewReader { scroller in
      ScrollView(.vertical) {
        LazyVStack(spacing: 20) {
          ForEach(Array(controller.pages.enumerated()), id: \.offset) { index, page in
            EngravedScoreView(page: page, highlights: controller.highlights)
              .overlay(alignment: .top) { anchors(for: page, page: index) }
              .id(index)
          }
        }
        .padding(.horizontal, 8)
      }
      .onChange(of: controller.focus) { _, id in
        guard let id, let target = anchor(of: id) else { return }
        withAnimation(.easeOut(duration: 0.3)) { scroller.scrollTo(target, anchor: .center) }
      }
    }
  }

  /// Invisible markers down a page, so a note can be scrolled to precisely.
  private func anchors(for engraved: EngravedPage, page index: Int) -> some View {
    let bands = max(Int(engraved.size.height / Self.bandHeight), 1)

    return GeometryReader { proxy in
      VStack(spacing: 0) {
        ForEach(0..<bands, id: \.self) { band in
          Color.clear
            .frame(height: proxy.size.height / CGFloat(bands))
            .id("p\(index)-b\(band)")
        }
      }
    }
    .allowsHitTesting(false)
  }

  /// Which marker sits nearest a note.
  private func anchor(of id: String) -> String? {
    for (index, engraved) in controller.pages.enumerated() {
      guard let frame = engraved.frame(of: id) else { continue }

      let bands = max(Int(engraved.size.height / Self.bandHeight), 1)
      let band = Int(frame.midY / engraved.size.height * CGFloat(bands))
      return "p\(index)-b\(min(max(band, 0), bands - 1))"
    }
    return nil
  }
}

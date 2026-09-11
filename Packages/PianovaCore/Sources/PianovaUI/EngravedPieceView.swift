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

  /// Every page, stacked, with the cursor kept in view.
  private var pages: some View {
    ScrollViewReader { scroller in
      ScrollView(.vertical) {
        LazyVStack(spacing: 20) {
          ForEach(Array(controller.pages.enumerated()), id: \.offset) { index, page in
            EngravedScoreView(page: page, highlights: controller.highlights)
              .id(index)
          }
        }
        .padding(.horizontal, 8)
      }
      .onChange(of: controller.focus) { _, id in
        guard let id,
          let index = controller.pages.firstIndex(where: { $0.frame(of: id) != nil })
        else { return }
        withAnimation(.easeOut(duration: 0.3)) { scroller.scrollTo(index, anchor: .center) }
      }
    }
  }
}

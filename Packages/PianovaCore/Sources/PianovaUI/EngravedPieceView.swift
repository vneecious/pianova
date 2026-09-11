import Engraving
import ScoreModel
import Sound
import SwiftUI

/// A piece drawn by a real engraver and played on the instrument.
///
/// Same rules as everywhere else — the cursor marks what to play, right
/// advances, wrong steps back. What changed is only who drew the page.
struct EngravedPieceView: View {
  @Environment(\.scoreEngraver) private var engraver
  @EnvironmentObject private var preview: ScorePlayer
  @StateObject private var controller = EngravedPlayController()
  @ObservedObject var hub: MIDIHub

  let score: Score
  let onFinished: () -> Void

  /// Called when a note is tapped, with the column it sits on.
  var onPickStart: ((Int) -> Void)?

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
    // While the piece plays itself the page follows the sound, not the cursor:
    // nobody is being judged, so there is nothing to point at.
    .onChange(of: preview.column) { _, column in
      guard preview.isPlaying else { return }
      controller.follow(column: column)
    }
    .onChange(of: preview.isPlaying) { _, isPlaying in
      if !isPlaying { controller.restoreCursor() }
    }
  }

  /// The system the page is currently showing.
  ///
  /// Held so the page only moves when the cursor leaves it. Scrolling on every
  /// note makes the page rise and fall with each change of hand.
  @State private var shownSystem: String?

  /// Every page, stacked, with the cursor kept in view.
  private var pages: some View {
    ScrollViewReader { scroller in
      ScrollView(.vertical) {
        LazyVStack(spacing: 20) {
          ForEach(Array(controller.pages.enumerated()), id: \.offset) { index, page in
            EngravedScoreView(
              page: page,
              highlights: controller.highlights,
              onTap: { id in
                if let column = controller.column(of: id) { onPickStart?(column) }
              }
            )
            .overlay(alignment: .top) { systemAnchors(for: page) }
            .id(index)
          }
        }
        .padding(.horizontal, 8)
      }
      .onChange(of: controller.focus) { _, id in
        guard let id, let system = system(containing: id) else { return }

        // Only when the cursor leaves the system on screen. Inside it, the
        // reader's eye does the moving and the page stays put.
        guard system != shownSystem else { return }
        shownSystem = system

        withAnimation(.easeInOut(duration: 0.45)) {
          scroller.scrollTo(system, anchor: .top)
        }
      }
    }
  }

  /// An invisible marker at the top of each system, to scroll to.
  private func systemAnchors(for engraved: EngravedPage) -> some View {
    GeometryReader { proxy in
      let scale = proxy.size.height / max(engraved.size.height, 1)

      ForEach(engraved.systems, id: \.id) { system in
        Color.clear
          .frame(height: 1)
          .id(system.id)
          // A little above the system, so the line being read is not pinned
          // to the very edge of the screen.
          .offset(y: max(system.frame.minY * scale - 24, 0))
      }
    }
    .allowsHitTesting(false)
  }

  /// Which system a note was drawn in, across every page.
  private func system(containing id: String) -> String? {
    controller.pages.compactMap { $0.system(containing: id) }.first
  }
}

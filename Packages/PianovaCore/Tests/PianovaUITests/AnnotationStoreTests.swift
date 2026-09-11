import Foundation
import Testing

@testable import PianovaUI

private func freshStore() -> AnnotationStore {
  AnnotationStore(
    folder: FileManager.default.temporaryDirectory
      .appendingPathComponent("annotations-\(UUID().uuidString)", isDirectory: true))
}

// MARK: - Rule 125: anotações persistem por peça e por zoom

/// Rule 125 — o que se desenha numa página volta ao reabrir.
@Test func aDrawingSurvivesTheRoundTrip() {
  let store = freshStore()
  let strokes = Data("riscos".utf8)

  store.save(strokes, title: "Bach", units: 2100, page: 0)

  #expect(store.drawing(title: "Bach", units: 2100, page: 0) == strokes)
}

/// Rule 125 — outra página, outro zoom: cada um é sua própria tela.
@Test func pagesAndZoomsKeepSeparateCanvases() {
  let store = freshStore()
  store.save(Data("a".utf8), title: "Bach", units: 2100, page: 0)

  #expect(store.drawing(title: "Bach", units: 2100, page: 1) == nil)
  #expect(store.drawing(title: "Bach", units: 1500, page: 0) == nil)
}

/// Um desenho esvaziado some do disco em vez de virar arquivo vazio.
@Test func anEmptiedDrawingIsForgotten() {
  let store = freshStore()
  store.save(Data("a".utf8), title: "Bach", units: 2100, page: 0)
  store.save(Data(), title: "Bach", units: 2100, page: 0)

  #expect(store.drawing(title: "Bach", units: 2100, page: 0) == nil)
}

/// Limpar a peça leva todos os zooms e páginas dela — e só dela.
@Test func clearingAPieceSparesTheOthers() {
  let store = freshStore()
  store.save(Data("a".utf8), title: "Bach", units: 2100, page: 0)
  store.save(Data("b".utf8), title: "Bach", units: 1500, page: 2)
  store.save(Data("c".utf8), title: "Grieg", units: 2100, page: 0)

  store.clear(title: "Bach")

  #expect(store.drawing(title: "Bach", units: 2100, page: 0) == nil)
  #expect(store.drawing(title: "Bach", units: 1500, page: 2) == nil)
  #expect(store.drawing(title: "Grieg", units: 2100, page: 0) == Data("c".utf8))
}

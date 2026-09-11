import CoreGraphics
import Foundation
import Testing

@testable import Engraving

/// A page as an engraver really emits it: glyphs defined once and placed by
/// reference, straight segments for stems, and an id on every note.
private let sample = """
  <svg width="2100px" height="2970px">
    <svg class="definition-scale" viewBox="0 0 21000 29700">
      <defs>
        <g id="E0A4-x">
          <path transform="scale(1,-1)" d="M0 0 L100 0 L100 60 L0 60 Z"/>
        </g>
      </defs>
      <g id="measure-1" class="measure">
        <g id="note-1" class="note">
          <g class="notehead">
            <use xlink:href="#E0A4-x" transform="translate(1000, 500) scale(0.5, 0.5)"/>
          </g>
          <g id="stem-1" class="stem">
            <path d="M1050 500 L1050 200" stroke-width="18"/>
          </g>
        </g>
      </g>
    </svg>
  </svg>
  """

private func parsedPage() -> EngravedPage? { EngravedPageParser.page(from: sample) }

/// The page reports the coordinate system the music was drawn in.
@Test func theViewBoxIsRead() throws {
  let page = try #require(parsedPage())

  #expect(page.size == CGSize(width: 21000, height: 29700))
}

/// A `<use>` becomes a real outline, placed where the transform put it.
///
/// Without resolving the reference the whole page would be stems and bar lines
/// with no note heads at all.
@Test func aReferencedGlyphIsPlaced() throws {
  let page = try #require(parsedPage())
  let heads = page.shapes.filter { $0.kind == "notehead" }

  #expect(heads.count == 1)
  let box = try #require(heads.first).path.boundingBoxOfPath
  #expect(box.minX == 1000, "translate deveria posicionar o glifo")
  #expect(box.width == 50, "scale(0.5) deveria reduzir pela metade")
}

/// A stem is stroked, a note head is filled.
@Test func strokesAndFillsAreToldApart() throws {
  let page = try #require(parsedPage())

  let stem = try #require(page.shapes.first { $0.kind == "stem" })
  #expect(stem.isFilled == false)
  #expect(stem.strokeWidth > 0)

  let head = try #require(page.shapes.first { $0.kind == "notehead" })
  #expect(head.isFilled)
}

/// Every shape carries the identifier of the element it belongs to.
///
/// This is the handle the cursor holds: the timemap says which ids sound when,
/// and highlighting is finding those ids on the page.
@Test func shapesCarryTheirElementIdentifier() throws {
  let page = try #require(parsedPage())

  #expect(page.shapes.contains { $0.elementID == "note-1" })
  #expect(page.shapes.contains { $0.elementID == "stem-1" })
}

/// An element can be located, which is what scrolling to it needs.
@Test func anElementCanBeFound() throws {
  let page = try #require(parsedPage())
  let frame = try #require(page.frame(of: "note-1"))

  #expect(frame.width > 0)
  #expect(frame.minX >= 1000 - 1)
  #expect(page.frame(of: "não-existe") == nil)
}

/// Rubbish is refused rather than drawn as an empty page.
@Test func rubbishIsRefused() {
  #expect(EngravedPageParser.page(from: "isto não é svg") == nil)
}

/// Transforms compose in the order SVG says they do.
@Test func transformsCompose() {
  let moved = SVGTransform.parse("translate(10, 20)")
  #expect(moved.tx == 10 && moved.ty == 20)

  let scaled = SVGTransform.parse("scale(2)")
  #expect(scaled.a == 2 && scaled.d == 2, "um argumento escala os dois eixos")

  // Translate then scale: the translation is scaled too, as SVG applies them
  // right to left.
  let both = SVGTransform.parse("translate(10, 0) scale(2, 2)")
  #expect(both.tx == 10)
  #expect(both.a == 2)
}

/// A missing or unreadable transform is the identity, not a crash.
@Test func anAbsentTransformIsTheIdentity() {
  #expect(SVGTransform.parse(nil) == .identity)
  #expect(SVGTransform.parse("rotate(45)") == .identity, "o que eu não leio, eu ignoro")
}

// MARK: - A nota inteira, não só a cabeça

/// Tudo dentro de uma nota pertence a ela, mesmo tendo id próprio.
///
/// No SVG do gravador a haste carrega um identificador seu. Casar só por
/// elemento pinta a cabeça e deixa haste e bandeirola na cor antiga — que na
/// tela vira "uma bolinha colorida".
@Test func everythingInsideANoteBelongsToIt() throws {
  let page = try #require(parsedPage())

  let head = try #require(page.shapes.first { $0.kind == "notehead" })
  let stem = try #require(page.shapes.first { $0.kind == "stem" })

  #expect(head.noteID == "note-1")
  #expect(stem.noteID == "note-1", "a haste é da nota, apesar do id próprio")
  #expect(stem.elementID == "stem-1", "e continua tendo o seu")
}

/// O contorno de uma nota é a união de tudo que é dela.
@Test func aNoteFrameCoversAllOfIt() throws {
  let page = try #require(parsedPage())

  let whole = try #require(page.frame(of: "note-1"))
  let head = try #require(page.shapes.first { $0.kind == "notehead" }).path.boundingBoxOfPath
  let stem = try #require(page.shapes.first { $0.kind == "stem" }).path.boundingBoxOfPath

  // Comparado com a união, e não com `contains`, que exclui a borda — a haste
  // cai exatamente nela e o teste falharia por artefato, não por defeito.
  #expect(whole == head.union(stem))
  #expect(whole.width >= stem.width)
  #expect(whole.width >= head.width)
}

/// O que está fora de uma nota não é atribuído a nenhuma.
@Test func whatIsOutsideANoteHasNoNote() {
  let bare = """
    <svg><svg class="definition-scale" viewBox="0 0 100 100">
      <g id="bar-1" class="barLine"><path d="M10 0 L10 50" stroke-width="4"/></g>
    </svg></svg>
    """

  let page = EngravedPageParser.page(from: bare)
  #expect(page?.shapes.first?.noteID == nil)
  #expect(page?.shapes.first?.elementID == "bar-1")
}

// MARK: - Rolagem por sistema

/// Uma página com dois sistemas, cada um com uma nota em cada clave.
private let twoSystems = """
  <svg><svg class="definition-scale" viewBox="0 0 1000 1000">
    <g id="sys-1" class="system">
      <g id="n-alto" class="note"><path d="M100 100 L110 100"/></g>
      <g id="n-baixo" class="note"><path d="M120 260 L130 260"/></g>
    </g>
    <g id="sys-2" class="system">
      <g id="n-2" class="note"><path d="M100 600 L110 600"/></g>
    </g>
  </svg></svg>
  """

/// Notas de mãos diferentes no mesmo sistema pertencem ao mesmo sistema.
///
/// É isso que impede a página de subir e descer: a esquerda está no pé do
/// sistema e a direita no topo, e seguir a nota faria a página balançar a cada
/// troca de mão.
@Test func bothHandsShareASystem() {
  let page = EngravedPageParser.page(from: twoSystems)

  #expect(page?.system(containing: "n-alto") == "sys-1")
  #expect(page?.system(containing: "n-baixo") == "sys-1")
  #expect(page?.system(containing: "n-2") == "sys-2")
}

/// Os sistemas saem de cima para baixo, que é a ordem de leitura.
@Test func systemsComeInReadingOrder() throws {
  let page = try #require(EngravedPageParser.page(from: twoSystems))

  #expect(page.systems.map(\.id) == ["sys-1", "sys-2"])
  #expect(try #require(page.systems.first).frame.minY < #require(page.systems.last).frame.minY)
}

/// O contorno de um sistema cobre as duas claves dele.
@Test func aSystemFrameCoversBothStaves() throws {
  let page = try #require(EngravedPageParser.page(from: twoSystems))
  let first = try #require(page.systems.first).frame

  #expect(first.minY <= 100)
  #expect(first.maxY >= 260, "o pé do sistema é a mão esquerda")
}

/// Uma página sem sistemas marcados não inventa nenhum.
@Test func aPageWithoutSystemsHasNone() throws {
  let page = try #require(parsedPage())

  #expect(page.systems.isEmpty)
  #expect(page.system(containing: "note-1") == nil)
}

// MARK: - Compassos

/// Uma página com dois compassos, cada um com sua nota.
private let twoMeasures = """
  <svg><svg class="definition-scale" viewBox="0 0 1000 400">
    <g id="sys-1" class="system">
      <g id="m-1" class="measure">
        <g id="n-1" class="note"><path d="M50 100 L60 100"/></g>
      </g>
      <g id="m-2" class="measure">
        <g id="n-2" class="note"><path d="M300 100 L310 100"/></g>
      </g>
    </g>
  </svg></svg>
  """

/// Uma nota sabe em que compasso está, que é o que o clique precisa.
@Test func aNoteKnowsItsMeasure() {
  let page = EngravedPageParser.page(from: twoMeasures)

  #expect(page?.measure(containing: "n-1") == "m-1")
  #expect(page?.measure(containing: "n-2") == "m-2")
}

/// O contorno de um compasso cobre o que está nele e não o vizinho.
@Test func aMeasureFrameStopsAtItsOwnContents() throws {
  let page = try #require(EngravedPageParser.page(from: twoMeasures))
  let first = try #require(page.measureFrame("m-1"))

  #expect(first.minX <= 50)
  #expect(first.maxX < 300, "não deveria alcançar o compasso seguinte")
}

/// Compasso e sistema são coisas diferentes, e ambos são conhecidos.
@Test func measuresAndSystemsAreBothTracked() {
  let page = EngravedPageParser.page(from: twoMeasures)

  #expect(page?.system(containing: "n-2") == "sys-1")
  #expect(page?.measure(containing: "n-2") == "m-2")
}

/// A altura de sistema é a do maior deles, que é o que tem de caber.
@Test func theSystemHeightIsTheTallest() throws {
  let uneven = """
    <svg><svg class="definition-scale" viewBox="0 0 1000 1000">
      <g id="s1" class="system"><path d="M0 0 L10 0"/><path d="M0 40 L10 40"/></g>
      <g id="s2" class="system"><path d="M0 200 L10 200"/><path d="M0 400 L10 400"/></g>
    </svg></svg>
    """

  let page = try #require(EngravedPageParser.page(from: uneven))
  #expect(page.systemHeight == 200, "o sistema mais alto é o que decide")
}

/// Sem sistemas marcados, a altura é a da página — nada a encolher.
@Test func aPageWithoutSystemsUsesItsOwnHeight() throws {
  let page = try #require(parsedPage())
  #expect(page.systemHeight == page.size.height)
}

// MARK: - Rule 109: qual pauta é qual

/// As pautas de um compasso são contadas na ordem, primeira e segunda.
///
/// O Verovio não escreve o número da pauta no SVG — nenhum atributo `n` — e
/// adivinhar com um padrão marcava a página inteira como pauta 1. Foi isso que
/// fez "mão esquerda" esmaecer a peça toda, a própria mão esquerda incluída.
@Test func stavesAreCountedInOrderWithinTheMeasure() {
  let grand = """
    <svg><svg class="definition-scale" viewBox="0 0 1000 400">
      <g id="m-1" class="measure">
        <g id="s-1" class="staff">
          <g id="n-1" class="note"><path d="M50 100 L60 100"/></g>
        </g>
        <g id="s-2" class="staff">
          <g id="n-2" class="note"><path d="M50 300 L60 300"/></g>
        </g>
      </g>
      <g id="m-2" class="measure">
        <g id="s-3" class="staff">
          <g id="n-3" class="note"><path d="M300 100 L310 100"/></g>
        </g>
        <g id="s-4" class="staff">
          <g id="n-4" class="note"><path d="M300 300 L310 300"/></g>
        </g>
      </g>
    </svg></svg>
    """
  let page = EngravedPageParser.page(from: grand)
  func staff(of note: String) -> Int? {
    page?.shapes.first { $0.noteID == note }?.staffNumber
  }

  #expect(staff(of: "n-1") == 1)
  #expect(staff(of: "n-2") == 2)
  #expect(staff(of: "n-3") == 1, "o compasso seguinte recomeça a contagem")
  #expect(staff(of: "n-4") == 2)
}

/// O que não está em pauta nenhuma não pertence a mão nenhuma.
@Test func inkOutsideAnyStaffHasNoStaffNumber() {
  let page = EngravedPageParser.page(from: twoMeasures)

  #expect(page?.shapes.allSatisfy { $0.staffNumber == nil } == true)
}

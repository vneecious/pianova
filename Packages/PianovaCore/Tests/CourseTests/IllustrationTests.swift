import ScoreModel
import Testing

@testable import Course

/// Every figure in the whole bank of teaching pages.
private var allIllustrations: [Illustration] {
  TheoryNotes.all.flatMap(\.illustrations)
}

/// Pages that teach something spatial, and so cannot be left as prose.
///
/// Named one by one on purpose. A rule inferred from the title would pass by
/// accident the day a page is renamed, and this is exactly the kind of gap that
/// only shows up when a beginner is staring at a wall of text.
private let mustBeIllustrated: [String: String] = [
  "n-keyboard": "onde ficam Dó e Fá entre as teclas pretas",
  "n-fingers": "a numeração espelhada das duas mãos",
  "n-values": "a divisão pela metade das figuras",
  "n-middle-c": "o Dó central entre as duas claves",
  "n-staff": "linhas e espaços",
  "i-tone-semitone": "a distância entre duas teclas",
  "s-accidentals": "o que sustenido e bemol fazem no teclado",
  "s-major": "o desenho tom-tom-semitom da escala",
]

// MARK: - Rule 28: what is seen is drawn

/// Rule 28 — a page about something spatial carries a figure.
@Test func spatialPagesAreIllustrated() {
  for (id, subject) in mustBeIllustrated {
    guard let note = TheoryNotes.note(id) else {
      Issue.record("a página \(id) não existe")
      continue
    }

    #expect(!note.illustrations.isEmpty, "\(id) explica \(subject) só com texto")
  }
}

/// Rule 28 — the keyboard is drawn somewhere, not only described.
@Test func theKeyboardIsDrawn() {
  let keyboards = allIllustrations.filter {
    guard case .keyboard = $0 else { return false }
    return true
  }

  #expect(!keyboards.isEmpty, "nenhuma página desenha o teclado")
}

/// Rule 28 — the hands are drawn where fingering is taught.
@Test func theHandsAreDrawnWhereFingeringIsTaught() {
  guard let note = TheoryNotes.note("n-fingers") else {
    Issue.record("a página n-fingers não existe")
    return
  }

  let hasHands = note.illustrations.contains {
    guard case .hands = $0 else { return false }
    return true
  }

  #expect(hasHands, "a página de dedilhado não desenha as mãos")
}

/// Rule 28 — note values are shown halving, not just listed.
@Test func noteValuesAreDrawnAsATree() {
  guard let note = TheoryNotes.note("n-values") else {
    Issue.record("a página n-values não existe")
    return
  }

  let hasTree = note.illustrations.contains {
    guard case .valueTree = $0 else { return false }
    return true
  }

  #expect(hasTree, "a página de figuras não mostra a divisão pela metade")
}

// MARK: - Rule 29: a diagram does not point outside itself

/// Rule 29 — every marked key and every bracket sits inside the drawn range.
@Test func keyboardDiagramsAreSelfContained() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .keyboard(let diagram) = illustration else { continue }

      #expect(diagram.isSelfContained, "\(note.id): o diagrama aponta para fora da extensão")
    }
  }
}

/// A bracket names a group, so it has to cover more than one key.
@Test func bracketsCoverMoreThanOneKey() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .keyboard(let diagram) = illustration else { continue }

      for bracket in diagram.brackets {
        #expect(
          bracket.range.lowerBound < bracket.range.upperBound,
          "\(note.id): o colchete \"\(bracket.label)\" cobre uma tecla só")
      }
    }
  }
}

/// A keyboard diagram wide enough to be read, and small enough to be a diagram.
///
/// Two octaves is where the groups of two and three repeat enough to be seen as
/// a pattern; much more than four and the keys get too narrow to label.
@Test func keyboardDiagramsAreAReadableWidth() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .keyboard(let diagram) = illustration else { continue }

      let span = Int(diagram.range.upperBound) - Int(diagram.range.lowerBound)
      #expect(span >= 12, "\(note.id): o diagrama tem menos de uma oitava")
      #expect(span <= 48, "\(note.id): o diagrama tem mais de quatro oitavas")
    }
  }
}

/// Every drawn key exists on the on-screen keyboard too, so the picture and the
/// instrument the player answers on agree.
@Test func drawnKeysExistOnTheScreenKeyboard() {
  let keys = KeyboardLayout.standard.range

  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .keyboard(let diagram) = illustration else { continue }

      #expect(
        keys.contains(diagram.range.lowerBound) && keys.contains(diagram.range.upperBound),
        "\(note.id): o diagrama desenha teclas que o app não tem")
    }
  }
}

// MARK: - Rule 30: every figure is captioned

/// Rule 30 — a figure with no caption sends the reader back to the text.
@Test func everyIllustrationIsCaptioned() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      #expect(!illustration.caption.isEmpty, "\(note.id) tem figura sem legenda")
    }
  }
}

/// A caption says something, rather than restating the title.
@Test func captionsDoNotRepeatTheTitle() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      #expect(
        illustration.caption.lowercased() != note.title.lowercased(),
        "\(note.id): a legenda só repete o título")
    }
  }
}

/// A hand diagram draws at least one hand.
@Test func handDiagramsDrawAHand() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .hands(let diagram) = illustration else { continue }

      #expect(!diagram.hands.isEmpty, "\(note.id): diagrama de mãos sem nenhuma mão")
    }
  }
}

/// A value tree halves: each row is worth half the one above it.
@Test func valueTreesActuallyHalve() {
  for note in TheoryNotes.all {
    for illustration in note.illustrations {
      guard case .valueTree(let tree) = illustration else { continue }

      #expect(tree.rows.count >= 2, "\(note.id): a árvore de valores tem uma linha só")

      for (above, below) in zip(tree.rows, tree.rows.dropFirst()) {
        #expect(
          above.beats == below.beats * 2,
          "\(note.id): \(above.name) não vale o dobro de \(below.name)")
      }
    }
  }
}

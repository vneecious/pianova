import ScoreModel

/// The teaching pages the course explains from.
///
/// Organised into the same four blocks as the questions. Written here, in our
/// own words, from standard theory.
public enum TheoryNotes {
  private enum Glyph {
    static let wholeNote = "\u{E1D2}"
    static let halfNote = "\u{E1D3}"
    static let quarterNote = "\u{E1D5}"
    static let eighthNote = "\u{E1D7}"
    static let wholeRest = "\u{E4E3}"
    static let halfRest = "\u{E4E4}"
    static let quarterRest = "\u{E4E5}"
    static let eighthRest = "\u{E4E6}"
    static let sharp = "\u{E262}"
    static let flat = "\u{E260}"
    static let natural = "\u{E261}"
    static let trebleClef = "\u{E050}"
    static let bassClef = "\u{E062}"
  }

  /// Every page, in block order.
  public static let all: [TheoryNote] = notation + intervals + scales + chords

  /// A page by identifier.
  /// - Parameter id: The identifier to look up.
  /// - Returns: The page, or `nil` if there is none.
  public static func note(_ id: String) -> TheoryNote? {
    all.first { $0.id == id }
  }

  /// Pages listed by identifier, skipping any that do not exist.
  /// - Parameter ids: The identifiers to look up, in order.
  /// - Returns: The pages found, in the order asked for.
  public static func notes(_ ids: [String]) -> [TheoryNote] {
    ids.compactMap(note)
  }

  // MARK: - A. Notação musical

  private static let notation: [TheoryNote] = [
    TheoryNote(
      id: "n-staff", topic: .notation,
      title: "A pauta",
      body: [
        "A música se escreve numa pauta de cinco linhas e quatro espaços, "
          + "contados sempre de baixo para cima.",
        "Cada nota ocupa uma linha ou um espaço. Subir uma posição na pauta é "
          + "subir para a nota vizinha: da linha para o espaço logo acima, e "
          + "assim por diante.",
        "Quanto mais alta a posição na pauta, mais agudo o som — e mais à "
          + "direita a tecla no piano.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [64, 65, 67, 69, 71].map { Pitch(UInt8($0)) },
        caption: "Notas vizinhas alternam entre linha e espaço")),

    TheoryNote(
      id: "n-clefs", topic: .notation,
      title: "As claves",
      body: [
        "Sozinha, a pauta não diz que notas são aquelas. Quem decide isso é a "
          + "clave, no começo da linha.",
        "A clave de sol enrola em torno da segunda linha: é ali que fica o Sol. "
          + "A clave de fá tem dois pontos que abraçam a quarta linha, onde "
          + "fica o Fá.",
        "A consequência é importante: a mesma posição na pauta significa notas "
          + "diferentes conforme a clave. Por isso as duas se aprendem juntas, "
          + "e não uma depois da outra.",
      ],
      glyphs: [
        GlyphLabel(glyph: Glyph.trebleClef, caption: "Clave de sol", detail: "Sol na 2ª linha"),
        GlyphLabel(glyph: Glyph.bassClef, caption: "Clave de fá", detail: "Fá na 4ª linha"),
      ]),

    TheoryNote(
      id: "n-middle-c", topic: .notation,
      title: "O Dó central",
      body: [
        "O Dó central é a referência de onde tudo se conta. No piano ele fica "
          + "mais ou menos no meio do teclado, logo à esquerda do grupo de duas "
          + "teclas pretas.",
        "Na escrita ele é o ponto onde as duas claves se encontram: uma linha "
          + "suplementar abaixo da clave de sol, ou uma linha suplementar acima "
          + "da clave de fá.",
        "Mesma tecla, duas escritas. Reconhecer as duas é o primeiro passo para "
          + "ler as duas mãos.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [Pitch(60)],
        caption: "Dó central, na primeira linha suplementar abaixo")),

    TheoryNote(
      id: "n-values", topic: .notation,
      title: "Figuras e valores",
      body: [
        "A posição na pauta diz qual nota tocar. A figura diz quanto tempo ela "
          + "dura.",
        "Cada figura vale metade da anterior: a semibreve vale duas mínimas, a "
          + "mínima vale duas semínimas, a semínima vale duas colcheias. É uma "
          + "escada de metades, e por isso os valores nunca são arbitrários.",
        "A semínima costuma ser a unidade de tempo — o pulso que se conta ao "
          + "tocar.",
      ],
      glyphs: [
        GlyphLabel(glyph: Glyph.wholeNote, caption: "Semibreve", detail: "4 tempos"),
        GlyphLabel(glyph: Glyph.halfNote, caption: "Mínima", detail: "2 tempos"),
        GlyphLabel(glyph: Glyph.quarterNote, caption: "Semínima", detail: "1 tempo"),
        GlyphLabel(glyph: Glyph.eighthNote, caption: "Colcheia", detail: "½ tempo"),
      ]),

    TheoryNote(
      id: "n-rests", topic: .notation,
      title: "Pausas",
      body: [
        "O silêncio também é medido. Cada figura tem uma pausa correspondente, "
          + "com exatamente a mesma duração.",
        "Uma pausa não é uma interrupção da música: é parte dela. O compasso "
          + "continua contando durante o silêncio.",
      ],
      glyphs: [
        GlyphLabel(glyph: Glyph.wholeRest, caption: "Pausa de semibreve", detail: "4 tempos"),
        GlyphLabel(glyph: Glyph.halfRest, caption: "Pausa de mínima", detail: "2 tempos"),
        GlyphLabel(glyph: Glyph.quarterRest, caption: "Pausa de semínima", detail: "1 tempo"),
        GlyphLabel(glyph: Glyph.eighthRest, caption: "Pausa de colcheia", detail: "½ tempo"),
      ]),

    TheoryNote(
      id: "n-dot-tie", topic: .notation,
      title: "Ponto e ligadura",
      body: [
        "O ponto de aumento, colocado à direita da figura, acrescenta metade do "
          + "valor dela. Uma semínima pontuada vale um tempo e meio; uma mínima "
          + "pontuada vale três.",
        "A ligadura é uma curva que une duas notas de mesma altura: elas viram "
          + "um som só, com a soma das durações. É assim que se escreve uma "
          + "duração que atravessa a linha divisória.",
      ]),

    TheoryNote(
      id: "n-bars", topic: .notation,
      title: "Compasso",
      body: [
        "As linhas divisórias cortam a pauta em compassos — trechos com a mesma "
          + "quantidade de tempo. É o que dá regularidade à música.",
        "A fórmula de compasso aparece uma vez, no começo. Em 4/4, o número de "
          + "cima diz que há quatro tempos por compasso; o de baixo diz que a "
          + "semínima é a figura que vale um tempo.",
        "Em 3/4 são três tempos por compasso, ainda com a semínima valendo um. "
          + "Muda a contagem, não a figura.",
      ]),

    TheoryNote(
      id: "n-ledger", topic: .notation,
      title: "Linhas suplementares",
      body: [
        "Cinco linhas não bastam para o alcance de um piano. Quando a nota "
          + "passa dos limites da pauta, ela ganha pequenas linhas extras, "
          + "acrescentadas uma a uma.",
        "Elas seguem a mesma lógica das linhas da pauta: continuam alternando "
          + "linha e espaço, para cima ou para baixo.",
        "O Dó central é a linha suplementar mais importante de todas — é a "
          + "primeira, dos dois lados.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [60, 62, 64].map { Pitch(UInt8($0)) },
        caption: "Dó e Ré usam linha e espaço suplementares; Mi já entra na pauta")),
  ]

  // MARK: - B. Intervalos

  private static let intervals: [TheoryNote] = [
    TheoryNote(
      id: "i-what", topic: .intervals,
      title: "O que é um intervalo",
      body: [
        "Intervalo é a distância entre duas notas.",
        "Conta-se pelos nomes das notas, incluindo as duas pontas. De Dó a Mi "
          + "contamos Dó, Ré, Mi — três nomes, logo uma terça. De Dó a Sol são "
          + "cinco nomes: uma quinta.",
        "Isso surpreende no começo: de Dó a Ré é uma segunda, e não uma "
          + "primeira, porque a nota de partida já conta.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [60, 64].map { Pitch(UInt8($0)) },
        caption: "Dó e Mi: uma terça")),

    TheoryNote(
      id: "i-melodic-harmonic", topic: .intervals,
      title: "Melódico e harmônico",
      body: [
        "Se as duas notas soam uma após a outra, o intervalo é melódico. Se "
          + "soam ao mesmo tempo, é harmônico.",
        "É a mesma distância nos dois casos — muda só como se ouve. Melodia é "
          + "feita de intervalos melódicos; acordes, de harmônicos.",
      ]),

    TheoryNote(
      id: "i-tone-semitone", topic: .intervals,
      title: "Tom e semitom",
      body: [
        "O semitom é a menor distância usada na música ocidental. No piano, é a "
          + "distância entre uma tecla e a tecla imediatamente vizinha, "
          + "contando as pretas.",
        "Dois semitons formam um tom.",
        "Entre quase todas as notas vizinhas há uma tecla preta, e portanto um "
          + "tom. As exceções são Mi–Fá e Si–Dó: ali as brancas são vizinhas "
          + "diretas, e a distância é de apenas meio tom. Essas duas exceções "
          + "explicam o formato do teclado.",
      ]),

    TheoryNote(
      id: "i-quality", topic: .intervals,
      title: "Maior, menor, justo",
      body: [
        "Só o número não basta: existem terças de tamanhos diferentes. Por isso "
          + "cada intervalo tem também uma qualidade.",
        "A terça maior tem quatro semitons (Dó–Mi); a menor tem três (Ré–Fá). "
          + "Essa diferença de um semitom é o que separa um acorde maior de um "
          + "menor.",
        "Uníssono, quarta, quinta e oitava são chamados justos, não maiores ou "
          + "menores.",
      ]),
  ]

  // MARK: - C. Escalas

  private static let scales: [TheoryNote] = [
    TheoryNote(
      id: "s-what", topic: .scales,
      title: "O que é uma escala",
      body: [
        "Escala é uma sucessão de notas em ordem de altura, subindo ou "
          + "descendo, dentro de uma oitava.",
        "Cada nota da escala é um grau, numerado do primeiro ao sétimo. O "
          + "oitavo é a repetição do primeiro, uma oitava acima.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [60, 62, 64, 65, 67, 69, 71, 72].map { Pitch(UInt8($0)) },
        caption: "A escala de Dó maior, do primeiro grau à oitava")),

    TheoryNote(
      id: "s-major", topic: .scales,
      title: "A escala maior",
      body: [
        "O que define a escala maior não são as notas em si, mas a distância "
          + "entre elas.",
        "A fórmula é sempre a mesma: tom, tom, semitom, tom, tom, tom, semitom. "
          + "Ou seja, os semitons caem entre o 3º e o 4º graus e entre o 7º e o "
          + "8º.",
        "Em Dó maior essa fórmula cai exatamente nas teclas brancas, porque os "
          + "semitons naturais Mi–Fá e Si–Dó estão justo nesses lugares. Em "
          + "qualquer outra tonalidade é preciso alterar notas para manter a "
          + "mesma fórmula.",
      ]),

    TheoryNote(
      id: "s-degrees", topic: .scales,
      title: "Os graus",
      body: [
        "Cada grau tem um nome e uma função. Os dois mais importantes são o "
          + "primeiro e o quinto.",
        "A tônica é o 1º grau: dá nome à tonalidade e é onde a música soa em "
          + "repouso. A dominante é o 5º: é o grau de maior tensão, que puxa de "
          + "volta para a tônica.",
        "O 7º grau é a sensível, a meio tom da tônica — é a nota que mais "
          + "\"pede\" para resolver.",
      ]),

    TheoryNote(
      id: "s-accidentals", topic: .scales,
      title: "Alterações",
      body: [
        "O sustenido sobe a nota meio tom. O bemol desce meio tom. O bequadro "
          + "cancela qualquer um dos dois e devolve a nota ao estado natural.",
        "No teclado, subir meio tom a partir de uma tecla branca normalmente "
          + "leva à tecla preta à direita — mas nem sempre: Mi sustenido é a "
          + "tecla do Fá, porque ali não existe preta entre as duas.",
        "A alteração vale para o compasso inteiro, e não só para a nota onde "
          + "aparece.",
      ],
      glyphs: [
        GlyphLabel(glyph: Glyph.sharp, caption: "Sustenido", detail: "sobe ½ tom"),
        GlyphLabel(glyph: Glyph.flat, caption: "Bemol", detail: "desce ½ tom"),
        GlyphLabel(glyph: Glyph.natural, caption: "Bequadro", detail: "desfaz"),
      ]),

    TheoryNote(
      id: "s-key-signature", topic: .scales,
      title: "Armadura de clave",
      body: [
        "Quando uma tonalidade precisa das mesmas alterações o tempo todo, "
          + "elas são escritas uma única vez, logo depois da clave. Isso é a "
          + "armadura.",
        "Sol maior precisa de Fá sustenido para que o semitom caia entre o 7º e "
          + "o 8º graus — por isso tem um sustenido. Fá maior precisa de Si "
          + "bemol pelo mesmo motivo, e tem um bemol.",
        "A armadura vale para todas as oitavas e para a peça inteira.",
      ]),
  ]

  // MARK: - D. Acordes

  private static let chords: [TheoryNote] = [
    TheoryNote(
      id: "c-what", topic: .chords,
      title: "O que é um acorde",
      body: [
        "Acorde é o conjunto de três ou mais sons ouvidos ao mesmo tempo.",
        "Duas notas simultâneas ainda são um intervalo. É a partir da terceira "
          + "que se fala em acorde.",
        "O acorde de três sons se chama tríade, e é a base de quase toda a "
          + "harmonia que você vai encontrar.",
      ],
      example: StaffExample(
        clef: .treble,
        pitches: [60, 64, 67].map { Pitch(UInt8($0)) },
        caption: "A tríade de Dó maior: Dó, Mi e Sol")),

    TheoryNote(
      id: "c-building", topic: .chords,
      title: "Como se monta uma tríade",
      body: [
        "A tríade se constrói empilhando terças a partir de uma nota, chamada "
          + "fundamental.",
        "Sobre Dó: a terça acima é Mi, e a terça acima de Mi é Sol. Fundamental, "
          + "terça e quinta — e o acorde está pronto.",
        "Na pauta isso é fácil de reconhecer: as três notas ficam todas em "
          + "linhas, ou todas em espaços. Um boneco de neve.",
      ]),

    TheoryNote(
      id: "c-major-minor", topic: .chords,
      title: "Maior e menor",
      body: [
        "A diferença entre um acorde maior e um menor está numa única nota: a "
          + "terça.",
        "Se a terça é maior — quatro semitons acima da fundamental — o acorde é "
          + "maior. Se é menor, com três semitons, o acorde é menor. A quinta "
          + "continua a mesma nos dois casos.",
        "Dó maior é Dó–Mi–Sol. Lá menor é Lá–Dó–Mi. Meio tom de diferença muda "
          + "o caráter inteiro do som.",
      ]),

    TheoryNote(
      id: "c-arpeggio", topic: .chords,
      title: "Arpejo e inversão",
      body: [
        "Tocar as notas de um acorde uma após a outra, em vez de juntas, é "
          + "fazer um arpejo. É o mesmo acorde, apresentado no tempo.",
        "Inverter é mudar qual das notas fica no baixo. Dó–Mi–Sol tem o Dó "
          + "embaixo; Mi–Sol–Dó é o mesmo acorde na primeira inversão.",
        "As notas são as mesmas, o acorde é o mesmo — muda a cor e a facilidade "
          + "de ligar um acorde ao seguinte.",
      ]),
  ]
}

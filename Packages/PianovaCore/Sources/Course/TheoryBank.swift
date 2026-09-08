/// The theory questions the course draws from.
///
/// Organised into the four blocks of Med's *Introdução à Teoria da Música*.
/// The blocks and their order come from the book; the individual questions are
/// written here, in our own words, from standard theory.
public enum TheoryBank {
  /// SMuFL code points for the symbols the questions show.
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

  /// Every question, in block order.
  public static let all: [TheoryQuestion] = notation + intervals + scales + chords

  /// Questions from one block.
  /// - Parameter topic: The block to draw from.
  /// - Returns: Its questions, in teaching order.
  public static func questions(for topic: TheoryTopic) -> [TheoryQuestion] {
    all.filter { $0.topic == topic }
  }

  // MARK: - A. Notação musical

  private static let notation: [TheoryQuestion] = [
    TheoryQuestion(
      id: "a1", topic: .notation, noteID: "n-staff",
      prompt: "Quantas linhas tem a pauta?",
      options: ["4", "5", "6"], correctIndex: 1,
      explanation: "A pauta tem cinco linhas e quatro espaços, contados de baixo para cima."),
    TheoryQuestion(
      id: "a2", topic: .notation, noteID: "n-staff",
      prompt: "Quantos espaços tem a pauta?",
      options: ["3", "4", "5"], correctIndex: 1,
      explanation: "Quatro espaços, entre as cinco linhas."),
    TheoryQuestion(
      id: "a16", topic: .notation, noteID: "n-staff",
      prompt: "As linhas da pauta são contadas a partir de onde?",
      options: ["De cima para baixo", "De baixo para cima", "Do meio para fora"],
      correctIndex: 1,
      explanation: "Sempre de baixo para cima: a primeira linha é a mais grave."),
    TheoryQuestion(
      id: "a17", topic: .notation, noteID: "n-staff",
      prompt: "Uma nota mais alta na pauta soa como?",
      options: ["Mais aguda", "Mais grave", "Mais forte"], correctIndex: 0,
      explanation: "Subir na pauta é subir no som — e ir para a direita no teclado."),
    TheoryQuestion(
      id: "a3", topic: .notation, noteID: "n-clefs",
      prompt: "O que esta clave fixa?", glyph: Glyph.trebleClef,
      options: ["O Sol na 2ª linha", "O Dó na 3ª linha", "O Fá na 4ª linha"], correctIndex: 0,
      explanation: "A clave de sol enrola justamente na 2ª linha, e é lá que o Sol fica."),
    TheoryQuestion(
      id: "a4", topic: .notation, noteID: "n-clefs",
      prompt: "Esta clave fixa qual nota?", glyph: Glyph.bassClef,
      options: ["O Sol na 2ª linha", "O Fá na 4ª linha", "O Dó central"], correctIndex: 1,
      explanation: "Os dois pontos da clave de fá abraçam a 4ª linha, onde fica o Fá."),
    TheoryQuestion(
      id: "a18", topic: .notation, noteID: "n-clefs",
      prompt: "Por que a mesma posição na pauta pode ser outra nota?",
      options: [
        "Porque a clave muda a referência", "Porque a pauta muda de tamanho",
        "Porque o compasso muda",
      ],
      correctIndex: 0,
      explanation: "É a clave que diz qual nota fica em qual linha. Troque a clave, troca tudo."),
    TheoryQuestion(
      id: "a19", topic: .notation, noteID: "n-middle-c",
      prompt: "Onde o Dó central é escrito na clave de sol?",
      options: [
        "Numa linha suplementar abaixo", "Na primeira linha da pauta",
        "Numa linha suplementar acima",
      ],
      correctIndex: 0,
      explanation: "Logo abaixo da pauta, na primeira linha suplementar."),
    TheoryQuestion(
      id: "a20", topic: .notation, noteID: "n-middle-c",
      prompt: "Onde o Dó central é escrito na clave de fá?",
      options: [
        "Numa linha suplementar abaixo", "Numa linha suplementar acima", "Na quinta linha",
      ],
      correctIndex: 1,
      explanation: "Logo acima da pauta. É a mesma tecla, escrita dos dois lados."),
    TheoryQuestion(
      id: "a21", topic: .notation, noteID: "n-middle-c",
      prompt: "No teclado, o Dó central fica:",
      options: [
        "À esquerda do grupo de duas pretas", "À direita do grupo de três pretas",
        "Entre duas teclas pretas",
      ],
      correctIndex: 0,
      explanation: "Todo Dó fica logo à esquerda de um grupo de duas teclas pretas."),
    TheoryQuestion(
      id: "a5", topic: .notation, noteID: "n-values",
      prompt: "Quantos tempos vale esta figura?", glyph: Glyph.wholeNote,
      options: ["1", "2", "4"], correctIndex: 2,
      explanation: "A semibreve vale quatro tempos: é a figura mais longa em uso comum."),
    TheoryQuestion(
      id: "a6", topic: .notation, noteID: "n-values",
      prompt: "Quantos tempos vale esta figura?", glyph: Glyph.halfNote,
      options: ["1", "2", "4"], correctIndex: 1,
      explanation: "A mínima vale dois tempos, metade da semibreve."),
    TheoryQuestion(
      id: "a7", topic: .notation, noteID: "n-values",
      prompt: "Quantos tempos vale esta figura?", glyph: Glyph.quarterNote,
      options: ["1", "2", "meio"], correctIndex: 0,
      explanation: "A semínima vale um tempo. É a unidade de tempo mais comum."),
    TheoryQuestion(
      id: "a8", topic: .notation, noteID: "n-values",
      prompt: "Quantas colcheias cabem em uma semínima?", glyph: Glyph.eighthNote,
      options: ["Uma", "Duas", "Quatro"], correctIndex: 1,
      explanation: "Cada colcheia vale meio tempo, então duas completam a semínima."),
    TheoryQuestion(
      id: "a9", topic: .notation, noteID: "n-rests",
      prompt: "O que este sinal indica?", glyph: Glyph.quarterRest,
      options: ["Um tempo de silêncio", "Um tempo mais forte", "Repetir o trecho"],
      correctIndex: 0,
      explanation: "É a pausa de semínima: silêncio com a mesma duração da figura."),
    TheoryQuestion(
      id: "a10", topic: .notation, noteID: "n-rests",
      prompt: "Esta pausa vale quantos tempos?", glyph: Glyph.halfRest,
      options: ["1", "2", "4"], correctIndex: 1,
      explanation: "A pausa de mínima cala dois tempos, e descansa sobre a linha."),
    TheoryQuestion(
      id: "a11", topic: .notation, noteID: "n-dot-tie",
      prompt: "O ponto de aumento acrescenta quanto à figura?",
      options: ["O dobro", "Metade do valor", "Um tempo"], correctIndex: 1,
      explanation: "O ponto vale metade da figura: semínima pontuada vale um tempo e meio."),
    TheoryQuestion(
      id: "a12", topic: .notation, noteID: "n-dot-tie",
      prompt: "A ligadura entre duas notas de mesma altura faz o quê?",
      options: ["Soma as durações", "Toca as duas separadas", "Abaixa meio tom"],
      correctIndex: 0,
      explanation: "Elas viram um som só, com a duração das duas juntas."),
    TheoryQuestion(
      id: "a13", topic: .notation, noteID: "n-bars",
      prompt: "O que as linhas divisórias separam?",
      options: ["As claves", "Os compassos", "As oitavas"], correctIndex: 1,
      explanation: "Cada trecho entre duas linhas divisórias é um compasso."),
    TheoryQuestion(
      id: "a14", topic: .notation, noteID: "n-bars",
      prompt: "No compasso 4/4, o que o 4 de baixo indica?",
      options: ["Quatro tempos", "A semínima como unidade", "Quatro compassos"],
      correctIndex: 1,
      explanation: "O número de cima conta os tempos; o de baixo diz qual figura vale um tempo."),
    TheoryQuestion(
      id: "a15", topic: .notation, noteID: "n-ledger",
      prompt: "Para que serve uma linha suplementar?",
      options: [
        "Escrever notas fora da pauta", "Marcar o compasso", "Indicar para tocar mais forte",
      ],
      correctIndex: 0,
      explanation: "Ela estende a pauta para cima ou para baixo, uma linha de cada vez."),
    TheoryQuestion(
      id: "a22", topic: .notation, noteID: "n-ledger",
      prompt: "As linhas suplementares são acrescentadas como?",
      options: ["Uma a uma", "Sempre em pares", "Cinco de cada vez"], correctIndex: 0,
      explanation: "Uma por vez, conforme a nota se afasta da pauta."),
    TheoryQuestion(
      id: "a23", topic: .notation, noteID: "n-ledger",
      prompt: "Qual é a linha suplementar mais importante para o piano?",
      options: [
        "A do Dó central", "A primeira acima da clave de sol", "A última abaixo da clave de fá",
      ],
      correctIndex: 0,
      explanation: "É a primeira dos dois lados, e liga as duas claves."),
  ]

  // MARK: - B. Intervalos

  private static let intervals: [TheoryQuestion] = [
    TheoryQuestion(
      id: "b1", topic: .intervals, noteID: "i-what",
      prompt: "O que é um intervalo?",
      options: ["A distância entre duas notas", "Uma pausa longa", "O fim do compasso"],
      correctIndex: 0,
      explanation: "Intervalo é a distância de altura entre duas notas."),
    TheoryQuestion(
      id: "b2", topic: .intervals, noteID: "i-what",
      prompt: "Dó e Ré formam qual intervalo?",
      options: ["Uníssono", "Segunda", "Terça"], correctIndex: 1,
      explanation: "Contam-se as notas incluindo as duas pontas: Dó, Ré — segunda."),
    TheoryQuestion(
      id: "b3", topic: .intervals, noteID: "i-what",
      prompt: "Dó e Mi formam qual intervalo?",
      options: ["Segunda", "Terça", "Quarta"], correctIndex: 1,
      explanation: "Dó, Ré, Mi — três nomes, terça. É o intervalo que empilha acordes."),
    TheoryQuestion(
      id: "b4", topic: .intervals, noteID: "i-what",
      prompt: "Dó e Sol formam qual intervalo?",
      options: ["Quarta", "Quinta", "Sexta"], correctIndex: 1,
      explanation: "Dó, Ré, Mi, Fá, Sol — quinta."),
    TheoryQuestion(
      id: "b5", topic: .intervals, noteID: "i-what",
      prompt: "Duas notas de mesmo nome e altura formam o quê?",
      options: ["Uníssono", "Oitava", "Segunda"], correctIndex: 0,
      explanation: "Uníssono: a mesma nota, distância zero."),
    TheoryQuestion(
      id: "b6", topic: .intervals, noteID: "i-what",
      prompt: "Do Dó ao Dó seguinte, acima, é qual intervalo?",
      options: ["Sétima", "Oitava", "Nona"], correctIndex: 1,
      explanation: "Oitava: oito nomes contados, e o som se repete mais agudo."),
    TheoryQuestion(
      id: "b7", topic: .intervals, noteID: "i-tone-semitone",
      prompt: "Entre Mi e Fá a distância é de:",
      options: ["Um tom", "Meio tom", "Um tom e meio"], correctIndex: 1,
      explanation: "Mi–Fá e Si–Dó são os únicos pares vizinhos sem tecla preta entre eles."),
    TheoryQuestion(
      id: "b8", topic: .intervals, noteID: "i-tone-semitone",
      prompt: "Entre Dó e Ré a distância é de:",
      options: ["Meio tom", "Um tom", "Dois tons"], correctIndex: 1,
      explanation: "Há uma tecla preta entre eles, então a distância é de um tom."),
    TheoryQuestion(
      id: "b9", topic: .intervals, noteID: "i-melodic-harmonic",
      prompt: "Duas notas tocadas ao mesmo tempo formam um intervalo:",
      options: ["Melódico", "Harmônico", "Composto"], correctIndex: 1,
      explanation: "Simultâneo é harmônico; uma após a outra é melódico."),
    TheoryQuestion(
      id: "b12", topic: .intervals, noteID: "i-melodic-harmonic",
      prompt: "Duas notas tocadas uma após a outra formam um intervalo:",
      options: ["Melódico", "Harmônico", "Justo"], correctIndex: 0,
      explanation: "Melódico. É de intervalos melódicos que uma melodia é feita."),
    TheoryQuestion(
      id: "b13", topic: .intervals, noteID: "i-melodic-harmonic",
      prompt: "A distância muda quando o intervalo é harmônico?",
      options: ["Não, só a maneira de ouvir", "Sim, fica maior", "Sim, fica menor"],
      correctIndex: 0,
      explanation: "A distância é a mesma; muda apenas se as notas soam juntas ou seguidas."),
    TheoryQuestion(
      id: "b10", topic: .intervals, noteID: "i-quality",
      prompt: "Quantos semitons tem uma terça maior?",
      options: ["3", "4", "5"], correctIndex: 1,
      explanation: "Quatro semitons, como de Dó a Mi. A terça menor tem três."),
    TheoryQuestion(
      id: "b14", topic: .intervals, noteID: "i-quality",
      prompt: "Quantos semitons tem uma terça menor?",
      options: ["2", "3", "4"], correctIndex: 1,
      explanation: "Três. Um semitom a menos que a maior — e é isso que muda o caráter."),
    TheoryQuestion(
      id: "b15", topic: .intervals, noteID: "i-quality",
      prompt: "Quarta, quinta e oitava são chamadas de:",
      options: ["Justas", "Maiores", "Menores"], correctIndex: 0,
      explanation: "Justas. Só segundas, terças, sextas e sétimas são maiores ou menores."),
    TheoryQuestion(
      id: "b11", topic: .intervals, noteID: "i-what",
      prompt: "Dó e Fá formam qual intervalo?",
      options: ["Terça", "Quarta", "Quinta"], correctIndex: 1,
      explanation: "Dó, Ré, Mi, Fá — quarta."),
  ]

  // MARK: - C. Escalas

  private static let scales: [TheoryQuestion] = [
    TheoryQuestion(
      id: "c1", topic: .scales, noteID: "s-what",
      prompt: "O que é uma escala?",
      options: [
        "Uma sucessão ordenada de notas", "Um acorde quebrado", "Um sinal de repetição",
      ],
      correctIndex: 0,
      explanation: "Escala é a sucessão de notas em ordem de altura, subindo ou descendo."),
    TheoryQuestion(
      id: "c2", topic: .scales, noteID: "s-what",
      prompt: "Quantos graus diferentes tem a escala maior?",
      options: ["5", "7", "8"], correctIndex: 1,
      explanation: "Sete graus; o oitavo é a repetição do primeiro, uma oitava acima."),
    TheoryQuestion(
      id: "c3", topic: .scales, noteID: "s-major",
      prompt: "Na escala maior, onde caem os semitons?",
      options: ["Entre 3–4 e 7–8", "Entre 2–3 e 5–6", "Entre 1–2 e 4–5"], correctIndex: 0,
      explanation: "É essa posição fixa dos semitons que dá à escala maior o seu som."),
    TheoryQuestion(
      id: "c4", topic: .scales, noteID: "s-major",
      prompt: "A escala de Dó maior tem quantas alterações?",
      options: ["Nenhuma", "Um sustenido", "Um bemol"], correctIndex: 0,
      explanation: "É só teclas brancas: por isso costuma ser a primeira escala estudada."),
    TheoryQuestion(
      id: "c5", topic: .scales, noteID: "s-key-signature",
      prompt: "Quantos sustenidos tem a escala de Sol maior?",
      glyph: Glyph.sharp,
      options: ["Nenhum", "Um", "Dois"], correctIndex: 1,
      explanation: "Um só: Fá sustenido, necessário para o semitom cair entre o 7º e o 8º grau."),
    TheoryQuestion(
      id: "c6", topic: .scales, noteID: "s-key-signature",
      prompt: "Quantos bemóis tem a escala de Fá maior?", glyph: Glyph.flat,
      options: ["Nenhum", "Um", "Dois"], correctIndex: 1,
      explanation: "Um: Si bemol."),
    TheoryQuestion(
      id: "c7", topic: .scales, noteID: "s-degrees",
      prompt: "O 1º grau da escala chama-se:",
      options: ["Tônica", "Dominante", "Sensível"], correctIndex: 0,
      explanation: "A tônica é o centro: dá nome à escala e é onde a música descansa."),
    TheoryQuestion(
      id: "c8", topic: .scales, noteID: "s-degrees",
      prompt: "Como se chama o 5º grau da escala?",
      options: ["Subdominante", "Dominante", "Mediante"], correctIndex: 1,
      explanation: "A dominante é o grau de maior tensão, que puxa de volta à tônica."),
    TheoryQuestion(
      id: "c9", topic: .scales, noteID: "s-accidentals",
      prompt: "O que o sustenido faz com a nota?", glyph: Glyph.sharp,
      options: ["Sobe meio tom", "Desce meio tom", "Desfaz a alteração"], correctIndex: 0,
      explanation: "Sobe meio tom. O bemol desce meio tom."),
    TheoryQuestion(
      id: "c10", topic: .scales, noteID: "s-accidentals",
      prompt: "O que o bequadro faz com a nota?", glyph: Glyph.natural,
      options: ["Sobe meio tom", "Desce meio tom", "Desfaz a alteração"], correctIndex: 2,
      explanation: "O bequadro cancela o sustenido ou o bemol e devolve a nota ao natural."),
    TheoryQuestion(
      id: "c11", topic: .scales, noteID: "s-major",
      prompt: "O que diferencia a escala menor natural da maior?",
      options: [
        "A posição dos semitons", "O número de notas", "A clave em que se escreve",
      ],
      correctIndex: 0,
      explanation: "Mesmos sete graus, semitons em lugares diferentes — e som diferente."),
  ]

  // MARK: - D. Acordes

  private static let chords: [TheoryQuestion] = [
    TheoryQuestion(
      id: "d1", topic: .chords, noteID: "c-what",
      prompt: "O que é um acorde?",
      options: [
        "Três ou mais sons simultâneos", "Duas notas seguidas", "Uma escala rápida",
      ],
      correctIndex: 0,
      explanation: "Acorde é o conjunto de três ou mais sons ouvidos ao mesmo tempo."),
    TheoryQuestion(
      id: "d2", topic: .chords, noteID: "c-what",
      prompt: "Um acorde de três sons chama-se:",
      options: ["Tríade", "Tétrade", "Arpejo"], correctIndex: 0,
      explanation: "Tríade. Com quatro sons, tétrade."),
    TheoryQuestion(
      id: "d3", topic: .chords, noteID: "c-building",
      prompt: "Como se monta uma tríade?",
      options: [
        "Empilhando terças", "Empilhando segundas", "Empilhando oitavas",
      ],
      correctIndex: 0,
      explanation: "Fundamental, terça e quinta: duas terças empilhadas."),
    TheoryQuestion(
      id: "d4", topic: .chords, noteID: "c-building",
      prompt: "Quais notas formam o acorde de Dó maior?",
      options: ["Dó Ré Mi", "Dó Mi Sol", "Dó Fá Lá"], correctIndex: 1,
      explanation: "Dó (fundamental), Mi (terça maior) e Sol (quinta justa)."),
    TheoryQuestion(
      id: "d5", topic: .chords, noteID: "c-major-minor",
      prompt: "O que torna uma tríade menor?",
      options: ["A terça é menor", "A quinta é diminuta", "A fundamental é grave"],
      correctIndex: 0,
      explanation: "Só a terça muda: menor em vez de maior. A quinta continua justa."),
    TheoryQuestion(
      id: "d6", topic: .chords, noteID: "c-major-minor",
      prompt: "Quais notas formam o acorde de Lá menor?",
      options: ["Lá Dó Mi", "Lá Dó# Mi", "Lá Si Ré"], correctIndex: 0,
      explanation: "Lá, Dó e Mi: a terça Lá–Dó é menor, e por isso o acorde é menor."),
    TheoryQuestion(
      id: "d7", topic: .chords, noteID: "c-building",
      prompt: "Quais notas formam o acorde de Sol maior?",
      options: ["Sol Si Ré", "Sol Sib Ré", "Sol Dó Mi"], correctIndex: 0,
      explanation: "Sol, Si e Ré — de novo fundamental, terça maior e quinta justa."),
    TheoryQuestion(
      id: "d8", topic: .chords, noteID: "c-arpeggio",
      prompt: "Tocar as notas do acorde uma após a outra é fazer um:",
      options: ["Arpejo", "Trinado", "Uníssono"], correctIndex: 0,
      explanation: "Arpejo: o mesmo acorde, sucessivo em vez de simultâneo."),
    TheoryQuestion(
      id: "d9", topic: .chords, noteID: "c-arpeggio",
      prompt: "O que é uma inversão do acorde?",
      options: [
        "Outra nota do acorde no baixo", "Tocar o acorde mais rápido", "Trocar de clave",
      ],
      correctIndex: 0,
      explanation: "As mesmas notas, mas quem fica embaixo não é a fundamental."),
    TheoryQuestion(
      id: "d10", topic: .chords, noteID: "c-what",
      prompt: "Sobre qual grau se constrói o acorde de tônica?",
      options: ["1º", "4º", "5º"], correctIndex: 0,
      explanation: "Sobre a tônica, o 1º grau: é o acorde de repouso da tonalidade."),
    TheoryQuestion(
      id: "d11", topic: .chords, noteID: "c-building",
      prompt: "Um acorde de sétima tem quantos sons?",
      options: ["Três", "Quatro", "Cinco"], correctIndex: 1,
      explanation: "Quatro: a tríade mais a sétima empilhada acima dela."),
  ]
}

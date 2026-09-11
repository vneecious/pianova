import ScoreModel

/// The guided technique drill that closes each unit.
///
/// One per unit, aimed at the movement that unit's music needs. They are short
/// on purpose — three minutes of attention beats twenty of repetition, and a
/// beginner practising a drill inattentively is practising tension.
///
/// Every exercise says what it trains and how to execute it before a key is
/// pressed. That is the difference between a drill and a shape repeated blind.
public enum Technique {
  /// A right hand note, a quarter unless another figure is given.
  private static func r(
    _ n: Int, _ f: Int, _ v: NoteValue = .quarter, dotted: Bool = false
  ) -> TechniqueNote {
    TechniqueNote(Pitch(UInt8(n)), hand: .right, finger: f, value: v, dotted: dotted)
  }

  /// A left hand note.
  private static func l(
    _ n: Int, _ f: Int, _ v: NoteValue = .quarter, dotted: Bool = false
  ) -> TechniqueNote {
    TechniqueNote(Pitch(UInt8(n)), hand: .left, finger: f, value: v, dotted: dotted)
  }

  // MARK: - Unit 1

  /// Both hands over the black-key groups, up and down the keyboard.
  public static let blackKeyGroups = TechniqueExercise(
    id: "t1-black-groups",
    title: "Grupos de teclas pretas",
    goal: "Encontrar os grupos de duas teclas pretas de olhos quase fechados.",
    hints: [
      "Mão direita: dedos 2 e 3 sobre um grupo de duas pretas, no meio do teclado.",
      "Suba de grupo em grupo, um toque por tecla, e volte descendo.",
      "Mão esquerda: a mesma viagem, descendo primeiro.",
      "Toque piano subindo e forte descendo — o teclado inteiro tem dinâmica.",
    ],
    tempo: 66,
    notes: [
      r(61, 2), r(63, 3), r(73, 2), r(75, 3),
      r(75, 3), r(73, 2), r(63, 3), r(61, 2),
      l(49, 3), l(51, 2), l(37, 3), l(39, 2),
      l(39, 2), l(37, 3), l(51, 2), l(49, 3),
      l(49, 3, .whole),
    ])

  /// The music alphabet, walked with one finger and said aloud.
  public static let musicAlphabet = TechniqueExercise(
    id: "t1-alphabet",
    title: "O alfabeto musical",
    goal: "Nomear as teclas brancas em voz alta enquanto o dedo 3 caminha.",
    hints: [
      "Sete letras: A B C D E F G — e então recomeça.",
      "Ache o A no meio do teclado: entre a segunda e a terceira preta do grupo de três.",
      "Suba dizendo cada nome em voz alta; desça dizendo de novo.",
      "Só o dedo 3. O exercício é do ouvido e da boca tanto quanto da mão.",
    ],
    tempo: 72,
    notes: [
      r(57, 3), r(59, 3), r(60, 3), r(62, 3), r(64, 3), r(65, 3), r(67, 3),
      r(67, 3), r(65, 3), r(64, 3), r(62, 3), r(60, 3), r(59, 3),
      r(57, 3, .half, dotted: true),
    ])

  /// C-D-E found from the two-black-key group, octave after octave.
  public static let cdeGroups = TechniqueExercise(
    id: "t1-cde-groups",
    title: "Dó-Ré-Mi pelo teclado",
    goal: "Achar Dó-Ré-Mi a partir do grupo de duas pretas, em qualquer oitava.",
    hints: [
      "O Ré mora entre as duas teclas pretas; Dó e Mi são os vizinhos.",
      "Mão direita, dedos 2-3-4, subindo uma oitava por vez.",
      "Depois a mão esquerda, dedos 4-3-2, descendo.",
      "Diga o nome de cada nota ao tocá-la.",
    ],
    tempo: 69,
    notes: [
      r(60, 2), r(62, 3), r(64, 4), r(72, 2),
      r(74, 3), r(76, 4), r(74, 3), r(72, 2),
      r(64, 4), r(62, 3), r(60, 2, .half),
      l(60, 4), l(62, 3), l(64, 2), l(48, 4),
      l(50, 3), l(52, 2), l(50, 3), l(48, 4),
      l(48, 4, .whole),
    ])

  /// The interval of a third, C up to E, broken then climbed by octaves.
  public static let thirdInterval = TechniqueExercise(
    id: "t1-third-interval",
    title: "O intervalo de terça",
    goal: "Ouvir e medir a distância de Dó a Mi — um intervalo de terça.",
    hints: [
      "De Dó a Mi contam-se três nomes: Dó, Ré, Mi. Isso é uma terça.",
      "Mão direita, dedos 1 e 3, subindo de oitava em oitava.",
      "Mão esquerda, dedos 3 e 1, descendo.",
      "Primeiro quebrado (uma nota depois a outra); ouça o salto.",
    ],
    tempo: 66,
    notes: [
      r(60, 1), r(64, 3), r(72, 1), r(76, 3),
      r(72, 1), r(76, 3), r(76, 3, .half),
      l(60, 3), l(64, 1), l(48, 3), l(52, 1),
      l(48, 3), l(52, 1), l(48, 3, .half),
    ])

  /// F-G-A found from the three-black-key group.
  public static let fgaGroups = TechniqueExercise(
    id: "t1-fga-groups",
    title: "Fá-Sol-Lá pelo teclado",
    goal: "Achar Fá-Sol-Lá a partir do grupo de três pretas, em qualquer oitava.",
    hints: [
      "Fá fica à esquerda do grupo de três pretas; Sol e Lá vêm em seguida.",
      "Mão direita, dedos 2-3-4, subindo uma oitava por vez.",
      "Depois a mão esquerda, dedos 4-3-2, descendo.",
      "Diga o nome de cada nota ao tocá-la.",
    ],
    tempo: 69,
    notes: [
      r(65, 2), r(67, 3), r(69, 4), r(77, 2),
      r(79, 3), r(81, 4), r(79, 3), r(77, 2),
      r(69, 4), r(67, 3), r(65, 2, .half),
      l(65, 4), l(67, 3), l(69, 2), l(53, 4),
      l(55, 3), l(57, 2), l(55, 3), l(53, 4),
      l(53, 4, .whole),
    ])

  /// The C pentascale, five fingers over five notes, both hands.
  public static let cPentascale = TechniqueExercise(
    id: "t1-c-pentascale",
    title: "Pentascale de Dó",
    goal: "Cobrir as cinco notas Dó-Ré-Mi-Fá-Sol com os cinco dedos, sem mover a mão.",
    hints: [
      "Mão direita: polegar no Dó central, um dedo por tecla até o Sol.",
      "Suba e desça sem pressa, um dedo de cada vez, os outros em repouso.",
      "Mão esquerda: dedo 5 no Dó abaixo, espelhando a subida.",
      "O dedo 4 vai querer arrastar o 3 ou o 5 junto. Observe-o.",
    ],
    tempo: 63,
    notes: [
      r(60, 1), r(62, 2), r(64, 3), r(65, 4), r(67, 5),
      r(65, 4), r(64, 3), r(62, 2), r(60, 1, .half),
      l(48, 5), l(50, 4), l(52, 3), l(53, 2), l(55, 1),
      l(53, 2), l(52, 3), l(50, 4), l(48, 5, .half),
    ])

  /// Broken thirds walked up the pentascale and back.
  public static let pentascaleThirds = TechniqueExercise(
    id: "t1-broken-thirds",
    title: "Terças quebradas",
    goal: "Encadear terças — Dó-Mi, Ré-Fá, Mi-Sol — mantendo a mão quieta.",
    hints: [
      "Cada terça pula um dedo: 1-3, 2-4, 3-5.",
      "A mão não persegue os dedos: ela fica parada sobre as cinco notas.",
      "Suba as três terças e volte. Ouça o desenho, não só as notas.",
    ],
    tempo: 60,
    notes: [
      r(60, 1), r(64, 3), r(62, 2), r(65, 4),
      r(64, 3), r(67, 5), r(62, 2), r(65, 4),
      r(60, 1), r(64, 3), r(60, 1, .half),
      l(48, 5), l(52, 3), l(50, 4), l(53, 2),
      l(52, 3), l(55, 1), l(50, 4), l(53, 2),
      l(48, 5), l(52, 3), l(48, 5, .half),
    ])

  // MARK: - Unit 1: peças pré-pauta

  /// Amazing Grace, pentatonic on white keys, guided by finger numbers.
  ///
  /// Own five-finger arrangement of the public-domain hymn tune, placed the
  /// way the unit teaches it: left hand on D-E, right hand on G-A-B-D.
  public static let amazingGrace = TechniqueExercise(
    id: "t1-amazing-grace",
    title: "Amazing Grace",
    goal: "Tocar uma melodia inteira guiado só pelos números dos dedos.",
    hints: [
      "Mão esquerda: dedos 3 e 2 sobre Ré e Mi, abaixo do Dó central... não — sobre Ré e Mi vizinhos do Dó central.",
      "Mão direita: polegar no Sol, dedos sobre Sol-Lá-Si e o 5 alcança o Ré agudo.",
      "Compasso ternário: conte 1-2-3 e deixe as notas longas soarem inteiras.",
      "A melodia você conhece de ouvido — deixe o ouvido conferir cada dedo.",
    ],
    tempo: 63,
    beatsPerBar: 3,
    notes: [
      l(62, 3),
      r(67, 1, .half), r(71, 3),
      r(69, 2, .half), r(67, 1),
      l(64, 2, .half), l(62, 3),
      r(67, 1, .half), r(71, 3),
      r(69, 2, .half), r(71, 3),
      r(74, 5, .half, dotted: true),
      r(74, 5, .half), r(71, 3),
      r(74, 5, .half), r(71, 3),
      r(69, 2, .half), r(67, 1),
      l(64, 2, .half), l(62, 3),
      r(67, 1, .half), r(71, 3),
      r(69, 2, .half), r(71, 3),
      r(67, 1, .half),
    ])

  /// Camptown Races in the C position, hands sharing the melody.
  ///
  /// Own arrangement of Stephen Foster's public-domain tune: right hand on
  /// G-A, left hand on C-D-E, exactly the split the unit practises.
  public static let camptownRaces = TechniqueExercise(
    id: "t1-camptown",
    title: "Camptown Races",
    goal: "Passar a melodia de uma mão para a outra sem quebrar o pulso.",
    hints: [
      "Mão esquerda: dedos 4-3-2 sobre Dó-Ré-Mi. Mão direita: 2-3 sobre Sol-Lá.",
      "Cada mão toca só as suas notas; a melodia atravessa de uma para a outra.",
      "Bata o ritmo na tampa antes de tocar, com a mão certa para cada nota.",
      "As pausas contam: sinta os tempos 3-4 em silêncio antes de seguir.",
    ],
    tempo: 84,
    notes: [
      r(67, 2), r(67, 2), l(64, 2), r(67, 2),
      r(69, 3), r(67, 2, .half, dotted: true),
      l(64, 2), l(62, 3, .half, dotted: true),
      l(64, 2), l(62, 3, .half, dotted: true),
      r(67, 2), r(67, 2), l(64, 2), r(67, 2),
      r(69, 3), r(67, 2, .half, dotted: true),
      l(64, 2), l(64, 2), l(62, 3), l(64, 2),
      l(60, 4, .whole),
    ])

  /// Merrily We Roll Along on just C, D and E.
  ///
  /// Own three-note arrangement of the traditional tune, right hand 1-2-3.
  public static let merrilyCDE = TechniqueExercise(
    id: "t1-merrily-cde",
    title: "Merrily We Roll Along",
    goal: "Uma melodia inteira em três teclas: Dó, Ré e Mi.",
    hints: [
      "Mão direita: polegar no Dó central, dedos 1-2-3 sobre Dó-Ré-Mi.",
      "A melodia desce e sobe por segundas — vizinho a vizinho.",
      "Conte 1-2-3-4 e segure as mínimas pelos dois tempos inteiros.",
    ],
    tempo: 80,
    notes: [
      r(64, 3), r(62, 2), r(60, 1), r(62, 2),
      r(64, 3), r(64, 3), r(64, 3, .half),
      r(62, 2), r(62, 2), r(62, 2, .half),
      r(64, 3), r(64, 3), r(64, 3, .half),
      r(64, 3), r(62, 2), r(60, 1), r(62, 2),
      r(64, 3), r(64, 3), r(64, 3), r(64, 3),
      r(62, 2), r(62, 2), r(64, 3), r(62, 2),
      r(60, 1, .whole),
    ])

  /// The same tune moved to F-G-A: transposing, heard and felt.
  public static let merrilyFGA = TechniqueExercise(
    id: "t1-merrily-fga",
    title: "Merrily em Fá-Sol-Lá",
    goal: "Transpor: a mesma melodia, o mesmo desenho, começando noutra tecla.",
    hints: [
      "Mão direita: dedos 1-2-3 agora sobre Fá-Sol-Lá.",
      "Nada muda além do lugar: os mesmos passos, os mesmos ritmos.",
      "Compare de ouvido com a versão em Dó-Ré-Mi: mais aguda, mesma música.",
    ],
    tempo: 80,
    notes: [
      r(69, 3), r(67, 2), r(65, 1), r(67, 2),
      r(69, 3), r(69, 3), r(69, 3, .half),
      r(67, 2), r(67, 2), r(67, 2, .half),
      r(69, 3), r(69, 3), r(69, 3, .half),
      r(69, 3), r(67, 2), r(65, 1), r(67, 2),
      r(69, 3), r(69, 3), r(69, 3), r(69, 3),
      r(67, 2), r(67, 2), r(69, 3), r(67, 2),
      r(65, 1, .whole),
    ])

  /// Ode to Joy across the whole C pentascale, one finger per key.
  ///
  /// Own arrangement of Beethoven's public-domain theme, right hand 1-5.
  public static let odeToJoyPentascale = TechniqueExercise(
    id: "t1-ode-pentascale",
    title: "Hino à Alegria",
    goal: "Fechar a unidade: os cinco dedos, terças e segundas numa melodia de verdade.",
    hints: [
      "Mão direita na pentascale de Dó: um dedo por tecla, do Dó ao Sol.",
      "A melodia anda por segundas quase sempre — e é isso que a faz cantar.",
      "As duas metades terminam iguais: dois passos curtos e um longo.",
    ],
    tempo: 76,
    notes: [
      r(64, 3), r(64, 3), r(65, 4), r(67, 5),
      r(67, 5), r(65, 4), r(64, 3), r(62, 2),
      r(60, 1), r(60, 1), r(62, 2), r(64, 3),
      r(64, 3), r(62, 2), r(62, 2, .half),
      r(64, 3), r(64, 3), r(65, 4), r(67, 5),
      r(67, 5), r(65, 4), r(64, 3), r(62, 2),
      r(60, 1), r(60, 1), r(62, 2), r(64, 3),
      r(62, 2), r(60, 1), r(60, 1, .half),
    ])

  /// Rounded hand and firm fingertips, over seconds and thirds.
  public static let roundHand = TechniqueExercise(
    id: "t1-round-hand",
    title: "Mão redonda",
    goal: "Sustentar a mão arredondada e apoiar o peso na ponta do dedo.",
    hints: [
      "Imagine segurar uma bola pequena: os dedos curvos, os nós à mostra.",
      "Cada tecla é tocada pela ponta do dedo, não pela polpa deitada.",
      "O pulso fica solto e na altura da mão — nem afundado, nem erguido.",
      "Toque devagar. Se algum dedo endurecer, pare e recomece mais lento.",
    ],
    tempo: 60,
    notes: [
      r(60, 1), r(62, 2), r(64, 3), r(62, 2),
      r(60, 1), r(64, 3), r(62, 2), r(60, 1),
      r(62, 1), r(64, 2), r(65, 3), r(64, 2),
      r(62, 1), r(65, 3), r(64, 2), r(62, 1),
    ])

  // MARK: - Unit 2

  /// Each hand walking up and down its own five notes.
  public static let walkingFingers = TechniqueExercise(
    id: "t2-walking-fingers",
    title: "Dedos que caminham",
    goal: "Fazer cada dedo tocar sozinho, sem que os vizinhos se mexam junto.",
    hints: [
      "Antes de tocar, bata o ritmo com a mão certa contando alto: 1-2-3-4.",
      "Toque uma nota por vez, olhando se os outros dedos ficam parados.",
      "A mão direita sobe do Dó central; a esquerda desce a partir dele.",
      "O dedo 4 é o mais fraco. Ele é o motivo deste exercício.",
    ],
    tempo: 60,
    notes: [
      r(60, 1), r(62, 2), r(64, 3), r(65, 4),
      r(67, 5), r(65, 4), r(64, 3), r(62, 2),
      r(60, 1, .whole),
      l(60, 1), l(59, 2), l(57, 3), l(55, 4),
      l(53, 5), l(55, 4), l(57, 3), l(59, 2),
      l(60, 1, .whole),
    ])

  // MARK: - Unit 3

  /// The same figure taken at three speeds.
  public static let threeTempos = TechniqueExercise(
    id: "t3-three-tempos",
    title: "Três andamentos",
    goal: "Manter o mesmo controle quando a velocidade muda.",
    hints: [
      "Toque três vezes: lento, moderado e um pouco mais rápido.",
      "O andamento sobe só se a versão anterior saiu sem nenhum tropeço.",
      "Se errar, você já está rápido demais. Volte um andamento.",
      "Conte alto 1-2-3 nas três vezes — o pulso é o que não pode mudar.",
    ],
    tempo: 60, beatsPerBar: 3,
    notes: [
      r(60, 1), r(62, 2), r(64, 3),
      r(62, 2), r(64, 3), r(62, 2),
      r(64, 3), r(65, 4), r(67, 5),
      r(67, 5), r(65, 4), r(64, 3),
    ])

  // MARK: - Unit 4

  /// Broken thirds, moving the hand up one note at a time.
  public static let brokenThirds = TechniqueExercise(
    id: "t4-broken-thirds",
    title: "Terças quebradas",
    goal: "Soltar o pulso e apoiar o polegar na lateral da ponta.",
    hints: [
      "O polegar toca de lado, na quina da unha — nunca deitado na tecla.",
      "O pulso fica flexível, mas não afunda abaixo do nível da mão.",
      "A cada compasso a mão inteira se desloca uma tecla para a direita.",
      "Prepare o deslocamento durante a última nota, sem parar o pulso.",
    ],
    tempo: 63,
    notes: [
      r(60, 1), r(64, 3), r(60, 1), r(64, 3),
      r(62, 1), r(65, 3), r(62, 1), r(65, 3),
      r(64, 1), r(67, 3), r(64, 1), r(67, 3),
      r(65, 1), r(69, 3), r(65, 1), r(69, 3),
    ])

  // MARK: - Unit 5

  /// Hands alternating in opposite directions.
  public static let contraryMotion = TechniqueExercise(
    id: "t5-contrary-motion",
    title: "Movimento contrário",
    goal: "Ouvir as duas mãos indo para lados opostos, uma de cada vez.",
    hints: [
      "A direita sobe enquanto a esquerda desce. As mãos se afastam.",
      "As mãos se alternam: nunca soam juntas aqui, revezam-se no pulso.",
      "Deixe a mão que não toca descansando sobre as teclas, sem tensão.",
      "Depois toque tudo em staccato: solte a tecla logo após tocá-la.",
    ],
    tempo: 60,
    notes: [
      r(60, 1), l(59, 2), r(62, 2), l(57, 3),
      r(64, 3), l(55, 4), r(65, 4), l(53, 5),
    ])

  // MARK: - Unit 6

  /// Eighths against quarters, counted aloud.
  public static let eighthNoteDrill = TechniqueExercise(
    id: "t6-eighth-drill",
    title: "Estudo de colcheias",
    goal: "Encaixar duas colcheias num tempo sem apressar o que vem depois.",
    hints: [
      "Bata o ritmo na tampa do piano antes de tocar, contando 1 e 2 e 3 e 4 e.",
      "As colcheias dividem o tempo em dois iguais — nenhuma é mais curta.",
      "O erro típico é acelerar depois das colcheias. Conte alto até o fim.",
      "Só depois de bater certo três vezes seguidas, leve para o teclado.",
    ],
    tempo: 60,
    notes: [
      r(60, 1, .eighth), r(62, 2, .eighth), r(64, 3), r(62, 2), r(60, 1),
      r(64, 3, .eighth), r(65, 4, .eighth), r(67, 5), r(65, 4), r(64, 3),
      r(67, 5, .eighth), r(65, 4, .eighth), r(64, 3, .eighth), r(62, 2, .eighth),
      r(60, 1, .half),
    ])

  // MARK: - Unit 7

  /// The F chord arpeggiated across both hands.
  public static let crossHandArpeggio = TechniqueExercise(
    id: "t7-cross-hand-arpeggio",
    title: "Arpejo de mãos cruzadas",
    goal: "Levar o braço inteiro ao lugar certo antes de o dedo tocar.",
    hints: [
      "A esquerda sobe pelo acorde de Fá; a direita entra por cima dela.",
      "Quem viaja é o braço, não o dedo esticado. O cotovelo abre o caminho.",
      "Olhe para a tecla de destino antes de sair da tecla atual.",
      "Procure som igual entre as mãos: a passagem não pode ter degrau.",
    ],
    tempo: 60,
    notes: [
      l(53, 5), l(57, 3), l(60, 1), r(65, 3),
      r(69, 5), r(65, 3), l(60, 1), l(57, 3),
    ])

  // MARK: - Unit 8

  /// The right hand answering the left, note for note.
  public static let imitation = TechniqueExercise(
    id: "t8-imitation",
    title: "Estudo de imitação",
    goal: "Repetir com uma mão exatamente o que a outra acabou de tocar.",
    hints: [
      "A esquerda propõe, a direita responde a mesma coisa uma oitava acima.",
      "As colcheias precisam sair perfeitamente iguais nas duas mãos.",
      "Prepare a mão que vai responder enquanto a outra ainda toca.",
      "Grave e escute: a resposta soou igual à pergunta, ou mais pesada?",
    ],
    tempo: 60,
    notes: [
      l(48, 5, .eighth), l(50, 4, .eighth), l(52, 3, .eighth), l(53, 2, .eighth),
      r(60, 1, .eighth), r(62, 2, .eighth), r(64, 3, .eighth), r(65, 4, .eighth),
      l(52, 3, .eighth), l(53, 2, .eighth), l(55, 1, .eighth), l(53, 2, .eighth),
      r(64, 3, .eighth), r(65, 4, .eighth), r(67, 5, .eighth), r(65, 4, .eighth),
      l(48, 5, .half), r(60, 1, .half),
    ])

  // MARK: - Unit 9

  /// Thirds inside the G pentascale.
  public static let fingerFanfare = TechniqueExercise(
    id: "t9-finger-fanfare",
    title: "Fanfarra de dedos",
    goal: "Firmar a posição de Sol com a mesma segurança da posição de Dó.",
    hints: [
      "Ache a posição antes de tocar: polegar no Sol, mínimo no Ré.",
      "Bata o ritmo contando alto 1-2-3-4 antes de levar ao teclado.",
      "São terças alternadas: dedos 1-3, depois 2-4, depois 3-5.",
      "Toque sem olhar para a mão. A posição já deve estar no tato.",
    ],
    tempo: 66,
    notes: [
      r(67, 1), r(71, 3), r(67, 1), r(71, 3),
      r(69, 2), r(72, 4), r(69, 2), r(72, 4),
      r(71, 3), r(74, 5), r(71, 3), r(74, 5),
      r(74, 5), r(71, 3), r(67, 1, .half),
    ])

  // MARK: - Unit 10

  /// The major pentascale pattern, over a black key.
  public static let wholeAndHalfSteps = TechniqueExercise(
    id: "t10-whole-and-half",
    title: "Tom, tom, semitom, tom",
    goal: "Sentir na mão o desenho que faz um pentascale ser maior.",
    hints: [
      "Este é o pentascale de Ré: Ré, Mi, Fá♯, Sol, Lá.",
      "Entre Fá♯ e Sol há um semitom — teclas vizinhas, sem nada no meio.",
      "O dedo 3 sobe para a tecla preta e volta. A mão não se desloca.",
      "Diga em voz alta tom-tom-semitom-tom enquanto sobe.",
    ],
    tempo: 63,
    notes: [
      r(62, 1), r(64, 2), r(66, 3), r(67, 4),
      r(69, 5), r(67, 4), r(66, 3), r(64, 2),
      r(62, 1, .whole),
    ])

  // MARK: - Unit 11

  /// Fourths, fifths and sixths from a fixed thumb.
  public static let intervalStudy = TechniqueExercise(
    id: "t11-interval-study",
    title: "Estudo de intervalos",
    goal: "Abrir a mão para o intervalo sem tensionar o pulso.",
    hints: [
      "O polegar fica ancorado no Dó. Só o dedo de cima muda de tecla.",
      "Toque o polegar leve: ele é pesado por natureza e abafa o resto.",
      "A abertura vem da mão inteira, não de esticar um dedo sozinho.",
      "Ligue as notas — legato, sem cortar o som entre uma e outra.",
    ],
    tempo: 63,
    notes: [
      r(60, 1), r(65, 4), r(60, 1), r(67, 5),
      r(60, 1), r(69, 5), r(60, 1), r(67, 5),
      r(60, 1), r(65, 4), r(60, 1), r(64, 3),
      r(60, 1, .whole),
    ])

  // MARK: - Unit 12

  /// The C major scale, one octave, with the thumb passing under.
  public static let cScale = TechniqueExercise(
    id: "t12-c-scale",
    title: "Escala de Dó maior",
    goal: "Passar o polegar por baixo sem que a escala dê um solavanco.",
    hints: [
      "Subindo: 1-2-3, o polegar passa por baixo, 1-2-3-4-5.",
      "O polegar começa a se mover para baixo já na nota anterior.",
      "O cotovelo acompanha suavemente para fora. O pulso não gira.",
      "Escute o ponto da passagem: se ouve um degrau, desacelere.",
    ],
    tempo: 66,
    notes: [
      r(60, 1), r(62, 2), r(64, 3), r(65, 1),
      r(67, 2), r(69, 3), r(71, 4), r(72, 5),
      r(72, 5), r(71, 4), r(69, 3), r(67, 2),
      r(65, 1), r(64, 3), r(62, 2), r(60, 1),
    ])

  // MARK: - Unit 13

  /// C, Csus4 and G7, broken.
  public static let chordWarmup = TechniqueExercise(
    id: "t13-chord-warmup",
    title: "Aquecimento de acordes",
    goal: "Trocar de acorde mudando só o dedo que precisa mudar.",
    hints: [
      "Dó, Dó4, Sol7 e Dó de novo. Repare no que fica parado entre eles.",
      "Do acorde de Dó para o Dó4, só o dedo 3 sobe para o Fá.",
      "Prepare a forma da mão no ar antes de descer no acorde seguinte.",
      "Depois toque os mesmos acordes bloqueados, as notas todas juntas.",
    ],
    tempo: 63,
    notes: [
      r(60, 1), r(64, 3), r(67, 5), r(64, 3),
      r(60, 1), r(65, 4), r(67, 5), r(65, 4),
      r(59, 1), r(62, 2), r(65, 4), r(67, 5),
      r(60, 1), r(64, 3), r(67, 5, .half),
    ])

  // MARK: - Unit 14

  /// The primary chords of C, arpeggiated in three.
  public static let chordEtude = TechniqueExercise(
    id: "t14-chord-etude",
    title: "Estudo de acordes",
    goal: "Deixar o pulso conduzir a mão de um acorde ao próximo.",
    hints: [
      "São os acordes I, IV, V7 e I de Dó maior, um por compasso.",
      "No fim de cada compasso o pulso levanta de leve e leva a mão.",
      "Quem escolhe a inversão é a preguiça: a que exige menos movimento.",
      "Toque tudo bem suave. Este estudo é de gesto, não de força.",
    ],
    tempo: 60, beatsPerBar: 3,
    notes: [
      r(60, 1), r(64, 3), r(67, 5),
      r(60, 1), r(65, 4), r(69, 5),
      r(59, 1), r(62, 2), r(67, 5),
      r(60, 1), r(64, 3), r(67, 5),
    ])

  // MARK: - Unit 15

  /// The G major scale, split between the hands.
  public static let gScaleDivided = TechniqueExercise(
    id: "t15-g-scale-divided",
    title: "Escala de Sol dividida",
    goal: "Passar a escala de uma mão para a outra sem quebrar o pulso.",
    hints: [
      "A esquerda toca a primeira metade; a direita continua de onde ela parou.",
      "O Fá é sustenido: é a armadura da tonalidade de Sol maior.",
      "A passagem entre as mãos é o ponto crítico — nada de hesitar ali.",
      "Tudo em semínimas, andamento absolutamente constante.",
    ],
    tempo: 66,
    notes: [
      l(55, 5), l(57, 4), l(59, 3), l(60, 2),
      r(62, 1), r(64, 2), r(66, 3), r(67, 4),
      r(67, 4), r(66, 3), r(64, 2), r(62, 1),
      l(60, 2), l(59, 3), l(57, 4), l(55, 5),
    ])

  // MARK: - Unit 16

  /// A rolling gesture from the left hand into the right.
  public static let musicBoxEtude = TechniqueExercise(
    id: "t16-music-box",
    title: "Estudo da caixinha de música",
    goal: "Ligar a mão esquerda à direita num gesto único e contínuo.",
    hints: [
      "A esquerda dá o baixo e o gesto rola para a direita, sem emenda.",
      "A direita sempre entra com o polegar, e entra leve.",
      "Pense numa frase só, atravessando as duas mãos.",
      "Para o efeito de caixinha de música, repita tudo uma oitava acima.",
    ],
    tempo: 66, beatsPerBar: 3,
    notes: [
      l(55, 5), r(71, 1), r(74, 3),
      l(50, 5), r(69, 1), r(74, 3),
      l(48, 5), r(72, 1), r(76, 3),
      l(55, 5), r(71, 1), r(74, 3),
    ])
}

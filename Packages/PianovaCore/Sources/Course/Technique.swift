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
  private static func r(_ n: Int, _ f: Int, _ v: NoteValue = .quarter) -> TechniqueNote {
    TechniqueNote(Pitch(UInt8(n)), hand: .right, finger: f, value: v)
  }

  /// A left hand note.
  private static func l(_ n: Int, _ f: Int, _ v: NoteValue = .quarter) -> TechniqueNote {
    TechniqueNote(Pitch(UInt8(n)), hand: .left, finger: f, value: v)
  }

  // MARK: - Unit 1

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

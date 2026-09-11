# Pianova

**Treinador de leitura de partitura ao piano.**

App de iPad para treinar leitura de partitura usando o **piano físico como
dispositivo de resposta**. O app apresenta notas na pauta; a resposta é tocar as
teclas correspondentes no teclado, conectado por USB.

## O problema

Quem começa a ler partitura normalmente treina com cartões: "que nota é esta?",
e responde escolhendo um nome numa lista. Isso ensina a *nomear* o símbolo, mas
não ensina a encontrá-lo no teclado — que é o que realmente trava na hora de
tocar. O nome da nota vira uma etapa intermediária: ler → nomear → lembrar onde
fica → tocar.

O objetivo aqui é eliminar a etapa do meio. Ao responder tocando, o que se
treina é a associação direta entre **a posição do símbolo na pauta** e **a
posição da tecla sob a mão**.

## Princípio central

O piano não é um acessório do app: é a interface de entrada. Toda validação de
resposta vem de MIDI real — qual tecla, quando, com que intensidade. Nada de
teclado na tela como forma primária de resposta.

## Modelo de interação

Um exercício é uma **sequência ordenada** de itens, onde cada item é uma nota ou
um conjunto de notas simultâneas. Um cursor marca o item atual e caminha pela
sequência conforme se toca — sem botão de confirmar, sem pausa entre itens.

Regras de avanço:

1. O cursor marca sempre exatamente um item: o que deve ser tocado agora.
2. **Acerto** → o cursor avança imediatamente para o próximo item.
3. Para itens de múltiplas notas, o item só é considerado correto quando **todas**
   as notas exigidas estiverem pressionadas simultaneamente, dentro de uma
   janela de tolerância.
4. **Erro** (qualquer nota fora do item esperado) → feedback visual de erro e o
   cursor **recua uma posição**, para que o trecho seja refeito a partir do item
   anterior.
5. Se o erro ocorre no primeiro item da sequência, o cursor permanece nele — não
   existe posição anterior.
6. Não há penalidade de tempo nem pontuação. O objetivo é repetir até a resposta
   sair sem hesitação.

O recuo em caso de erro é deliberado: refazer a transição que falhou treina a
passagem entre as notas, não apenas a nota isolada. O funcionamento é inspirado
no Duolingo Music — o comportamento, não a estética.

## Os dois elos

Ler partitura ao piano são **duas associações distintas**, e treinar uma não
ensina a outra:

| Elo | O que treina | Onde |
|---|---|---|
| **pauta → tecla** | achar a nota sob a mão, sem pensar no nome | modo piano |
| **pauta → nome** | saber que aquilo se chama Dó | modo cards |

O modo piano sozinho produz reconhecimento espacial: dá para acertar todas as
notas sem nunca saber como elas se chamam. O modo cards sozinho produz quem sabe
nomear e não acha a tecla. O app precisa dos dois, e eles avançam em paralelo.

Consequência prática: o **modo cards não usa o instrumento**, então funciona em
qualquer lugar — e sem as restrições de MIDI que limitam o modo piano.

## Modo cards — nomear a nota

Um card mostra uma nota na pauta e pergunta o nome dela. A resposta é dada em
**solfejo** (Dó, Ré, Mi, Fá, Sol, Lá, Si), tocando um dos sete botões fixos.

Regras:

1. Cada card mostra **uma única nota**, em clave de sol ou de fá.
2. Os sete botões de resposta ficam **sempre na mesma posição**. Não são
   embaralhados e não há alternativas sorteadas: acertar por eliminação não
   treina nada, e a posição fixa vira reflexo.
3. **Acerto** → o card seguinte aparece imediatamente.
4. **Erro** → o app mostra qual era a resposta certa, e o card **volta para o
   fim da fila** para ser revisto ainda na mesma rodada.
5. A rodada termina quando todos os cards tiverem sido respondidos
   corretamente — errar não elimina um card, só o adia.
6. **Acidentes não mudam o nome**: Dó sustenido responde-se como Dó. O que se
   treina aqui é a leitura da posição na pauta, não a alteração.

A regra 4 é o análogo do recuo do modo piano: em vez de seguir em frente
deixando o erro para trás, o app insiste no que falhou.

### Cards invertidos — achar a posição

Nomear uma nota mostrada é **reconhecimento**. Apontar onde uma nota fica é
**evocação** — mais difícil, mais duradoura, e é outra habilidade. A rodada
mistura as duas direções para que não dê para entrar em piloto automático.

11. Um card invertido mostra o **nome** da nota e uma pauta vazia; a resposta é
    tocar na linha ou espaço onde ela fica.
12. O toque **gruda na posição mais próxima**, então acertar não depende de
    precisão de toque, só de saber o lugar.
13. **A oitava importa.** O card pede uma posição específica, não qualquer nota
    com aquele nome — por isso o nome vem com o número da oitava (`Dó 4`).
14. Do nível 2 em diante, **um terço dos cards da rodada é invertido**. O nível
    1 é só direto, para firmar o básico antes de somar dificuldade.

### As duas claves desde o começo

15. **As duas claves entram juntas.** A primeira lição que lê a pauta apresenta
    a clave de sol e a de fá ao mesmo tempo, e o curso nunca ensina uma clave
    inteira antes de apresentar a outra.

> A redação anterior dizia "na primeira lição do curso". Não sobreviveu à ordem
> do método: a unidade 1 é orientação ao teclado e não lê pauta nenhuma. O que
> importa é que nenhuma clave chegue depois da outra, e isso continua valendo.

O motivo é o do método adotado: quem aprende todas as notas na clave de sol
primeiro precisa depois *rememorizar* tudo na clave de fá, e as duas leituras
passam a competir. Apresentadas juntas desde o início, cada uma nasce no seu
lugar.

Na prática o curso cresce **a partir do Dó central para os dois lados** — a mão
direita subindo na clave de sol, a esquerda descendo na de fá — em vez de
percorrer uma clave inteira e depois voltar ao começo.

### A trilha: lições, não modos

O curso é uma sequência de **lições**, percorrida numa trilha vertical.

16. Uma lição é uma lista curta de **atividades em ordem**, e cada atividade é
    de um destes tipos: **cards** (teoria), **prática** (uma sequência gerada
    para tocar) ou **música** (uma peça do início ao fim).
17. Uma lição **mistura teoria e piano**. Não existe "modo cards" separado de
    "modo piano": os dois elos se treinam juntos, dentro da mesma lição.
18. As lições **abrem em ordem**: a próxima libera quando a anterior é
    concluída. Uma lição já concluída continua aberta para repetir.
19. **Prática livre** permite repetir qualquer lição já aberta sem mexer na
    trilha — serve para insistir num ponto fraco, não para avançar.

O currículo cresce a partir do Dó central para os dois lados. Uma lição pode
**estreitar a faixa de propósito** quando é construída em torno de uma peça:
música de iniciante fica em posição de cinco dedos.

> Uma progressão anterior, por níveis, ensinava a clave de sol inteira antes de
> apresentar a de fá. Foi removida por contradizer a regra 15.

### A ordem do curso: 16 unidades

A trilha segue a **sequência pedagógica de um método adulto consagrado** — 16
unidades, cada uma introduzindo um conceito novo e revisando os anteriores.

20. O curso tem **exatamente 16 unidades**, na ordem fixa abaixo. Uma unidade só
    abre quando a anterior é concluída.
21. Cada unidade **introduz pelo menos um conceito que nenhuma anterior
    introduziu**. Nenhum conceito é ensinado duas vezes como novidade.
22. Toda unidade termina com duas atividades, nesta ordem: **técnica guiada** e
    **teoria**. É o fecho que o método usa, e o app não o dispensa.
23. Uma unidade **nunca pede uma nota, figura ou símbolo que nenhuma unidade
    até ela tenha apresentado.**

| # | Unidade | Conceito que estreia |
|---|---|---|
| 1 | Introdução ao teclado | Postura, dedilhado, pentascale de Dó e Sol, 2ªs e 3ªs |
| 2 | Orientação na pauta | Pauta, claves, fórmula de compasso, ligadura, legato |
| 3 | Reforço de leitura | Sol na clave de sol; Sol e Fá na clave de fá; coda |
| 4 | Mais leitura na pauta | 3ªs na pauta, pausas, D.C. al Fine, acorde de Dó |
| 5 | Mais clave de fá | Dó-Ré-Mi graves, hastes, staccato, casas 1 e 2 |
| 6 | Colcheias | Colcheia, frase, crescendo, fermata, anacruse |
| 7 | Espaços da clave de sol | F-A-C-E, cruzamento de mãos, arpejo |
| 8 | Pentascale de Dó agudo | Dó-Sol agudos, imitação, ritardando |
| 9 | Pentascale de Sol | Sol em três posições, acorde de Sol |
| 10 | Sustenidos e bemóis | Semitom, tom, sustenido, bemol, bequadro |
| 11 | Intervalos: 4ªs, 5ªs, 6ªs | Quarta, quinta e sexta |
| 12 | Escala de Dó maior | Escala completa, tônica, dominante, sensível |
| 13 | O acorde de Sol7 | V7, substituição de dedo |
| 14 | Acordes primários em Dó | I-IV-V7, inversão, cifra |
| 15 | Escala de Sol maior | Armadura de clave |
| 16 | Acordes primários em Sol | I-IV-V7 em Sol, Ré7 |

> **Origem e limite.** A ordem das unidades e os conceitos de cada uma seguem o
> método. As melodias são de **domínio público**, escritas neste repositório, e
> os exercícios de técnica são originais: nenhum arranjo, texto ou peça
> protegida é reproduzido. Onde o método usa uma peça ainda em direito autoral,
> a trilha põe uma equivalente de domínio público no mesmo nível.

### Exercícios de técnica guiados

24. Um exercício de técnica é **guiado**: antes de tocar, o app mostra o
    **objetivo** e as **instruções de execução**, uma por linha.
25. Todo exercício de técnica declara **qual dedo toca cada nota**, e o
    dedilhado é mostrado nota a nota sob a pauta, com a mão indicada.
26. Um exercício de técnica é **percutido antes de ser tocado**: primeiro o
    ritmo, contando em voz alta; só depois as notas.
27. O exercício é validado **com ritmo**, não só por altura — a tolerância é a
    do modo de leitura, generosa por decisão pedagógica.

### Ilustração antes de descrição

Um método de piano é um livro ilustrado, e não por enfeite: teclado, mãos e
duração são coisas **espaciais**. Descrever em palavras onde fica o Dó custa um
parágrafo e ainda sai ambíguo; um teclado desenhado com a tecla marcada resolve
sem texto nenhum.

28. Toda página que ensina algo que **se vê** mostra a coisa desenhada, e não
    apenas descrita. São quatro tipos de figura: **teclado**, **mãos com os
    dedos numerados**, **árvore de valores** e **exemplo em pauta**.
29. Num diagrama de teclado, tudo que for marcado ou colchetado fica **dentro
    da extensão desenhada** — um diagrama não aponta para fora de si.
30. Toda figura tem **legenda**. Uma figura sem legenda obriga a voltar ao texto
    para descobrir o que ela quer dizer, e aí ela não substituiu nada.

### Partitura de verdade

Uma peça não é uma fila de notas. Uma primeira versão guardava só as alturas, e
o resultado desenhado não era uma partitura pobre — era uma sequência de
cabeças de nota sobre cinco linhas, sem ritmo, sem compasso, sem armadura. Não
dá para aprender a ler numa coisa dessas.

31. Toda peça declara **fórmula de compasso** e **armadura de clave**.
32. Toda nota declara sua **figura**. Uma peça sem ritmo escrito não é peça.
33. Os compassos **fecham**: a soma das figuras de cada compasso é exatamente o
    que a fórmula manda. A única exceção é a **anacruse**, que é o primeiro
    compasso e é incompleta por definição.
34. A pauta desenha **fórmula de compasso, barras de compasso e armadura**.
    Barra dupla no fim.
35. Pausas são escritas e desenhadas como pausas — nunca como um buraco.

### Importar partituras

36. O formato de entrada é **MusicXML** (`.musicxml`, e `.mxl` comprimido), que
    é o que todo editor exporta e o que o IMSLP e o MuseScore distribuem.
37. O que o importador não souber ler ele **recusa com uma mensagem**, em vez de
    importar pela metade e produzir uma partitura silenciosamente errada.

### A pauta rola, não encolhe

Espremer a peça inteira na largura da tela dá uma linha ilegível: as cabeças de
nota se sobrepõem e as hastes colidem. Uma partitura tem a largura que precisa
ter, e quem se move é a janela.

38. As notas têm **espaçamento mínimo fixo**. A pauta nunca comprime a peça para
    caber na largura disponível.
39. A pauta **rola conforme o cursor avança**, mantendo a nota atual **à
    esquerda do centro** — com mais música visível à frente do que atrás.
    Ler adiante é a habilidade; uma nota centralizada esconde metade dela.
40. **Clave, armadura e fórmula de compasso ficam fixas** na borda esquerda
    enquanto a música rola por baixo. Elas valem para o trecho inteiro, então
    sair de vista seria perder a referência.
41. A rolagem **para nas pontas**: nunca antes da primeira nota, nunca depois de
    a última entrar na janela.

### Errar no exercício de tempo

Deixar a música seguir depois do erro é o pior dos dois mundos: você perde o
pulso e continua tocando errado até o fim. Quem estuda de verdade volta ao
início do compasso e retoma.

42. Um erro **interrompe a passagem**. O exercício volta ao **início do compasso**
    onde o erro aconteceu — não ao começo da peça.
43. Antes de retomar, a **contagem de entrada acontece de novo**. Retomar sem
    ouvir o pulso é recomeçar sem referência.
44. O que foi tocado certo **antes** do compasso do erro permanece certo. Só o
    compasso refeito volta a ser avaliado.
45. A linha-guia é posicionada pela **mesma aritmética das cabeças de nota**.
    Ela nunca varre a largura da tela, ou aponta para um lugar onde não há nota.

### Repertório

Uma peça presa dentro da lição que a usa só pode ser tocada refazendo a lição
inteira. Mas tocar música é o motivo de estudar piano, e querer sentar e tocar
uma peça conhecida não é desvio do curso — é o ponto dele.

46. Existe uma tela de **repertório** que lista **todas as peças do app**, e
    qualquer uma pode ser tocada direto, sem passar por lição nenhuma.
47. Cada peça mostra **compositor, tonalidade, compasso e a unidade** em que
    aparece no curso — que é o que indica o quão difícil ela é.
48. O repertório **não mexe na trilha**. Tocar uma peça ali não conclui lição,
    não destrava nada e não altera o progresso.
49. A lista é ordenada pela **ordem do curso**, da mais simples à mais difícil,
    porque essa é a informação que ajuda a escolher.

### Espaço é tempo

50. A largura de cada nota é **proporcional à sua duração**. Uma semibreve ocupa
    quatro vezes o espaço de uma semínima; uma colcheia, metade.

Gravação profissional usa uma escala comprimida, para economizar página. Aqui
não há página para economizar, e há uma linha-guia andando em velocidade
constante: com espaço proporcional ao tempo, **a linha e as notas se movem na
mesma escala**, e seguir a música vira uma coisa só em vez de duas. O olho
também passa a ler duração como distância, antes de ler a figura.

51. Há uma **largura mínima** por nota. Proporcional não pode significar
    ilegível quando a peça mistura semibreves e colcheias.

### Seguir sem esforço

52. A rolagem é **contínua e animada**, nunca um salto. A pauta desliza entre
    uma nota e a seguinte.
53. O ponto onde a música está agora é marcado na pauta **mesmo antes de tocar**,
    para que nunca seja preciso procurar onde se está.
54. A nota atual é distinguível **de relance**, sem comparar com as vizinhas.

### O Treino mede tempo, não só acerto

Acerto satura. Um iniciante chega a 95% em poucas semanas e o número para de se
mexer — justo quando a evolução real começa. **Tempo continua se movendo por
anos**, e é o que separa quem calcula a nota de quem a reconhece.

55. O Treino cronometra cada resposta e reporta a **mediana**, nunca a média.
    Uma distração no meio da rodada destrói uma média e não move uma mediana.
56. A estatística é **por estilo de pergunta**. Cronometrar reconhecimento
    auditivo mede outra habilidade que não cronometrar leitura de pauta, e num
    exercício de ouvido velocidade **não é o objetivo** — ali vale o acerto.
57. O Treino mostra **em quais notas se hesita mais**, ordenadas pela demora.
    Uma mediana diz como você está; a lista diz o que estudar amanhã.
58. As notas hesitadas **realimentam o gerador**: o Treino passa a perguntar
    mais sobre elas, sem que seja preciso ler painel nem decidir nada.
59. Só conta para a estatística a resposta dada **sem erro**. Cronometrar uma
    tentativa que já falhou mede a digitação, não o reconhecimento.

### O som

Síntese aditiva não soa como piano, e não vai soar: o timbre vem de centenas de
cordas com ressonância simpática, ruído de martelo e comportamento de abafador.

60. Com o instrumento conectado, o app **toca pelo próprio instrumento**,
    mandando MIDI de volta para ele. Não é parecido com o piano do usuário —
    é o piano do usuário.
61. Isso também resolve o eco: sem roteamento, tocar uma tecla soa **duas
    vezes**, no piano e no sintetizador do app, levemente defasadas.
62. Sem instrumento conectado, o app usa um **piano amostrado** se houver um
    banco de sons instalado, e só cai no sintetizador se não houver.
63. O usuário pode **desligar o roteamento** e ouvir o app, para comparar.

### Carregar partituras

64. O app importa **MusicXML** (`.musicxml`, `.xml`) e renderiza na mesma pauta
    que o resto do curso usa.
65. O que o importador não souber ler ele **recusa dizendo o quê**, em vez de
    produzir uma partitura silenciosamente errada.
66. Uma peça importada pode ser tocada de dois modos: **livre**, onde a pauta
    espera por você, e **no tempo**, onde ela não espera.
67. Existe um **preview**: o app toca a peça sozinho, para servir de referência
    de como deveria soar. O preview nunca avalia nada.

### Sistemas, não uma faixa infinita

Uma peça inteira numa única linha que rola para o lado é ilegível quando tem
545 notas, e não é como ninguém lê música. Papel quebra em **sistemas**, e a
quebra é o que dá descanso ao olho e ensina o movimento real da leitura:
esquerda para direita, depois desce.

68. A partitura é quebrada em **sistemas** empilhados verticalmente, cada um
    ocupando a largura disponível.
69. A quebra acontece **sempre numa barra de compasso**, nunca no meio de um.
70. Cada sistema repete **clave e armadura**; a fórmula de compasso aparece
    só no primeiro, como em partitura impressa.
71. A rolagem vertical **acompanha o cursor** sozinha, mantendo visível o
    sistema que está sendo tocado.
72. O usuário pode **rolar à mão** a qualquer momento, para olhar adiante ou
    conferir o que passou.
73. Cada sistema mostra o **número do primeiro compasso** dele, como em edição
    impressa. Não é enfeite: o app fala em compassos — "vamos refazer este
    compasso", "o compasso 7 tem uma nota sem duração" — e sem numeração não
    há como saber qual.
74. A **anacruse não é numerada**. O primeiro compasso completo é o número 1,
    que é a convenção de qualquer editora.

### Metrônomo

75. O metrônomo pode ficar **ligado o tempo todo**, em qualquer tela, com
    andamento e compasso ajustáveis.
76. O **primeiro tempo do compasso é acentuado**. Um clique sem acento marca
    pulso mas não marca compasso, e é o compasso que se está aprendendo a
    sentir.
77. O metrônomo **não deriva**: cada clique é agendado contra o instante de
    início, nunca somando esperas — somar acumula erro, e um metrônomo que
    atrasa é pior que nenhum.
78. Um exercício que traz o próprio pulso **silencia o metrônomo global**
    enquanto roda, e o devolve ao terminar. Dois pulsos ao mesmo tempo é ruído.

### O último sistema

79. Todo sistema é esticado para preencher a linha, **menos o último**.
80. No último sistema, **as linhas da pauta terminam na barra final** — não
    seguem até a margem. Pauta vazia depois do fim da música não existe em
    partitura impressa.
81. A exceção: um último sistema que já ocupa **mais de 70% da linha** é
    justificado assim mesmo, porque um vão pequeno no fim fica pior que a
    linha cheia. É o mesmo critério que os editores usam.

### Ouvir a peça

82. Durante o preview, a partitura **acompanha o que está soando**: a nota atual
    é marcada e a página rola sozinha.
83. Dá para **ouvir a partir de um trecho**, escolhendo onde começar em vez de
    sempre voltar ao início. Estudar é repetir um pedaço, não a peça inteira.

### Barras de ligação

Colcheia solta usa bandeirola; colcheias seguidas se unem por uma barra
horizontal. E isso não é vaidade tipográfica: **a barra agrupa o que pertence a
um mesmo tempo**. Duas colcheias ligadas se leem como "um tempo"; duas
bandeirolas soltas se leem como duas notas sem relação, e obrigam a contar.

84. Figuras menores que a semínima que caem **no mesmo tempo** são unidas por
    barra de ligação.
85. Uma nota **sozinha** no seu tempo mantém a bandeirola. Barra de uma nota só
    não existe.
86. Uma **pausa interrompe** a ligação: o grupo não atravessa o silêncio.
87. Em compasso composto (6/8, 9/8, 12/8) o agrupamento é **de três em três**,
    porque ali o tempo é a semínima pontuada.
88. O grupo **nunca atravessa a barra de compasso**.
89. Cada **nível de barra** cobre só as notas que o carregam: a primeira
    atravessa o grupo, a segunda aparece apenas sobre as semicolcheias. Uma
    barra só sobre um grupo misto desenha semicolcheia como colcheia, que é
    outro ritmo.

### Partituras importadas ficam

90. Uma partitura importada **sobrevive ao fechamento do app**. Importar algo
    que some ao fechar obriga a reimportar toda sessão.
91. O que é guardado é o **arquivo original**, relido a cada abertura. O arquivo
    é a fonte da verdade; guardar a interpretação dele congelaria os erros de
    leitura que ainda vamos corrigir.
92. Uma partitura importada pode ser **removida** da lista.

### A nota pertence à pauta em que foi escrita

93. Numa pauta dupla, cada nota é desenhada **na pauta em que foi escrita**,
    não na que sua altura sugere. Um Dó central escrito na clave de fá é
    desenhado lá, com linha suplementar.

Decidir pela altura parece razoável e é errado: no prelúdio BWV 846 a mão
esquerda toca Dó4 e Mi4, e roteá-los pela altura mandou a mão esquerda inteira
para a clave de sol, deixando a de fá vazia.

## Gravação de partitura

Notação de verdade é polifônica: cada pauta tem vozes independentes, cada voz
com ritmo, pausas e hastes próprias. O modelo deste app é o de quem **toca** —
uma coluna é um instante e o conjunto de teclas a apertar — e ele não
representa isso. Competir com um gravador de verdade não é trabalho de semanas.

94. Partitura é desenhada pelo **Verovio**, a mesma tradição de gravação que o
    MuseScore e o Finale seguem.
95. O julgamento continua **nativo**: qual tecla, quando, acerto e erro. O
    Verovio desenha; ele não decide nada.
96. A ligação entre os dois é o **timemap**, que dá instante → identificadores
    de elemento, e `getMIDIValuesForElement`, que dá identificador → altura
    MIDI. É por aí que o cursor sabe o que destacar.
97. O SVG que o Verovio devolve é **interpretado e desenhado nativamente**, sem
    `WKWebView`. Nada de JavaScript no caminho do desenho.

> **Medido, não suposto.** Um exercício gerado de oito notas leva **9,7 ms** do
> MusicXML ao SVG; o Bach inteiro carrega em 64 ms e desenha uma página em 36.
> A objeção de latência que sustentava a pauta própria não sobreviveu à medição.

98. Na partitura gravada valem as **mesmas regras de interação**: o cursor marca
    o que tocar agora, acerto avança, erro recua uma posição.
99. A nota atual é destacada **pelo identificador que o gravador deu a ela**, e
    a página rola sozinha para mantê-la visível.
100. Uma peça de várias páginas mostra **todas**, empilhadas, e não só a
     primeira.
101. A rolagem acompanha o **sistema**, nunca a nota. Seguir a nota faz a página
     subir e descer a cada troca de mão — a esquerda está no pé do sistema e a
     direita no topo — e o que se lê fica pulando.
102. Enquanto o cursor está **dentro do sistema visível**, a página não se mexe.
103. A tela mostra **sempre pelo menos dois sistemas**, reduzindo a escala se
     preciso. Com um só não existe ler adiante: vira-se a linha e descobre-se.
104. O sistema que está sendo tocado fica **no alto**, para que todo o resto da
     tela seja música que ainda vem.

## Estudar, não executar

Tocar a peça do início ao fim é **performance**. Estudo é trabalho cirúrgico em
dois a quatro compassos, uma mão de cada vez, devagar, repetindo. O app precisa
servir ao segundo e permitir o primeiro, e não o contrário.

105. Um **trecho** é escolhido como se seleciona texto no iOS: **segurar** num
     compasso marca aquele compasso **sob o dedo, sem precisar soltar** — e
     continuar arrastando estende a seleção até onde o dedo for. Soltar
     mantém, com **alças nas duas pontas** para ajustar. A peça inteira
     continua na tela enquanto se escolhe.
106. Um trecho é sempre **contíguo**. Do 1 ao 7 vai tudo que há entre eles —
     não se estuda o 1 e o 7 soltos, porque o que se treina é a passagem de um
     ao outro.
107. Ajustar é **arrastar uma alça** — com um tique háptico a cada compasso —
     ou tocar num compasso de fora para estender a seleção até ele. Tocar
     **fora da pauta desfaz a seleção**, como tocar fora do texto. Nenhum
     gesto de ajuste confirma nada: ajustar e confirmar são atos diferentes.
108. A confirmação é o botão **Estudar**, flutuando junto à seleção como o
     menu de edição do iOS flutua junto ao texto. É o único caminho para o
     modo estudo — nenhum toque na pauta confirma nada por acidente.
109. O modo estudo acontece **na própria página**: os compassos escolhidos
     ficam como estão e todo o resto da partitura **esmaece**. Mesma página,
     mesmo scroll, nada salta nem muda de forma — o esmaecido é a lupa.
110. No modo estudo, pode-se trabalhar **uma mão só**. A mão em descanso
     também esmaece, dentro do trecho — esmaecer é a única linguagem para
     "isto não está em jogo agora", seja compasso, seja mão.
111. Um trecho em estudo **repete sozinho** ao terminar, para que a repetição
     não custe um gesto a cada volta. A **peça inteira não repete**: terminar
     a peça é terminá-la — é o que deixa uma lição avançar.
112. Fora do modo de seleção, tocar num compasso apenas escolhe **de onde
     ouvir**. Enquanto há seleção ou estudo, o botão de sair da peça some:
     sair do trecho e sair da peça são gestos diferentes.
113. Sempre há um caminho de volta para a **peça inteira**, num gesto — e a
     volta é **imediata e no lugar**: a página nunca foi embora, só o
     esmaecido sai de cena.
114. O preview toca **o que está em estudo** — aqueles compassos, aquela mão.
115. A **pinça** aproxima e afasta a partitura, e a página **reflui**: mais
     perto, menos compassos por linha; mais longe, mais — como regravar, não
     como esticar uma foto.
116. A tinta da página é **desenhada uma vez** e reaproveitada; por cima dela
     só se redesenha o que muda — destaques, seleção, alças. Uma peça longa
     não pode custar a tela inteira a cada tecla.
117. **Gravar nunca congela a tela.** A gravação acontece fora dela; enquanto
     dura, a tela diz o que está fazendo — abrir uma peça mostra progresso, e
     regravar (zoom, estudo) mantém a página antiga à vista com um aviso
     discreto. Um app parado sem explicação é um app quebrado, ainda que por
     dois segundos.
118. As **transições entre telas são animadas** e direcionais: entrar numa
     peça empurra a lista para trás; sair a traz de volta. A animação é o que
     diz de onde se veio e para onde se vai.

## Três lugares

119. O app tem **três lugares**, na ordem em que se vive neles: **Tocar** (o
     repertório), **Praticar** (treino contínuo, leitura contínua e as
     atividades repetíveis da trilha, como cartões de um mesmo hub) e
     **Trilha** (o curso). Lugares são lugares e modos são modos — os modos de
     praticar moram dentro de Praticar, não na navegação.
120. O app **abre em Tocar**. Tocar música é o motivo de estudar piano; abrir
     no curso era abrir no meio.
121. Com o app aberto, **a tela não dorme**. O sistema só conta toques no
     vidro como atividade, e quem pratica toca no piano — o iPad apagava no
     meio do exercício. Em segundo plano, o descanso volta ao normal.

> **Quem desenha o quê.** Partitura de verdade — peças, estudo, preview — é o
> **Verovio** (regras 94–97), com o SVG interpretado e desenhado nativamente.
> A pauta própria sobrevive só nos **prompts de exercício** (treino, leitura
> contínua, passos de lição): eles trocam de conteúdo a cada acerto e precisam
> de desenho imediato, e a fonte é a mesma Bravura, então a cara das notas não
> muda. A decisão inicial de manter a pauta própria para tudo caiu diante da
> medição de latência registrada acima.

## Interface

- **Notação musical correta e legível**, com tipografia musical de verdade
  (padrão SMuFL, fonte Bravura — a mesma família usada por editores
  profissionais). A pauta é o objeto central da tela e precisa ser fiel.
- **Feedback visual imediato e inequívoco**, com estados distinguíveis à
  primeira vista: pendente, atual, correto, erro.
- **Visual sóbrio e adulto.** A referência ao Duolingo Music é estritamente de
  mecânica de exercício. A linguagem visual dele é infantilizada e não serve
  como referência estética aqui.
- Tela amigável e fluida: o retorno acompanha o ritmo de quem toca, sem travar a
  sequência com diálogos, animações longas ou confirmações.

## Escopo inicial

O foco é fundamento, para quem está construindo a leitura do zero. Duas frentes
que avançam juntas:

**Leitura — ligar a pauta ao teclado**

- Nota única em clave de sol
- Nota única em clave de fá
- Pauta dupla (as duas claves ao mesmo tempo)
- Progressão de uma mão para duas mãos
- Aumento gradual do número de notas simultâneas (intervalos, depois acordes)

**Teclado — posição e navegação**

- Posição da mão e referência de dedilhado
- Navegação entre regiões do teclado (deslocamento sem procurar visualmente)
- Reconhecimento de onde cada nota lida efetivamente cai sob os dedos

A meta é fluência: ler uma nota e tocá-la sem etapa consciente de tradução.

## Configurabilidade

Não é uma sequência fixa de lições. Os exercícios são gerados a partir de
parâmetros, para permitir insistir exatamente no que está difícil:

| Parâmetro | Exemplos |
|---|---|
| **Clave** | sol, fá, ou ambas |
| **Região** | faixa de notas; começar em torno do dó central e expandir |
| **Dificuldade** | número de notas simultâneas, tempo de resposta, com ou sem acidentes |
| **Tema** | conjunto de notas específico — linhas suplementares, uma tonalidade, um trecho da pauta |
| **Mãos** | direita, esquerda, ou as duas |

A ideia é que qualquer ponto fraco vire um exercício configurável, em vez de
depender de a lição certa aparecer.

## Plataforma e conexão

- **iPad** (USB-C), conectado ao piano por cabo USB-C → USB-B na porta
  `USB TO HOST` do instrumento. Sem adaptador, hub ou fonte extra.
- O piano é **USB MIDI class-compliant**: o iPadOS carrega o driver de classe
  padrão, sem instalação de nada.
- Entrada via **Core MIDI**, a mesma API no iPadOS e no macOS — o que permite
  desenvolver e testar a lógica de MIDI no desktop antes de empacotar.

Dados disponíveis para avaliação, já verificados no hardware alvo: nota tocada,
momento exato (precisão de milissegundos), intensidade do toque (*velocity*),
duração, notas simultâneas e pedal de sustain.

Isso deixa em aberto, para o futuro, avaliar não só o acerto da nota, mas também
regularidade rítmica e uniformidade de dinâmica.

### Alvo de hardware único

O app é construído para **uma única configuração conhecida** de instrumento e de
iPad. Não há — e não deve ser adicionada — detecção de modelo, validação de
compatibilidade ou caminho alternativo para outros equipamentos. Onde essa
decisão simplifica o código, ela deve simplificar de fato.

## Desenvolvimento

Convenções de código, ferramental e fluxo de trabalho estão em
[docs/CONVENTIONS.md](docs/CONVENTIONS.md).

Resumo: código e identificadores em inglês, Google Swift Style Guide aplicado via
`swift-format`, e desenvolvimento guiado por especificação e por testes — o teste
vem antes da implementação, sempre.

### Ferramenta de diagnóstico

`tools/midimon.swift` — monitor de MIDI de entrada. Mostra em tempo real tudo que
o instrumento envia; use para separar "o instrumento não está enviando" de "o app
não está lendo".

```
swift tools/midimon.swift 60
```

O Simulator do iOS **não** expõe MIDI de forma confiável. Todo teste de teclado
precisa de iPad físico.

## Fora de escopo por enquanto

O app pode crescer bastante, mas nada abaixo está planejado para as primeiras
versões — está registrado só para não ser descartado por acidente no desenho:

- Repertório e acompanhamento de músicas completas
- Avaliação de ritmo e dinâmica como objetivo próprio
- Treino de ouvido e teoria harmônica
- Métricas de progresso ao longo do tempo, histórico e revisão espaçada

A prioridade é fazer o ciclo básico — ler, tocar, receber retorno — funcionar
bem.

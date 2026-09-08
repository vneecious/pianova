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

15. **A clave de fá entra na primeira lição**, junto com a de sol. O curso
    nunca ensina uma clave inteira antes de apresentar a outra.

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

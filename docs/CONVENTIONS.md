# Convenções de desenvolvimento

Este documento define como o código é escrito e verificado. A especificação do
produto está no [README](../README.md).

## Idioma

**Todo o código é em inglês** — nomes de tipos, variáveis, funções, arquivos,
módulos, casos de enum e comentários no código.

A documentação do repositório (README, este arquivo, notas de projeto) é em
português. A separação é intencional: código é artefato técnico e segue a
convenção da linguagem; documentação é para leitura humana.

Nomes musicais em inglês seguem a nomenclatura por letras, não solfejo:
`Pitch.c4`, `Clef.treble`, `Clef.bass` — nunca `do`, `claveDeSol`.

## Estilo

Adotamos o [**Google Swift Style
Guide**](https://google.github.io/swift/), aplicado pelo `swift-format`.

A escolha não é arbitrária: o `swift-format` é o formatador oficial da Apple,
vem embutido no toolchain do Xcode (versão 6.3.0 aqui, sem nada a instalar) e
implementa exatamente esse guia. Padrão escrito e ferramenta não divergem.

Configuração em [`.swift-format`](../.swift-format). Pontos principais:

- Indentação de **2 espaços**, linha de até **100 colunas** (o guia do Google)
- `NeverForceUnwrap`, `NeverUseForceTry`, `NeverUseImplicitlyUnwrappedOptionals`
  ativos — sem `!` para desembrulhar nem `try!`
- `AllPublicDeclarationsHaveDocumentation` — API pública documentada
- `OrderedImports`, `UseEarlyExits`, `DoNotUseSemicolons`

### Comandos

```sh
make format   # formata no lugar
make lint     # linter, falha em qualquer violação (--strict)
make test     # roda os testes
make check    # lint + test, o portão antes de commitar
```

O linter é `swift-format lint --strict`: qualquer violação é erro, não aviso.

## Desenvolvimento guiado por especificação (SDD)

Toda funcionalidade nasce como **regra escrita** antes de virar código.

As regras de comportamento vivem no README, numeradas. Exemplo: as regras de
avanço do cursor na seção *Modelo de interação* estão numeradas de 1 a 6.

O vínculo é explícito nos dois sentidos:

- Nenhuma regra existe sem pelo menos um teste que a exercite.
- Todo teste referencia a regra que valida, no nome ou num comentário.

```swift
/// README › Modelo de interação, regra 5:
/// erro no primeiro item mantém o cursor nele — não existe posição anterior.
@Test func cursorStaysAtStartWhenFirstItemIsWrong() { ... }
```

Mudou o comportamento? A regra no README muda **primeiro**. O README é a fonte
da verdade, não a documentação do que o código acabou virando.

## Desenvolvimento guiado por testes (TDD)

Framework: **swift-testing** (`import Testing`, `@Test`, `#expect`) — o padrão
moderno do Swift 6, presente no toolchain. Não usamos XCTest em código novo.

O ciclo, sem atalho:

1. **Vermelho** — escrever o teste que falha. Rodar e *ver* falhar. Um teste que
   nunca falhou não provou nada.
2. **Verde** — a implementação mínima que faz passar.
3. **Refatorar** — limpar, com os testes segurando.

Regra dura: **não se escreve implementação sem um teste falhando que a exija.**

Ao relatar resultado de teste, colar a saída real. "Os testes passam" sem a
saída não conta.

## Arquitetura para testabilidade

A decisão que torna o TDD viável aqui: **a lógica de domínio não conhece
SwiftUI nem Core MIDI**.

```
Packages/PianovaCore/
  Sources/
    ScoreModel/       # pitch, clave, posição na pauta. Sem dependências.
    ExerciseEngine/   # sequência, cursor, regras de avanço e recuo.
    MIDIInput/        # adaptador Core MIDI, atrás de um protocolo. (a fazer)
  Tests/
    ScoreModelTests/
    ExerciseEngineTests/
App/                  # alvo iPad, SwiftUI. Fino: apresenta e encaminha eventos.
```

- `ScoreModel` e `ExerciseEngine` são Swift puro. Seus testes rodam com `swift
  test` no macOS, em segundos, sem simulador e sem hardware.
- A entrada MIDI fica atrás de um protocolo. Os testes injetam eventos
  sintéticos: dá para testar "tocou dó, depois ré errado, cursor recuou" sem
  encostar no piano.
- `App/` não contém regra de negócio. Se uma regra precisa de teste e está na
  camada de UI, ela está no lugar errado.

O piano físico valida a **integração** — nunca a lógica.

## Renderização de notação

A partitura é desenhada em SwiftUI usando a fonte **Bravura**, do padrão
[SMuFL](https://w3c.github.io/smufl/) (*Standard Music Font Layout*).

Por que essa via, e não desenho vetorial próprio nem biblioteca de terceiros:

- SMuFL é o padrão que editores profissionais adotam (MuseScore, Dorico). Os
  glifos saem tipograficamente corretos, não "quase certos".
- Sendo fonte, escala sem perda em qualquer densidade de tela do iPad.
- O **posicionamento** fica sob nosso controle total — o glifo vem pronto, mas
  onde ele cai na pauta é código nosso. Isso é o que permite animar o cursor e
  os estados de acerto/erro do jeito que o exercício precisa, sem lutar contra
  uma biblioteca que impõe o próprio layout.
- Licença SIL OFL, sem restrição de uso.

Consequências práticas:

- A fonte é *vendorizada* no repositório (não é dependência de rede) e
  registrada no bundle do app.
- O mapeamento de nota → posição vertical na pauta é lógica de domínio pura,
  mora em `ScoreModel` e é testável sem renderizar nada. **A renderização não
  decide onde a nota fica; ela recebe a posição já calculada e testada.**

## Alvo de hardware único

O app tem um único instrumento e um único iPad como alvo. Não escrever detecção
de modelo, validação de compatibilidade, nem caminho alternativo para outro
hardware. Onde isso simplifica, deve simplificar de verdade — menos código, não
mais abstração.

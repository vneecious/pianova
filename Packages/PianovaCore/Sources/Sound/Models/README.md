# Basic Pitch — o ouvido neural (regra 153)

`nmp.mlpackage` é o modelo de transcrição automática do **Basic Pitch**
(Spotify AB), sob **Apache License 2.0** — ver `LICENSE-basic-pitch.txt`.
Origem: <https://github.com/spotify/basic-pitch>, `basic_pitch/saved_models/icassp_2022/`.

Interface (lida do próprio modelo, não suposta):

| | forma | o que é |
|---|---|---|
| entrada `input_2` | 1 × 43844 × 1 | áudio mono a **22 050 Hz** (~1,99 s) |
| saída `Identity` | 1 × 172 × 264 | contorno de altura, 3 faixas por semitom |
| saída `Identity_1` | 1 × 172 × 88 | **nota soando** por quadro |
| saída `Identity_2` | 1 × 172 × 88 | **ataque** por quadro |

172 quadros por janela ⇒ um quadro a cada 256 amostras (~11,6 ms). A coluna
`k` é o MIDI `21 + k` — a primeira tecla do piano. Os passos (`strides`) das
matrizes são lidos em tempo de execução: a largura da linha não é 88, e
assumi-la foi o que fez a primeira tentativa ler lixo em escada.

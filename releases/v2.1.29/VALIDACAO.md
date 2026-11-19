# Validação — BRUMCLASSICS OFICIAL 2.1.29

## Checks automatizados e compilação executados

- `npm run check`, `npm run check:controllers` e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `972` testes (`971` aprovados, `0` falhas, `1` opcional ignorado por `BRUM_REAL_CORE_PATH` ausente).
- `npm run build:official`: compilação de `brum-core-pc.exe` (`murb_video_tests` e `murb_input_tests` aprovados), `brum-ios-bridge.exe` (`6` testes Rust + `386` licenças verificados), geração de assets de marca e empacotamento portátil `x64`.
- `verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.29`: `197` arquivos conferidos.
- `dist\win-unpacked\resources\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`.
- `dist\win-unpacked\resources\brum-core-pc.exe --probe-controllers`: JSON válido retornado.

## Pendências físicas

- A validação interativa presencial com iPhone/Android pareados em rede Wi-Fi real abrindo um jogo via botão `GAMEPAD` e testando a entrada no Windows permanece pendente de execução física no aparelho do usuário.

## Artefato oficial gerado

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411410594` bytes
- **SHA-256:** `093D9AF7C3C828A89A388632CBDDBC2D23D98AD1879953DEBE592599086F850B`

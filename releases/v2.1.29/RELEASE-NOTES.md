# BRUMCLASSICS OFICIAL 2.1.29

Adiciona o fluxo completo de lançamento remoto em **Modo GAMEPAD** a partir do celular (**BRUMCLASSICS MÓVEL** iOS `0.17.0` / Android `0.27.0`), abrindo o jogo no computador enquanto o joystick virtual M.U.R.B abre conectado automaticamente no celular.

## Principais novidades

- **Comando autenticado `gamepad_launch` (`src/mobile-bridge.js` & `src/main.js`):** localiza o jogo por `gameId`, `filename` ou título normalizado, abre ou traz o foco do título no computador e devolve imediatamente o payload `remoteGamepad` (`murb://`, `host`, `port`, `token`, `system`, `p2QrUri`).
- **Ponte Desktop Gamepad (`--desktop-gamepad 1`):** adicionado suporte em `native/brum-core-pc/main.cpp` e `src/brum-core-pc-service.js` (`launchDesktopGamepad`) para jogos modernos de PC, além de captura de `BRUM_REMOTE_SERVER`, `BRUM_REMOTE_QR` e `BRUM_REMOTE_QR_P2` e encerramento sincronizado em `quitActiveSession`.
- **Co-op Híbrido LAN (`src/brum-input-core.js`):** `prepareBackendLaunch` aceita overrides de sessão móvel (`mobileGamepadEnabled`, `players`, `hybridMode`: `pc1-mobile2`, `mobile1-pc2`, `dual-mobile`) para jogar em rede local com controles no PC e celulares.

## Verificação desta entrega

- `npm run check`, `npm run check:controllers` e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `972` testes listados (`971` aprovados, `0` falhas, `1` opcional ignorado quando `BRUM_REAL_CORE_PATH` não está definido), incluindo novos testes de `gamepad_launch`, overrides do `brum-input-core` e `launchDesktopGamepad` contra `brum-core-pc.exe`.
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes Rust + `386` licenças verificados) e pacote portátil Windows gerado.
- `verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.29`: `197` arquivos conferidos.
- `brum-core-pc.exe --self-test` (`BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`) e `--probe-controllers` aprovados.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411410594` bytes
- **SHA-256:** `093d9af7c3c828a89a388632cbddbc2d23d98ad1879953debe592599086f850b`

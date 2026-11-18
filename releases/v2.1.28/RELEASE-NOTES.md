# BRUMCLASSICS OFICIAL 2.1.28

Correção emergencial para eliminar o travamento da tela de intro após 6 segundos e garantir a abertura imediata dos jogos (especialmente no **Wii U / Cemu**).

## Principais correções

- **Fim do bloqueio de 8 segundos no lançamento de controles:** `controllerService.prepareLaunch` (`src/controller-service.js`) passa a utilizar sonda nativa imediata (`--probe-controllers`, ~160 ms) combinada a `detectHardwareQuick()` com limite de 250 ms e cache de 60 s aquecido em segundo plano na abertura (`main.js`), eliminando a espera de > 8 s do `Get-PnpDevice` PowerShell que travava o lançamento depois do término da intro.
- **Detecção real de abertura do Cemu (Wii U) em tela cheia:** em `native/brum-core-pc/main.cpp` (`runCemuCommercialWiiU`), como o Cemu 2.6 iniciado com `-f` mantém o título como `Cemu 2.6 - loading...` sem exibir `FPS:` ou `TitleId:`, o host passa a monitorar também o `portable/log.txt` desta execução (`Loaded module '` / `IOSU_ACT:`), remove `WS_EX_LAYERED` imediatamente no evento `onWindowReady` (~8,2 s no *Mario Kart 8* contra ~27–37 s na 2.1.27), libera o `FOCUS` incondicionalmente para garantir visibilidade da janela e reduz o fallback de 25 s para 12 s.
- **Timeout e saída segura da tela de intro:** `brum-core-pc-service.js` amplia o tempo-limite de confirmação inicial de sessão para 25 s no Cemu (evitando abortar o processo sob carga fria) e guarda buffer de 8 KiB de saída; `main.js` reduz o timeout de segurança pós-intro de 45 s para 20 s, garante fechamento em erro de lançamento e `launch-briefing.js` libera cancelamento via `Escape` após 1,5 s de espera.

## Verificação desta entrega

- `npm run check`, `npm run check:controllers` (`34/34` testes aprovados) e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `971` testes executados (`970` aprovados, `0` falhas, `1` opcional ignorado).
- Teste de bancada ao vivo em *Mario Kart 8* (`cemu-wiiu` no `build/brum-core-pc/brum-core-pc.exe`): `ctrlSvc.prepareLaunch` em `~367 ms`, `onStart` em `~4,7 s` e `onWindowReady` em `~8,2 s` com encerramento limpo (`EXIT 0`).
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes Rust + `386` licenças verificados) e pacote portátil Windows gerado.
- `verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.28`: `197` arquivos conferidos.
- `brum-core-pc.exe --self-test` (`BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`) e `--probe-controllers` aprovados.
- **Observação de bancada:** não havia controle físico pareado durante o empacotamento final (`XInput[0..3]` desconectados no `--probe-controllers`); recomenda-se validar em partida presencial no GUI portátil com seu controle conectado.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411395908` bytes
- **SHA-256:** `7b1053d0893c3083b5c5b97c10eac261a24b0e0952ef3aba1d58172dcfbcfba1`

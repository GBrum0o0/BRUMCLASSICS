# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.28

## Causas raiz identificadas na reprodução ao vivo da 2.1.27

1. **Bloqueio de ~8,2 s antes de abrir o emulador:** `controllerService.prepareLaunch` (`src/controller-service.js`) executava `Get-PnpDevice` com loop por dispositivo via PowerShell (~6,2–8,2 s) a cada abertura de jogo após `openLaunchBriefing` já ter aberto a intro de 6 s. Quando a intro terminava aos 6 s, o jogo ainda nem havia sido iniciado.
2. **Janela do Cemu oculta (`WS_EX_LAYERED` / `LWA_ALPHA = 0`) por 25+ s em tela cheia:** sondagem direta de `Cemu.exe -f` mostrou que o Cemu 2.6 em tela cheia mantém o título em `Cemu 2.6 - loading...` sem inserir `FPS:` ou `TitleId:`, fazendo `atomicGameMarkerSeen` e `atomicTitleIdSeen` permanecerem falsos até o fallback de 25 s mesmo com *Mario Kart 8* já em execução (`Loaded module`). Além disso, `FOCUS` exigia `atomicWindowRevealed || atomicGameMarkerSeen`, mantendo o Cemu transparente se outro timer fechasse a intro antes.
3. **Tela de intro presa sem saída após 6 s e timeout curto no host:** ao concluir o vídeo de 6 s, `launch-briefing.js` ocultava `#intro-skip` e bloqueava novas teclas `Escape`, mantendo `alwaysOnTop: 'screen-saver'` por até 45 s; simultaneamente, `brum-core-pc-service.js` usava timeout de 10 s para `BRUM_CORE_READY`, podendo encerrar o host prematuramente sob carga de disco/scan.

## Resumo das alterações

- **`src/controller-service.js` & `src/main.js`:** `hardwareCache` de 60 s com aquecimento em `scheduleBackgroundStartup`, `detectHardwareQuick()` limitado a 250 ms em `prepareLaunch` usando sonda nativa `--probe-controllers` (~157 ms) em paralelo, timeout `onWait` reduzido para 20 s, limpeza de apresentação prévia sobreposta e fechamento explícito da apresentação ao falhar `launchStoredLibraryGame`.
- **`native/brum-core-pc/main.cpp`:** leitura de progresso real em `portable/log.txt` (`Loaded module '` / `IOSU_ACT:` após `------- Run title -------`), liberação incondicional de `WS_EX_LAYERED` e foco no comando `FOCUS` e redução do fallback de revelação de 25 s para 12 s (`8 s` com `TitleId`).
- **`src/brum-core-pc-service.js` & `src/launch-briefing.js`:** buffer de stdout ampliado para 8 KiB, timeout inicial ampliado (`25 s` no Cemu / `15 s` demais sistemas), permissão de `Escape` cancelar via `window.launchBriefing.cancel` após 1,5 s de espera pós-intro (`tests/launch-briefing.test.js` atualizado para 5/5 testes) e versão atualizada para `2.1.28`.

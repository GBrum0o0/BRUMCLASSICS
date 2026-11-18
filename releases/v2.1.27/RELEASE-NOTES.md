# BRUMCLASSICS OFICIAL 2.1.27

Pacote de estabilização do **Brum Input Core**, **Wii U (Cemu)**, biblioteca **CLASSICS**, transição de abertura em tela cheia e motor nativo **RetroAchievements**.

## Principais novidades e correções

- **Gerenciador visual de controles simplificado (`Brum Input Core`):** a janela aberta pelo ícone de controle exibe apenas os cartões dos dispositivos conectados (controle físico no PC e celular pareado como `CONECTADO`) e dois botões principais (**`TESTAR CONTROLE`** e **`CONFIGURAÇÃO GLOBAL`**), mantendo o testador em tempo real e as opções avançadas ocultos até serem selecionados.
- **Isolamento do Gamepad Mobile no P2:** corrigida a leitura de estado em `createBrumInputCore.getMobileStatus` e na ponte móvel para que o celular conectado como companheiro não ocupe `P2` nem force `--remote-gamepad 1` quando o modo Gamepad Mobile está desativado.
- **Wii U (Cemu) — entrega de controles físicos em jogo:** corrigido o encaminhamento direto no host `brum-core-pc.exe` (`runCemuCommercialWiiU`), removendo os bloqueios de `p1BoundSlotMask` e `p1NativeXInputLive` quando `p1KeyboardEnabled` está ativo para que entradas XInput/DirectInput reais cheguem ao jogo em todos os títulos de Wii U.
- **CLASSICS — eliminação de falso "Arquivos ausentes" e varredura inteligente:**
  - `integrity-service.js`, `main.js` (`normalizeGame` / `runIntegrityAudit`) e `retro-service.js` passam a validar pela existência real da ROM em disco em vez de exigir `retroarch.exe` legado, limpando falsos estados `incomplete` em jogos do Wii (`.nkit.iso`) e de pastas adicionadas pelo usuário.
  - Identificação de `.nkit.iso` e inspeção do conteúdo interno de arquivos `.zip`/`.7z` (`classic-content-identity.js` e `retro-service.js`) para classificar corretamente `3DS`, `Wii`, `Wii U`, `GameCube`, `Saturn`, `PS1`, `PSP` e `Mega Drive`, deduplicar `.zip`/`.7z` quando a ROM extraída já existe, remover o sufixo `nkit` dos títulos e localizar `dolphin-emu/Sys` populado em Wii/GameCube.
- **Intro sincronizada até a abertura em tela cheia:** `launchBriefingWindow` mantém o logotipo em exibição (com proteção de timeout de 45 s) e fecha apenas quando `brum-core-pc.exe` emite `BRUM_CORE_WINDOW_READY` após a janela do jogo estar visível e focada em tela cheia (como após compilação de shaders no Cemu).
- **RetroAchievements nativo no CLASSICS:** base nativa `murb_retroachievements.hpp` integrada ao `brum-core-pc.exe`, decodificação de eventos `BRUM_RA` e identificador oficial `consoleId: 62` para Nintendo 3DS.

## Verificação desta entrega

- `npm run check`, `npm run check:controllers` (`33/33` testes aprovados) e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `970` testes executados (`969` aprovados, `0` falhas, `1` opcional ignorado).
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes e `386` licenças verificados) e pacote portátil Windows gerado.
- `verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.27`: `197` arquivos conferidos.
- `brum-core-pc.exe --self-test` (`BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`) e `--probe-controllers` aprovados.
- **Observação de bancada:** não havia controle físico XInput pareado/ligado no ambiente durante a execução da esteira (`XInput[0..3]` desconectados no `--probe-controllers`), de modo que a leitura presencial de botões em partida real segue para validação do usuário.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411391842` bytes
- **SHA-256:** `21b9dc1210ac791cd8008f826afdb1362be4bccad1a82f8a96f7b8e3b9394453`

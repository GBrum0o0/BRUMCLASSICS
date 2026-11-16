# BRUMCLASSICS OFICIAL 2.1.24

Correção emergencial no host **BRUM Core PC** (`brum-core-pc.exe`) para restaurar o funcionamento completo de controles conectados diretamente ao computador no **Nintendo Wii U (Cemu)**.

## O que foi corrigido nesta versão

- **Fim do travamento de `VK_UP` (`buttons=4`) com controles XInput/DirectInput no Wii U:** `pollUniversalGamepadForCemu` estava sendo chamado com `allowXInput = false`, forçando a leitura do espelho legado `winmm` (`joyGetPosEx`) sem validar `JOYCAPS_HASPOV`, o que convertia `dwPOV == 0` em tecla Cima pressionada continuamente no Cemu.
- **Prioridade real para XInput nativo + fallback inteligente:** quando o slot XInput principal do GamePad está conectado, o Cemu recebe o controle diretamente em modo nativo sem injeção concorrente de teclado nem leitura `winmm`. Se o controle conectar após a abertura em outro slot XInput (`1..3`) ou for exclusivamente DirectInput/HID, o fallback encaminha os comandos de forma segura apenas quando há entrada real e POV válido.
- **Foco e eventos em segundo plano:** `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1` e recuperação segura de foco após o fechamento da tela de preparação garantem que a janela do Cemu receba os comandos do jogador assim que o jogo inicia pelo Launcher.

## Verificação desta entrega

- `build-brum-core-pc.ps1` + `brum-core-pc.exe --self-test` (`tripleEscape=1`, `inputMapping=1`, `cemuInput=1`) aprovados.
- Smoke test ao vivo do Wii U (`Cemu` + *Mario Kart 8*, 120 quadros): `BRUM_WIIU_CONTROLLERS players=1 topology=3` com `buttons=0` em repouso (sem `VK_UP` preso) e saída limpa (`código 0`).
- `npm run check`, `npm run check:updates` e `npm test`: `954` aprovados, `0` falhas e `1` opcional ignorado (`brum-core-pc-real-core.test.js`, dependente de `BRUM_REAL_CORE_PATH`).
- Empacotamento Windows (`npm run build:official`), auditoria ASAR (`scripts/verify-release-source.js`, `official`, `2.1.24`, `196` arquivos) e `brum-core-pc.exe` empacotado validados.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411241299` bytes
- **SHA-256:** `a43d1e01ac69cc20f6cfc6f379c219aaff4a803380dd28a6d5c0f817c1d965ca`

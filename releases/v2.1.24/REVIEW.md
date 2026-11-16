# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.24

## Escopo da correção

- **Causa raiz identificada no host Wii U (`native/brum-core-pc/main.cpp`):**
  1. `pollUniversalGamepadForCemu` possuía padrão `allowXInput = false` e era invocado sem sobrescrever esse sinalizador em `runCemuCommercialWiiU`, ignorando controles XInput conectados e caindo no backend legado `winmm` (`joyGetPosEx`).
  2. `decodeJoyInfo` lia `ji.dwPOV` sem consultar `joyGetDevCapsW` (`JOYCAPS_HASPOV`), interpretando `dwPOV == 0` em drivers sem hat switch/repouso como D-Pad Cima (`1u << 2 = 4`) e mantendo `VK_UP` pressionado continuamente via `SendInput`/`PostMessageW` contra `<api>Keyboard</api>` no `controller0.xml`.
  3. Ao abrir o Wii U pelo Launcher (tela de introdução `alwaysOnTop` + processo `brum-core-pc.exe` com `windowsHide: true`), a janela do Cemu podia perder o foco inicial após o encerramento da introdução.
- **Alterações aplicadas (`8c9416c`):**
  - Extraídos helpers puros `decodeCemuXInputState` e `decodeCemuJoyInfo` (validando `JOYCAPS_HASPOV` e evitando retorno ativo em repouso).
  - Atualizado `configureCemuControllers` para expor o slot XInput nativo vinculado ao P1 (`outP1XInputSlot`), a máscara de slots extras (`outOtherPlayersXInputMask`) e estado do perfil Keyboard (`outP1KeyboardEnabled`).
  - Atualizado `runCemuCommercialWiiU` para: (a) silenciar síntese de teclado e não consultar `joyGetPosEx` enquanto o slot XInput nativo de P1 estiver ativo no Cemu; (b) habilitar fallback XInput em slots não atribuídos (`1..3`) ou `joyGetPosEx` validado caso o controle nativo esteja ausente; (c) definir `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`, `AllowSetForegroundWindow` e recuperação controlada de foco apenas diante de janelas transitórias do Launcher nos primeiros segundos após exibir a janela do Cemu.
  - Ampliado `--self-test` (`cemuInput=1`) e `tests/brum-core-pc-host.test.js` com casos de regressão para o decodificador `winmm`/XInput e XML do Cemu.

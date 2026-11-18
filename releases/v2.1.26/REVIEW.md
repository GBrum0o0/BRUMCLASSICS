# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.26

## Causa raiz do bloqueio anterior (Launcher → Wii U / Cemu)

1. `launchStoredLibraryGame` (`src/main.js`) e `launchPrepared` (`src/brum-core-pc-service.js`) não consultavam o gerenciador central de controles antes de iniciar `brum-core-pc.exe`, fixando `--remote-gamepad 0` sem encaminhar zona morta, inversões `A/B` e `X/Y`, vibração ou mapeamento de slots `P1–P4`.
2. `recognizeConnectedControllers` (`src/renderer.js`) retornava `[]` quando `navigator.getGamepads()` estava vazio, impedindo que receptores sem fio em standby ou dispositivos detectados via XInput/PnP aparecessem no Launcher com aviso real de estado.
3. No Cemu/Wii U (`native/brum-core-pc/main.cpp`), perfis `controller0.xml` precisavam manter `<type>Wii U GamePad</type>`, remover tags `<profile>` redirecionadas, vincular os slots XInput ativos do Jogador 1 com carga dinâmica (`XInput1_4.dll -> XInput1_3.dll -> XInput9_1_0.dll`) e recuperar foco após o fechamento da janela de abertura (`FOCUS`).

## Resumo das alterações

- **Core nativo (`native/brum-core-pc/`):** adicionados `GlobalInputProfile`, comando `--probe-controllers` (JSON XInput + DirectInput), flags `--input-deadzone`, `--input-swap-ab`, `--input-swap-xy`, `--input-rumble`, `--p1-slot..--p4-slot`, normalização idempotente de `controller0.xml` e comando stdin `FOCUS`.
- **Serviço de controles & Brum Input Core (`src/brum-input-core.js`, `src/controller-hardware.js`, `src/controller-model.js`, `src/controller-service.js`):** inventário PnP expandido (GameSir `3537:1040`/`3537:2106`, 8BitDo e receptores sem fio), sonda nativa integrada ao `prepareLaunch`, tradutor global de botões por console, prioridade de toque Mobile vs. Mouse PC e registro de capacidades dos adaptadores (`cemu`, `dolphin`, `libretro-murb`, `rpcs3`, `xemu`).
- **Launcher UI & IPC (`src/main.js`, `src/preload.js`, `src/brum-core-pc-service.js`, `src/index.html`, `src/styles.css`, `src/renderer.js`):** novo ícone e gerenciador visual `P1–P4` estilo Switch à esquerda de Configurações com testador em tempo real, troca global, perfis e roteamento automático ao iniciar jogos.

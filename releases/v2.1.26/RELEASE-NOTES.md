# BRUMCLASSICS OFICIAL 2.1.26

Integração completa do **Brum Input Core** como central universal de gerenciamento de controles do BRUMCLASSICS e estabilização do roteamento de entradas entre o Launcher, o host **BRUM Core PC** (`brum-core-pc.exe`) e o **Cemu (Nintendo Wii U)**.

## Principais novidades e correções

- **Gerenciador visual na tela inicial:** ícone de joystick **imediatamente à esquerda da engrenagem de Configurações** com visualização `P1–P4` (origem PC ou Celular LAN), inversão rápida `P1 ↔ P2`, teste em tempo real de botões e analógicos, alertas de standby/conflitos (`Steam`, `DS4Windows`, `reWASD`), preferências globais e perfis salvos/restaurados.
- **Configuração global e prioridade de toque:** ajustes globais de zona morta, troca `A ↔ B` e `X ↔ Y`, vibração e modo de toque em telas duplas (**DS / 3DS / Wii U** — usando o celular quando o Gamepad Mobile está ativo ou o mouse do PC quando desativado).
- **Detecção nativa XInput + PnP Windows:** nova sonda `--probe-controllers` em `brum-core-pc.exe` reconciliada com o inventário PnP do Windows (incluindo receptores sem fio GameSir `VID_3537&PID_2106` em standby e controles `3537:1040`), removendo o bloqueio em que a ausência de eventos no navegador ocultava controles físicos.
- **Roteamento end-to-end para Cemu (Wii U) e M.U.R.B Engine:** `launchStoredLibraryGame` e `brum-core-pc-service.js` passam a enviar automaticamente os parâmetros globais e slots `P1–P4` ao host nativo, mantendo `Wii U GamePad` no `controller0.xml` do P1, removendo redirecionamentos `<profile>` conflitantes e disparando recuperação de foco (`FOCUS`) ao concluir o briefing de abertura.
- **Arquitetura extensível de adaptadores:** registro explícito de capacidades para **Cemu**, **Dolphin**, **BRUM Core PC (Libretro)** e placeholders arquiteturais **RPCS3** / **xemu** (PS3 e Xbox continuam desativados na release oficial).

## Verificação desta entrega

- `npm run check`, `npm run check:controllers` (`33/33` testes aprovados) e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `964` testes executados (`963` aprovados, `0` falhas, `1` opcional ignorado).
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes e `386` licenças verificados) e pacote portátil Windows gerado.
- `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.26`: `197` arquivos verificados.
- `dist\win-unpacked\resources\brum-core-pc.exe --self-test` (`BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1`) e `--probe-controllers` aprovados.
- **Observação de bancada:** testes de botões em hardware físico e gameplay contínuo de 5 minutos com controle real permanecem **NÃO VERIFICADO** nesta publicação porque nenhum controle sem fio/USB estava pareado/ligado na sessão (`XInput[0..3]` desconectados no probe nativo).

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411343633` bytes
- **SHA-256:** `5cdaaf365179c3c134788336625cc5aab20fa2d1a0fe30896f429e36be82e6ba`

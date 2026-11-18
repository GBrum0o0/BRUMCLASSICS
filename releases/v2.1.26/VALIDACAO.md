# Validação — BRUMCLASSICS OFICIAL 2.1.26

## Checks automatizados e compilação executados após as alterações finais

- `npm run check`: sintaxe de todos os scripts e módulos verificada (`código 0`).
- `npm run check:controllers`: `33` testes aprovados (`0` falhas), incluindo `tests/brum-input-core.test.js` e reconciliação GameSir `3537:1040` / `3537:2106` com `webDevices` vazio em `tests/controller-hardware.test.js`.
- `npm run check:updates`: sintaxe dos serviços de atualização e notas verificada (`código 0`).
- `npm test`: `964` testes executados (`963` aprovados, `0` falhas, `1` opcional ignorado).
- `npm run build:official`: `murb_video_tests` e `murb_input_tests` aprovados, `brum_ios_bridge` (`6` testes Rust + `386` licenças) verificado e empacotamento Windows `portable --x64` concluído (`dist\BRUMCLASSICS OFICIAL.exe`).
- `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.26`: `197` arquivos conferidos.
- `dist\win-unpacked\resources\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1`.
- `dist\win-unpacked\resources\brum-core-pc.exe --probe-controllers`: retornou JSON válido para `xinput[0..3]` e `directInput[]` (`connected: false` na bancada sem controle pareado no momento).

## Pendências explicitamente NÃO VERIFICADAS nesta sessão

- **Leitura física de botões/analógicos e gameplay de 5 minutos em controle real (incluindo Wii U / Cemu, Gamepad Mobile conjunto e troca dinâmica em partida):** **NÃO VERIFICADO** — durante a execução da esteira, os slots `XInput[0..3]` retornaram desconectados (`connected: false`, receptor sem fio GameSir em modo standby), exigindo validação presencial do usuário com controle ligado/pareado.

## Artefato oficial gerado

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411343633` bytes
- **SHA-256:** `5CDAAF365179C3C134788336625CC5AAB20FA2D1A0FE30896F429E36BE82E6BA`

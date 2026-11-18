# Validação — BRUMCLASSICS OFICIAL 2.1.27

## Checks automatizados e compilação executados após as alterações finais

- `npm run check`: sintaxe de todos os scripts e módulos verificada (`código 0`).
- `npm run check:controllers`: `33` testes aprovados (`0` falhas), incluindo `tests/brum-input-core.test.js` (`8/8` aprovados), verificação da interface simplificada e isolamento `mobileGamepadEnabled=false`.
- `npm run check:updates`: sintaxe dos serviços de atualização e notas verificada (`código 0`).
- `npm test`: `970` testes executados (`969` aprovados, `0` falhas, `1` opcional ignorado).
- Varredura em diretório real de ROMs (`scanRetroDirectory` e normalização em `src/retro-service.js` / `src/classic-content-identity.js`): `125` jogos classificados em `17` plataformas (`wii: 8`, `wiiu: 5`, `3ds: 9`, `gamecube: 13`, `saturn: 1`, `ps1: 7`, `psp: 15`, `genesis: 11`, etc.) com `0` `incomplete`, `0` sufixos `nkit` nos títulos e deduplicação dos `7` `.zip` duplicados de 3DS.
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes Rust + `386` licenças verificados) e empacotamento Windows `portable --x64` concluído (`dist\BRUMCLASSICS OFICIAL.exe`).
- `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.27`: `197` arquivos conferidos.
- `dist\win-unpacked\resources\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`.
- `dist\win-unpacked\resources\brum-core-pc.exe --probe-controllers`: retornou JSON válido para `xinput[0..3]` e `directInput[]`.

## Pendências explicitamente NÃO VERIFICADAS nesta sessão

- **Gameplay presencial com controle físico pareado no Cemu (Wii U) e abertura gráfica GUI do `BRUMCLASSICS OFICIAL.exe` 2.1.27:** **NÃO VERIFICADO** — durante a execução da esteira automatizada, os slots `XInput[0..3]` retornaram desconectados (`connected: false` no `--probe-controllers`), exigindo teste presencial do usuário em jogo de Wii U, troca visual da intro até a tela cheia do emulador e verificação visual do gerenciador simplificado.

## Artefato oficial gerado

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411391842` bytes
- **SHA-256:** `21B9DC1210AC791CD8008F826AFDB1362BE4BCCAD1A82F8A96F7B8E3B9394453`

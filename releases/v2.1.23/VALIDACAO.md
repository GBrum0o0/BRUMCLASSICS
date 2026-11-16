# Validação — BRUMCLASSICS OFICIAL 2.1.23

## Escopo e política desta release

- Integração completa dos consoles suportados pela base híbrida da **M.U.R.B ENGINE** no **BRUMCLASSICS OFICIAL**, abrangendo **`33` sistemas integrados** (`gb`, `gbc`, `nes`, `sms`, `gg`, `genesis`, `snes`, `gba`, `pce`, `a2600`, `a7800`, `sg1000`, `neogeo`, `ngp`, `ws`, `lynx`, `msx`, `segacd`, `sega32x`, `ps1`, `n64`, `dreamcast`, `nds`, `psp`, `ps2`, `3ds`, `gamecube`, `saturn`, `3do`, `jaguar`, `wii`, `wiiu` e `arcade`).
- **PS3 e Xbox permanecem desativados e bloqueados** tanto nas políticas/descoberta do Launcher quanto no host nativo `brum-core-pc.exe`.
- Conforme autorização para esta publicação (`2.1.23`), a validação focou na integração de arquitetura, compilação nativa, verificação de empacotamento, isolamento de saves e execução completa das suítes automatizadas (sem bateria manual individual dos consoles nesta entrega).

## Verificações executadas após as alterações finais

- `npm run check` e `npm run check:updates`: aprovados (`código 0`).
- `npm run check:core-manager`: `8/8` aprovados (`tests/brum-core-pc-configuration.test.js` e `tests/brum-core-pc-service.test.js`).
- `npm run check:ios-bridge`: `69/69` aprovados (`tests/ios-bridge*.test.js`).
- `npm run check:on-brum`: `8/8` suítes aprovadas na base autoral `on-brum`, incluindo `478` testes nativos C++ sem falhas (`gameplayReady=false`).
- `npm run build:core-pc` + `brum-core-pc.exe --self-test` + `--describe 1` + testes nativos/captura/recuperação GBA (`tests/murb-pc-distribution.test.js`, `tests/murb-video-capture.test.js`, `tests/murb-gba-save-recovery.test.js`): `23/23` aprovados (`0` falhas).
- `npm test` (`node --test --test-concurrency=2 tests/*.test.js`): `954` testes, `953` aprovados, `0` falhas e `1` opcional ignorado (`tests/brum-core-pc-real-core.test.js`, condicionado à variável de ambiente `BRUM_REAL_CORE_PATH`).
- Execução isolada de `tests/brum-core-pc-real-core.test.js` apontando para um núcleo libretro GB local real: `1/1` aprovado (`0` falhas).
- Empacotamento Windows (`npm run build:official`), auditoria de origem ASAR (`scripts/verify-release-source.js`, `official`, `2.1.23`, `196` arquivos verificados) e verificação do binário empacotado `brum-core-pc.exe --self-test` / `--describe 1` concluídos com sucesso.

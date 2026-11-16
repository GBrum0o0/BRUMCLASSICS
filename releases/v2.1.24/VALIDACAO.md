# Validação — BRUMCLASSICS OFICIAL 2.1.24

## Escopo desta entrega

- Hotfix direcionado à restauração do controle físico conectado diretamente no computador no módulo **Nintendo Wii U (Cemu)** (`native/brum-core-pc/main.cpp`), mantendo todos os 33 consoles integrados na `2.1.23` (exceto PS3 e Xbox) e o isolamento dos saves/Cofre.

## Verificações executadas após as alterações finais (`8c9416c`)

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-brum-core-pc.ps1` + `build\brum-core-pc\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1` (`código 0`).
- `npm run check` e `npm run check:updates`: aprovados (`código 0`).
- `node --test tests/brum-core-pc-host.test.js tests/brum-core-pc-service.test.js tests/brum-core-pc-configuration.test.js tests/murb-runtime-policy.test.js tests/murb-pc-distribution.test.js tests/update-service.test.js`: `45/45` aprovados (`0` falhas).
- `npm test` (`node --test --test-concurrency=2 tests/*.test.js`): `955` testes, `954` aprovados, `0` falhas e `1` opcional ignorado (`tests/brum-core-pc-real-core.test.js`, condicionado à variável `BRUM_REAL_CORE_PATH`).
- Teste ao vivo no host nativo com **Cemu 2.6** local (*Mario Kart 8*, `120` quadros, `--remote-gamepad 0`): `BRUM_WIIU_CONTROLLERS players=1 topology=3` e `BRUM_CORE_TELEMETRY buttons=0` sem travamento de tecla sintética, encerrando com `código 0`.
- Empacotamento Windows (`npm run build:official`), `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.24` (`196` arquivos verificados) e validação do binário empacotado `dist\win-unpacked\resources\brum-core-pc.exe --self-test` / `--describe 1` aprovados.
- Artefato gerado: `BRUMCLASSICS-OFICIAL.exe` (`411241299` bytes, SHA-256 `a43d1e01ac69cc20f6cfc6f379c219aaff4a803380dd28a6d5c0f817c1d965ca`).

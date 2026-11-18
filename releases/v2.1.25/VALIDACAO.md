# Validação — BRUMCLASSICS OFICIAL 2.1.25

## Escopo desta entrega

- Correção direcionada ao módulo **Nintendo Wii U (Cemu)** em `native/brum-core-pc/main.cpp` para garantir entrada funcional dentro dos jogos que exigem **Wii U GamePad** no Jogador 1 mesmo após personalização de perfis no Cemu.

## Verificações executadas após as alterações finais (`b59043b`)

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-brum-core-pc.ps1` + `build\brum-core-pc\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1` (`código 0`).
- `npm run check` e `npm run check:updates`: aprovados (`código 0`).
- `npm test` (`node --test --test-concurrency=2 tests/*.test.js`): `954` aprovados, `1` opcional ignorado (`tests/brum-core-pc-real-core.test.js`, dependente de `BRUM_REAL_CORE_PATH`) e `1` falha por timeout sob execução concorrente (`tests/update-helper.windows.test.js`), que passou na reexecução dedicada (`node --test tests/update-helper.windows.test.js tests/brum-core-pc-host.test.js`: `10/10` aprovados, `0` falhas).
- Empacotamento Windows (`npm run build:official`), `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.25` (`196` arquivos verificados) e validação do binário empacotado `dist\win-unpacked\resources\brum-core-pc.exe --self-test` / `--describe 1` aprovados.
- Artefato gerado: `BRUMCLASSICS-OFICIAL.exe` (`411267256` bytes, SHA-256 `824e7325a906cea5f22de3dfd6a6dfbbc0f0602b9eca1754f53c72d2aad50334`).

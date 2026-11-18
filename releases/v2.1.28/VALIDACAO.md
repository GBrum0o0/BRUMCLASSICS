# Validação — BRUMCLASSICS OFICIAL 2.1.28

## Checks automatizados, benchmark ao vivo e compilação executados

- `npm run check`: sintaxe de todos os scripts e módulos verificada (`código 0`).
- `npm run check:controllers`: `34` testes aprovados (`0` falhas).
- `npm run check:updates`: sintaxe verificada (`código 0`).
- `tests/brumnews.test.js`: `8/8` testes aprovados (verificando `2.1.28` em `package.json`, `index.html`, `brumnews-history.js` e `renderer.js`).
- `npm test`: `971` testes executados (`970` aprovados, `0` falhas, `1` opcional ignorado).
- Teste ao vivo da esteira de lançamento em *Mario Kart 8* (`build/brum-core-pc/brum-core-pc.exe`): `prepare` em `224 ms`, `ctrlSvc.prepareLaunch` em `367 ms` (contra `8.167 ms` antes), `onStart` em `4,72 s` e `onWindowReady` em `8,23 s` com saída `EXIT 0` limpa.
- `npm run build:official`: `brum-core-pc.exe` compilado (`murb_video_tests` e `murb_input_tests` aprovados), `brum_ios_bridge` (`6` testes Rust + `386` licenças verificados) e empacotamento Windows `portable --x64` concluído (`dist\BRUMCLASSICS OFICIAL.exe`).
- `npx electron scripts/verify-release-source.js dist/win-unpacked/resources/app.asar official 2.1.28`: `197` arquivos conferidos.
- `dist\win-unpacked\resources\brum-core-pc.exe --self-test`: `BRUM_CORE_SELF_TEST PASS tripleEscape=1 inputMapping=1 cemuInput=1 raEngine=1`.
- `dist\win-unpacked\resources\brum-core-pc.exe --probe-controllers`: JSON válido retornado.

## Pendências explicitamente NÃO VERIFICADAS nesta sessão

- **Execução interativa completa pela janela gráfica do portátil `2.1.28` com controle físico pareado (`XInput[0..3]` retornou `connected: false` no `--probe-controllers` final):** **NÃO VERIFICADO** — a validação presencial no executável `BRUMCLASSICS-OFICIAL.exe` após o build final fica para confirmação direta do usuário.

## Artefato oficial gerado

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411395908` bytes
- **SHA-256:** `7B1053D0893C3083B5C5B97C10EAC261A24B0E0952EF3ABA1D58172DCFBCFBA1`

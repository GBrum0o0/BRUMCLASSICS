# Validação da versão 2.1.22

## Suítes automatizadas e build final (`e843cf7`)

- `npm run check` e `npm run check:updates`: aprovados (`exit 0`).
- `npm run check:on-brum`: `ON_BRUM_TESTS passed=478 gameplayReady=false` + `8/8` testes Node aprovados (`0` falhas).
- `npm run check:on-brum-pc`: `murb_video_tests` (`2 PASS`), `murb_input_tests` (`1 PASS`) + `36/36` testes Node aprovados (`0` falhas).
- `npm test`: **954 testes, 953 aprovados, 0 falhas e 1 opcional ignorado** (`BRUM Core PC carrega uma ROM de teste em núcleo libretro real` por ausência de `BRUM_REAL_CORE_PATH`), incluindo os novos testes de múltiplos diretórios, autodetecção da pasta `games`, remoção segura, assinatura Wii/GameCube `.nkit.iso` e invalidação delta multi-root.
- `npm run check:on-brum-vault`: **56/56** testes aprovados (`0` falhas).
- `build:ios-bridge`: `5 + 1` testes Cargo aprovados e `386` licenças verificadas.
- `verify-release-source`: `{"version":"2.1.22","edition":"official","verifiedSourceFiles":196}`.
- Pacote Windows final: `BRUMCLASSICS-OFICIAL.exe` com **`410.589.290` bytes** e SHA-256 `FCBC4AD2A8062D7F31CE582EB27B45E99E5FE176D6DACC115CAD810AF5425FF8`.

## Teste E2E do executável empacotado `2.1.22` em sandbox isolada

- Detecção automática da pasta local `games` ao lado do `BRUMCLASSICS OFICIAL.exe` (`Pac-Man` em `a2600`) combinada com diretório externo adicionado (`The Legend of Zelda: A Link to the Past` em `snes`).
- Abertura real de ambos via Launcher (`launched: true`, janela `960x720`, vídeo colorido não uniforme `18` a `19` cores, saída limpa por `Escape`) e gravação isolada do container `.onbrum` de SNES sem tocar em perfis, ROMs ou saves reais.

# Validação da versão 2.1.21

## Suítes executadas sobre o commit final empacotado

- `npm run check`: aprovado (exit `0`).
- `npm run check:updates`: aprovado (exit `0`).
- `npm run check:on-brum`: `ON_BRUM_TESTS passed=478 gameplayReady=false`, somado a `8/8` testes Node aprovados (exit `0`).
- `npm run check:on-brum-pc`: `murb_video_tests` (`2 PASS`), `murb_input_tests` (`1 PASS`) e `36/36` testes Node aprovados (exit `0`).
- `npm test`: **949 testes, 948 aprovados, 0 falhas e 1 opcional ignorado** (teste libretro externo condicionado a `BRUM_REAL_CORE_PATH`).
- `npm run check:on-brum-vault`: **56/56** testes aprovados (exit `0`, proteção integral dos saves e isolamento de containers `.onbrum`).
- `build:ios-bridge`: `5 + 1` testes Cargo aprovados e `386` registros de licença conferidos contra `Cargo.lock`.
- `verify-release-source`: `{"version":"2.1.21","edition":"official","verifiedSourceFiles":196}`.
- Pacote final Windows x64: `BRUMCLASSICS-OFICIAL.exe` com **`410.573.362` bytes** e SHA-256 `590C1E68C3605E33F0EC36C459A3FF3E31C5357D6C743519D6DD7B66259BEDFA`. Dependências transitivas (`dijkstrajs`, `pngjs`, etc.) conferidas presentes dentro de `app.asar`.

## Teste end-to-end do executável empacotado (`Official`) em perfil isolado

Executado em perfil temporário isolado de `APPDATA`, `LOCALAPPDATA`, `USERPROFILE` e pasta de ROMs copiada, sem tocar em perfis, ROMs ou saves reais:

- Descoberta de mídia: `6/6` títulos clássicos localizados com `integrityStatus: "verified"`.
- Abertura pelo fluxo do Launcher (`brumCorePcStatus` + `launchGame` usando `M.U.R.B ENGINE`): `Pac-Man` (`a2600`), `Excitebike` (`nes`), `The Legend of Zelda: A Link to the Past` (`snes`), `Super Mario Advance 4` (`gba`), `Pokémon Red` (`gb`) e `Pokémon Crystal` (`gbc`) iniciaram janela Win32 (`960x720`) com saída visual variada (`24` a `29` cores amostradas), reação de entrada e encerramento limpo por `Escape`.
- Saves isolados gravados em `murb-test-saves/primary/...`: `gbc` (`32.961` bytes `.onbrum`) e `snes` (`65.695` bytes `.onbrum`), sem criação ou alteração fora da sandbox.

## Matriz de gameplay estendido (`10 min` = `36.000` quadros @ 60 Hz) e sondas comerciais

- **Atari 2600 (`Pac-Man`):** `36.000` quadros no core (`48,02 s` parede, `6` cores únicas, `35.999` mudanças de hash, reação a input confirmada, `rms=1613.67`) e `36.000` quadros no host `brum-core-pc` (`saveCommitted=1`, saída WASAPI `submittedAudioFrames=94140` em `180` quadros).
- **NES (`Excitebike` / `Super Mario Bros. 3`):** `36.000` quadros cada no core (`11` cores / `16.264` trocas de hash / `rms=778.101` em *Excitebike*; `7` cores / `6.176` trocas de hash / `rms=517.691` em *SMB3*), mais host `36.000` quadros e WASAPI (`submittedAudioFrames=143763`).
- **SNES (`A Link to the Past` / `Super Mario World`):** `36.000` quadros cada no core (`52` cores / `6.596` trocas / `rms=2205.08` em *LttP*; `47` cores / `13.271` trocas / `rms=826.17` em *SMW*), persistência de SRAM `65.536` bytes (`saveCrc=928859301` e `803676318`) e restauração comprovada após reabrir (`900` quadros e host `.onbrum` `BRUM_CORE_SAVE restored=1 saveCommitted=1`).
- **GBA (`Super Mario Advance 4` / `Pokémon Emerald`):** `36.000` quadros em *SMA4* (`61` cores / `7.970` trocas / `rms=7384.62`, Flash128 `131.072` bytes `saveCrc=1581853677` restaurado ao reabrir pulando seleção de idioma); `Pokémon Emerald` em `1.800` quadros (`35` cores, áudio `rms=5690.54`).
- **GB / GBC (Regressão):** `Pokémon Red` (`1.800` quadros, `rms=3546.73`, save `532` bytes não nulos, host WASAPI `144514`) e `Pokémon Crystal` (`1.800` quadros, `rms=1070.13`, recarga de save `.onbrum` `BRUM_CORE_SAVE restored=1 saveCommitted=1`).
- **Bloqueios e pendências confirmados nesta revisão:** `nds` (`Mario Kart DS`, `New Super Mario Bros.`, `Pokémon Platinum`, `Super Mario 64 DS` com `uniqColors=1` e `nonzeroAudio=0` em `900` quadros), `3ds` (*Pokémon X* recusado por `.code` comprimido), `genesis` e `n64` (tela preta/silêncio em `180` quadros), `xbox` (`default.xbe` estático em `30` quadros), `sms`/`gg`/`pce` sem ROMs comerciais locais, e demais sistemas do catálogo de 30 grupos apenas experimentais.

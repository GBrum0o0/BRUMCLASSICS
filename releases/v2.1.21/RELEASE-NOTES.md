# BRUMCLASSICS OFICIAL 2.1.21 (Windows)

Esta atualização publica o lote validado da **M.U.R.B ENGINE** no Launcher Windows (`Official`), mantendo a execução de **CLASSICS** sem RetroArch ou DLLs externas, com saves de teste isolados e preservação integral dos saves antigos. Se precisar dos backends externos anteriores, mantenha a [2.1.5](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v2.1.5).

> **Aviso de escopo:** o porte dos 30 grupos **ainda não foi concluído**. Somente os 4 sistemas comerciais validados por 10 minutos abaixo entram como **Jogável Verificado** nesta build; os demais sistemas permanecem experimentais, em diagnóstico ou pendentes.

## Correções e sistemas validados (`JOGÁVEL VERIFICADO` — 10 min / 36.000 quadros)

- **Atari 2600 (`a2600`):** *Pac-Man* validado em 36.000 quadros com vídeo TIA, reação aos controles, áudio coerente e abertura/saída pelo executável empacotado.
- **NES (`nes`):** *Excitebike* e *Super Mario Bros. 3* validados em 36.000 quadros cada, com saída WASAPI e controles ativos. Suíte nativa ampliada com testes de MMC3 CHR-RAM/A12 e ciclos de alinhamento de OAM DMA.
- **SNES (`snes`):** correções de sprites/prioridade/saída RGBA; *The Legend of Zelda: A Link to the Past* e *Super Mario World* validados em 36.000 quadros com persistência e recarga da SRAM nativa (`64 KiB`) em container `.onbrum` isolado.
- **GBA (`gba`):** *Super Mario Advance 4 - Super Mario Bros. 3* validado em 36.000 quadros com persistência e recuperação do save Flash128 (`128 KiB`) após reabertura; *Pokémon Emerald* validado em boot/áudio (`1.800` quadros).

## Regressões preservadas (sem certificação adicional)

- **GB / GBC:** *Pokémon Red* e *Pokémon Crystal* (RTC e `.onbrum`) seguem estáveis na abertura pelo Launcher empacotado, reabertura de save e suíte completa do **Cofre de Saves** (`56/56`), sem risco aos saves originais.

## Sistemas em diagnóstico, bloqueados ou experimentais (pendentes)

- **Nintendo DS (`nds`):** incluídas correções de Shared WRAM, timers/cascade, RTC, AUXSPI, divisão/raiz, IPC FIFO Recv, DMA de cartucho e canais de áudio ARM7 (cobertos por regressão na suíte nativa de `478` testes e ROMs de diagnóstico). **Bloqueio comercial:** *Mario Kart DS*, *New Super Mario Bros.*, *Pokémon Platinum* e *Super Mario 64 DS* seguem exibindo tela branca uniforme e áudio zerado.
- **Nintendo 3DS (`3ds`):** layout de duas telas (`F3`) e ROMs diagnósticas ARM11 sem compressão funcionam no host, mas jogos comerciais comprimidos (como *Pokémon X* `.3ds`) continuam sendo recusados (`ExeFS .code comprimido ainda não suportado`).
- **Master System (`sms`), Game Gear (`gg`) e PC Engine (`pce`):** testes sintéticos aprovados na suíte nativa; **sem mídia comercial local testada nesta entrega**.
- **Mega Drive (`genesis`) e Nintendo 64 (`n64`):** sondas comerciais curtas (*Golden Axe* e *Super Mario 64*) ainda resultam em tela preta/silêncio nesta revisão.
- **Xbox (`xbox`):** leitura inicial de `default.xbe` com quadro estático em sonda curta, sem gameplay comercial verificado.
- **Demais grupos experimentais pendentes:** Atari 7800, SG-1000, Neo Geo, Neo Geo Pocket, WonderSwan, Atari Lynx, MSX, Sega CD, Sega 32X, PS1, PS2, PSP, Saturn, Dreamcast, GameCube, Wii, 3DO e Atari Jaguar permanecem apenas com estrutura/diagnóstico sintético (não certificados).

## Arquivo desta release

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Canal:** `Official`
- **Tamanho:** `410.573.362` bytes
- **SHA-256:** `590C1E68C3605E33F0EC36C459A3FF3E31C5357D6C743519D6DD7B66259BEDFA`

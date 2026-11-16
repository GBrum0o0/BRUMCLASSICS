# BRUMCLASSICS OFICIAL 2.1.23

Integração completa da base híbrida da **M.U.R.B ENGINE** no **BRUMCLASSICS OFICIAL** para **33 sistemas** (todos os consoles e portáteis integrados ao Launcher, **exceto PS3 e Xbox**), mantendo a base dos módulos autorais `on-brum` para evolução gradual rumo a uma engine 100% autoral.

## O que mudou nesta versão

- **33 sistemas integrados no BRUMCLASSICS OFICIAL:** Game Boy (`gb`), Game Boy Color (`gbc`), Game Boy Advance (`gba`), Nintendo DS (`nds`), Nintendo 3DS (`3ds`), NES (`nes`), SNES (`snes`), Nintendo 64 (`n64`), GameCube (`gamecube`), Wii (`wii`), Wii U (`wiiu` via ponte **Cemu** e fallback HLE `.rpx`), Master System (`sms`), Game Gear (`gg`), Mega Drive/Genesis (`genesis`), Sega CD (`segacd`), Sega 32X (`sega32x`), Sega Saturn (`saturn`), Dreamcast (`dreamcast`), SG-1000 (`sg1000`), PlayStation (`ps1`), PlayStation 2 (`ps2`), PSP (`psp`), Atari 2600 (`a2600`), Atari 7800 (`a7800`), Atari Jaguar (`jaguar`), Atari Lynx (`lynx`), PC Engine (`pce`), Neo Geo (`neogeo`), Neo Geo Pocket (`ngp`), WonderSwan (`ws`/`wsc`), 3DO (`3do`), MSX (`msx`) e Arcade (`arcade`).
- **Bloqueio explícito de PS3 e Xbox:** tanto a política/seleção do Launcher quanto o host nativo `brum-core-pc.exe` recusam explicitamente `ps3` e `xbox` nesta versão.
- **Recursos integrados ao host (`brum-core-pc.exe`):** execução via núcleos locais não vazios (ignorando DLLs placeholder de `0` byte), áudio **WASAPI** com reamostrador **Sonic**, ajuste adaptativo de tempo para Wii, **Gamepad Híbrido LAN** com QR/segunda tela para **DS/3DS/Wii U** (`F3`), OSD nativo, controle XInput/multijogador e suporte híbrido com os módulos autorais `on-brum`.
- **Detecção e proteção de mídia/saves:** inspeção de assinaturas `.iso` (Wii/GameCube, incluindo `.nkit.iso`), hash amostrado `BRUM-LARGE-v1` para imagens de disco grandes acima de `64 MiB`, guarda de estado pausado no encerramento `on-brum`, captura exclusiva de quadros sem sobrescrita e preservação de saves `.srm`/`.onbrum`.

## Notas e limites técnicos

- Bibliotecas de núcleos de terceiros (`cores/` ou `Cemu.exe`), ROMs, BIOS e saves não são embarcados no executável portátil; o host utiliza os núcleos instalados localmente pelo usuário no computador ou pasta configurada em **Configurações → CLASSICS**.
- Por escopo desta entrega (`2.1.23`), os testes automatizados completos e a verificação de empacotamento foram executados sem bateria manual individual por console; os módulos autorais `on-brum` mantêm `onBrumProductionReady: false` enquanto evoluem em paralelo.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411236477` bytes
- **SHA-256:** `b9baf6298e510ea3ca907e738eb361470cfeb01d4cd1396014bd21e4bf5c3573`

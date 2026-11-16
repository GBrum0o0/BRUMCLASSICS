# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.23

## O que entrou nesta release

- Integração da arquitetura híbrida de **M.U.R.B ENGINE** ao **BRUMCLASSICS OFICIAL**: execução unificada pelo host nativo `brum-core-pc.exe` com suporte a núcleos locais não vazios, ponte **Cemu** e fallback HLE para **Wii U**, áudio **WASAPI** com reamostrador **Sonic**, ajuste adaptativo para **Wii**, **Gamepad Híbrido LAN**, alternância de telas (**DS/3DS/Wii U**), OSD nativo e leitura de memória para RetroAchievements, preservando os módulos autorais `on-brum` (`gb`, `gbc`, `gba`, `nes`, `snes`, `a2600` e registro de `32` consoles autorais) como base da futura engine 100% autoral.
- Política explícita de bloqueio para **PS3** e **Xbox** no Launcher (`murb-runtime-policy.js`, `retro-service.js`, `brum-core-pc-service.js`) e no host nativo (`brum-core-pc.exe --describe 1` reporta `"excludedSystems":["ps3","xbox"]`).
- Correções de segurança e robustez identificadas na bateria automatizada: guarda de estado pausado no encerramento (`on_brum` DS/GB), validação estrita de parâmetros AV inválidos em núcleos externos (`initialize_audio_video`), captura de quadros exclusiva sem sobrescrita (`--capture-frame`) e detecção por assinatura binária `.iso` (Wii/GameCube) com prioridade sobre nomes genéricos de diretórios ancestrais.

## Separação de código privado, mídia e saves

- O pacote final não embarca bibliotecas terceiras de núcleos (`RetroArch-Win64/cores` ou `Cemu.exe`), ROMs, BIOS, saves de usuário nem código privado/ferramentas internas (`audit-public-repo.ps1`).
- Saves nativos (`.srm`) e containers autorais isolados (`.onbrum`) seguem separados sem conversão automática destrutiva e com verificação de integridade antes de restaurar ou gravar.


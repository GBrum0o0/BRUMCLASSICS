# BRUMCLASSICS OFICIAL 2.1.41 — Correção de Empacotamento e Melhorias DS/3DS/Wii/Wii U/PSP

- **Correção de inicialização no pacote portátil (Windows):** restaura todas as dependências transitivas de produção no `app.asar` (`dijkstrajs`, `pngjs`, `qrcode` e módulos auxiliares da ponte móvel) eliminando o erro `Cannot find module 'dijkstrajs'` ao abrir o executável portátil.
- **Inclui todas as correções da 2.1.40:**
  - **Toque no DS e 3DS (celular e computador):** retenção temporizada de `75ms` no servidor WebSocket (`murb_remote_server.hpp`), fallback funcional de mouse no PC para P1 em modos multi-jogador, `citra2018_analog_function = C-Stick` e preservação da proporção do Nintendo DS em tela cheia.
  - **Wii e PSP (modo Gamepad e abertura direta):** hash RetroAchievements movido para segundo plano após `BRUM_CORE_READY`, prioridade para os núcleos empacotados do pacote, serialização de chamadas remotas no launcher, tolerância ampliada (`45s`/`35s`) e visibilidade garantida da janela.
  - **Wii U (`Cemu` pelo celular):** `controller0.xml` exclusivo do slot virtual ViGEm em modo 1 jogador (`single_vigem`), fallback automático para teclado quando ViGEm estiver indisponível e polling PnP ampliado do slot ViGEmBus.

Atualize pelo executável oficial desta release (`BRUMCLASSICS-OFICIAL.exe`). Seus saves e configurações são preservados.

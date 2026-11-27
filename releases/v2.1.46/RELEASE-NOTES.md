# BRUMCLASSICS OFICIAL 2.1.46 — Correção GameCube, Transição Suave, Otimizações MURB/Launcher e Nomenclatura BRUMCLASSICS+

- **Correção gráfica do Nintendo GameCube (`dolphin_libretro.dll`):**
  - Alinha o pipeline OpenGL FBO do GameCube ao mesmo fluxo estável do Wii, preserva estados GL nos shaders pós-processamento, pré-dimensiona o FBO (`1280×1056` / `2560×2112` em 4x), ativa shaders `Synchronous`, `Fastmem` e `EFBToTexture` em 4:3 e elimina piscadas/tela preta e leituras síncronas por frame.
- **Transição suave entre Intro e Jogos:**
  - Mantém a janela do emulador oculta até a confirmação do primeiro quadro não-preto (`DwmFlush`) e libera o foco antes de fechar o overlay inicial, eliminando flashes de janela preta ou desktop na abertura.
- **Otimizações na MURB Engine e no Launcher Desktop:**
  - VSync `wglSwapIntervalEXT(1)` + `CS_OWNDC`, reutilização de buffers de vídeo/CAS por thread, cache persistente em disco para identidade de ROMs/ISOs, cache de 10 minutos para descoberta de controles (`Get-PnpDevice`) e redução automática de tarefas em segundo plano durante emulação ativa.
- **Nomenclatura oficial (`BRUMCLASSICS+` e `MURB Engine`) & Pokédex Universal:**
  - Atualiza textos visíveis para **BRUMCLASSICS+** (mobile) e **MURB Engine** (motor de emulação), enriquece as 809 espécies do catálogo (`1.1.0`) mantendo redação estrita pré-captura e inclui o adaptador compartilhado Gen 4 **Pokémon Platinum (`CPUE`)** em fase piloto.

Atualize pelo botão **Verificar** no Launcher ou pelo executável oficial desta release. Jogos, ROMs, BIOS, configurações e saves existentes são preservados.

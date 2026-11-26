# BRUMCLASSICS OFICIAL 2.1.45 — Shaders de Resolução Eficientes & Menu Rápido em Jogo

- **Shaders de nitidez e upscaling eficientes em GPU (OpenGL) e CPU no M.U.R.B Core PC:**
  - **Nitidez adaptativa (`CAS`):** pipeline GLSL 5-tap em placa de vídeo para núcleos 3D/OpenGL e implementação inteira em CPU com trava local `[min, max]` para evitar halos e artefatos.
  - **Edge Upscale 2x (`EPX / Scale2x`):** suavização inteligente de bordas e diagonais em pixel art 2D até 640×480 (com fallback CAS seguro acima disso).
  - **Sharp Bilinear (`anti-tremor`):** pré-escala 2x + filtragem linear/halftone mantendo quinas definidas em tela cheia sem cintilação ao mover a câmera.
  - **CRT Scanlines & Grade LCD aprimorados** no shader OpenGL e na apresentação GDI.
- **Menu rápido in-game pela tecla `G`:** abre sobre metade da tela sem perder o foco do jogo, permite ajustar multiplicador interno 3D, escala e filtro gráfico com visualização ao vivo e persiste configurações individualmente por jogo (sem afetar os demais títulos).
- **Pacote de Melhoria de Resolução:** opções unificadas entre Launcher (`Configurações → Gráficos`), runtime M.U.R.B e menu `G`.

Atualize pelo botão **Verificar** no Launcher ou pelo executável oficial desta release. Jogos, ROMs, BIOS, configurações e saves existentes são preservados.

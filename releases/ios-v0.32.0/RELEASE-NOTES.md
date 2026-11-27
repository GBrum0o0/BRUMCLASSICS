# BRUMCLASSICS MÓVEL iOS 0.32.0 — Correção PPSSPP, Google Drive e Menu Logo In-Game

- **Google Drive no Gaming Mode (`ClassicDriveCloudService` + `ROMFolderLibrary` + `ClassicsEverywhere`):**
  - Corrige o parser HTML do Google Drive para pastas reais (`flip-entry-title` aninhado dentro de `<a>`, entidades HTML, suporte a `resourcekey`, arquivos diretos e detecção de `ServiceLogin`/aviso de download grande).
  - Jogos baixados pelo Drive agora aparecem imediatamente na biblioteca com o botão **Jogar** pronto para iniciar o núcleo compatível (incluindo detecção ISO-9660 para PSP).
- **Correções no PSP (PPSSPP) no iOS (`ppsspp-ios-libretro.patch` + `GraphicsResolutionPack` + `BrumLibretroEngine`):**
  - Carregamento síncrono do executável PSP na `Load_PSP_ISO` / `Load_PSP_ELF_PBP` no iOS, evitando estourar a stack reduzida (512 KB) de threads secundárias no iOS.
  - Suporte explícito ao VAO global do OpenGL ES 3.0 no `GLQueueRunner` e fallback seguro para `g_defaultFBO` em blits/readbacks, além de reforço contínuo de `IR_JIT` sem JIT executável.
  - Multiplicador padrão seguro para PSP no iOS (`1x` em perfis baixo/médio e `2x` em alto) com logs de vendor/renderer GL e diagnóstico rápido em caso de ausência de vídeo/áudio.
- **Novo Menu Rápido Translúcido na Logo (`BrumLibretroEngine`):**
  - Remove a barra superior fixa durante o jogo e centraliza todos os atalhos na **logo BRUMCLASSICS translúcida** no centro superior: controles na tela, alternância stick/D-Pad, ajuste de opacidade e tamanho (persistidos), estados rápidos (slots), dimensão de tela, filtros/shaders ao vivo, avanço rápido `5×`, diagnóstico e saída do jogo.

Atualize via SideStore ou baixando o `.ipa` desta release preservando saves, biblioteca e configurações.

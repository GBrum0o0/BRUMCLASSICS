# BRUMCLASSICS MÓVEL Android 0.22.1

## Estados rápidos no BRUM Core

- GB, GBC e GBA agora possuem três slots locais de estado rápido.
- O menu **SLOTS** permite salvar ou retomar uma sessão sem sair do jogo.
- Os estados rápidos permanecem separados do save normal do cartucho.
- Cada arquivo usa a identidade estável do conteúdo da ROM e registra sistema, núcleo e versão do núcleo.
- Estados vazios, corrompidos ou incompatíveis são recusados sem alterar o save normal.
- A gravação é atômica para não deixar um slot parcial após interrupção.

O APK é arm64, requer Android 8.0/API 26 ou superior e mantém o fallback do RetroArch para sistemas ainda não integrados.

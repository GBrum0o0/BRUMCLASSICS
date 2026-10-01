# BRUMCLASSICS MÓVEL iOS 0.13.7

## Fundação multicore

- O controlador Libretro recebe dinamicamente biblioteca, nome e versão do núcleo.
- Mensagens, status, saves e estados rápidos deixam de presumir mGBA internamente.
- A versão exata do núcleo passa a acompanhar o save e cada slot rápido.
- Os cartões informam `BRUM CORE · MGBA` quando a execução acontece dentro do aplicativo.
- Sistemas sem núcleo interno aprovado permanecem no RetroArch de forma transparente.
- GB, GBC e GBA continuam com todas as funções da versão anterior.

O IPA é arm64, sem assinatura, e deve ser assinado pelo Sideloadly ou AltStore.

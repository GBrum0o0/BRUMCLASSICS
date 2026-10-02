# BRUMCLASSICS MÓVEL iOS 0.15.0

## BRUM Core GPL e novos consoles

- O código próprio do aplicativo móvel e do BRUM Core passa a GPL-3.0-or-later; o launcher de PC continua proprietário e a marca/artes permanecem sob licença separada.
- NES/Famicom passa a abrir diretamente com Nestopia UE.
- Master System e Game Gear passam a abrir diretamente com Gearsystem.
- Cartuchos PC Engine/TurboGrafx-16 `.pce` passam a abrir diretamente com Beetle PCE Fast.
- SNES/Super Famicom `.sfc` e `.smc` passam a abrir diretamente com bsnes-mercury Performance.
- Permanecem integrados mGBA, SkyEmu e Geolith.
- Todos os núcleos usam revisões fixadas, licenças empacotadas, saves normais, três slots rápidos e o host multicore existente.
- PlayStation 2, PSP, Nintendo 64, Dreamcast, Nintendo 3DS e GameCube continuam limitados no fluxo comum do iOS pela ausência de JIT; fallback externo não é suporte nativo.

O IPA é arm64, sem assinatura, e deve ser assinado pelo Sideloadly ou AltStore. O build real depende do workflow macOS.

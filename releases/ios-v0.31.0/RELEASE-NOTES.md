# BRUMCLASSICS MÓVEL iOS 0.31.0 — Shaders de Resolução Eficientes

- **Novos shaders de nitidez e upscaling no motor nativo iOS (`BrumLibretroEngine` + `brum_resolution_shaders.hpp`):**
  - **Nitidez adaptativa (`cas_sharpen`):** realce local de bordas e texturas com proteção contra halos em cores `XRGB8888`, `RGB565`, `0RGB1555` e leitura OpenGL ES (`BrumHardwareFrameBuffer`).
  - **Edge Upscale 2x (`edge_upscale_2x`):** dobramento inteiro EPX/Scale2x para jogos 2D até 640×480 (fallback CAS em resoluções superiores).
  - **Sharp Bilinear (`sharp_bilinear`):** pré-escala 2x + filtro linear `kCAFilterLinear` aplicado também em layouts de duas telas (DS/3DS) para reduzir tremor de rolagem mantendo bordas nítidas.
- **Configurações gráficas:** seletores atualizados no pacote de resolução para sistemas 2D, portáteis e 3D mantendo retorno seguro para o padrão original.

Atualize via SideStore ou baixando o `.ipa` desta release preservando saves, biblioteca e configurações.

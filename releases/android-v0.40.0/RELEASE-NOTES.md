# BRUMCLASSICS MÓVEL Android 0.40.0 — Shaders de Resolução Eficientes

- **Novos shaders de melhoria de resolução no Android (`BrumCoreView` + `GraphicsResolutionRules`):**
  - **Nitidez adaptativa (`cas_sharpen`):** filtro CAS de 5 pontos com limitação local anti-halo sobre o framebuffer `ARGB_8888`.
  - **Edge Upscale 2x (`edge_upscale_2x`):** algoritmo EPX/Scale2x inteiro em memória pré-alocada sob demanda para consoles e portáteis 2D até 640×480 (com recuo automático CAS acima disso).
  - **Sharp Bilinear (`sharp_bilinear`):** pré-escala 2x pareada com amostragem linear de hardware para evitar tremor de subpixel em movimento.
- **Configurações gráficas (`Pacote de Melhoria de Resolução`):** os novos filtros ficam disponíveis nos seletores 2D, portáteis e 3D com persistência e fallback seguro ao original.
- **Publicação automática oficial no GitHub Releases** para o APK desta versão (`android-v0.40.0`).

Instale `BRUMCLASSICS-MOVEL-0.40.0.apk` sobre a versão anterior para preservar seus jogos, saves e configurações.

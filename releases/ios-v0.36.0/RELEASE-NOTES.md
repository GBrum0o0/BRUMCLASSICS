# BRUMCLASSICS+ iOS 0.36.0 — Estabilidade e Controles do PPSSPP

- **PPSSPP sem travamentos constantes:**
  - Substitui a leitura síncrona por CPU (`glReadPixels` + `CGImage`) por apresentação direta em GPU via `CAEAGLLayer` (`glBlitFramebuffer` + `presentRenderbuffer`) para os filtros de hardware.
  - Adiciona espera de quadro limitada (`ThreadFrameTimed`) na integração Libretro do PPSSPP para impedir bloqueio contínuo da thread principal no iOS sem JIT.
  - Habilita auto frameskip adaptativo (`ppsspp_auto_frameskip = enabled`, `ppsspp_frameskip = 1`) e filtra logs informativos excessivos durante a execução.
- **Controles virtuais do PPSSPP responsivos:**
  - Passa a exibir D-Pad e analógico esquerdo simultaneamente na tela de PSP (essencial para menus e títulos sem suporte inicial ao analógico).
  - Garante retenção mínima de 2 quadros (`latchButton`) para toques rápidos nos botões e no direcional digital.

Instale e atualize conectando o iPhone ao PC exclusivamente pelo **Brum iOS Bridge** no BRUMCLASSICS Desktop.

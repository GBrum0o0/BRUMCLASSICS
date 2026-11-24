# BRUMCLASSICS MÓVEL iOS 0.29.0 — Correções PSP Nativo e Toque DS/3DS

- **PSP nativo no iOS (`PPSSPP`):** garante vinculação do FBO de saída na thread GL (`ThreadFrame` / `CreateDrawContext` / `ContextReset`), atualização de `SetTargetSize` em `GotBackbuffer`, correção de `glInvalidateFramebuffer` com `GL_STENCIL_ATTACHMENT`, preservação completa de estado GLES3 no readback de frame e padrões explícitos de renderização buffered.
- **Toque no DS e 3DS (nativo e controle remoto):** evita sobreposição de `SELECT`/`START` na área de toque em modo dual-screen, mapeia o toque exclusivamente na imagem ativa da tela inferior (ignorando bordas) e libera o ponteiro automaticamente ao desconectar, pausar ou rotacionar a tela.

SideStore e atualização pelo fluxo existente preservados. Atualize mantendo os dados; não é necessário desinstalar.

# BRUMCLASSICS+ iOS 0.37.0 — Correção Crítica de Congelamento e Travamentos no PPSSPP

- **Fim do congelamento ao tocar na tela ou abrir o menu rápido:**
  - Elimina consultas repetidas a `retro_serialize_size()` durante toques na tela e troca de modo de exibição, além de encerrar a pausa indevida em `retro_serialize_size()` no PPSSPP Libretro.
- **Execução estável sem travamentos no iOS sem JIT:**
  - Restaura padrões essenciais de `g_Config` ignorados no backend Libretro (`bIgnoreBadMemAccess`, `bSoftwareSkinning`, `bFragmentTestCache`, `bVendorBugChecksEnabled`, `bHighQualityDepth`, `iBufFilter = SCALE_LINEAR`, `iInflightFrames = 3`).
  - Limita o `maxFrameskip` do auto frameskip ao valor configurado (`1`) mesmo com `unthrottle = true`, evitando saltos de 8 quadros.
  - Adiciona verificação rápida de faixa mapeada nas leituras e gravações `Unchecked` do interpretador IR no iOS.
- **Saída limpa, áudio e RetroAchievements:**
  - Evita deadlock no `EmuThreadStop()` e no `EmuThreadPause()`, reduz o atraso máximo do buffer de áudio e sincroniza a inicialização de RetroAchievements após o primeiro quadro visível.

Instale e atualize conectando o iPhone ao PC exclusivamente pelo **Brum iOS Bridge** no BRUMCLASSICS Desktop.

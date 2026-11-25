# BRUMCLASSICS MÓVEL Android 0.39.0 — Correções de Toque DS/3DS, Gamepad e PSP

- **Toque no Nintendo DS e Nintendo 3DS:** retém toques curtos por 4 quadros na bridge nativa C++ (`brum_core.cpp`), desativa `citra_enable_mouse_touchscreen` e preserva eventos `touching: true` na fila WebSocket (`MurbRemoteClient`).
- **Modo Gamepad para PC (Wii, PSP, Wii U):** amplia o timeout de leitura de `/v1/remote` para 45 segundos durante lançamentos no computador e reduz perda de eventos rápidos de toque.
- **PSP (`PPSSPP`):** habilita `ppsspp_auto_frameskip = enabled` com `frameskip = 1` para manter ritmo suave e resposta consistente.

Instale `BRUMCLASSICS-MOVEL-0.39.0.apk` sobre a versão anterior para preservar seus jogos, saves e configurações.

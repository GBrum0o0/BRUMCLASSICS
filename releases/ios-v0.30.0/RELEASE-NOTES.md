# BRUMCLASSICS MÓVEL iOS 0.30.0 — Correções PSP Nativo, Toque DS/3DS e Modo Gamepad

- **PSP nativo no iOS (`PPSSPP`):** muda a emulação CPU para `IR jit` (`CPUCore::IR_JIT` via interpretador IR seguro, sem precisar de JIT executável no iOS) com `ppsspp_auto_frameskip = enabled`, acelerando a inicialização e eliminando telas pretas longas.
- **Toque no Nintendo DS e Nintendo 3DS:** retém toques rápidos por 4 quadros em execuções nativas (`BrumLibretroEngine`), desativa `citra_enable_mouse_touchscreen` e garante que o WebSocket remoto envie eventos `touching: true` antes de um `touching: false` subsequente.
- **Modo Gamepad (Wii, PSP e Wii U):** amplia o timeout do comando `/v1/remote` para 45 segundos e evita repetição em hosts alternativos quando um lançamento está demorando no computador.

Atualize via SideStore ou baixando o `.ipa` desta release preservando saves e biblioteca.

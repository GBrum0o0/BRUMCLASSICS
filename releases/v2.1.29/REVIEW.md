# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.29

## Escopo integrado

1. **`src/mobile-bridge.js` & `src/main.js`:** adição do comando remoto autenticado `gamepad_launch` com validação UUID (`requestId`), proteção contra replay (`GAMEPAD_REQUEST_REPLAYED`) e TTL (`GAMEPAD_REQUEST_EXPIRED`), resolução por `gameId`, `filename` ou título e retorno de `remoteGamepad`.
2. **`src/brum-input-core.js`:** extensão de `prepareBackendLaunch({ overrides })` com `--remote-gamepad`, `--local-players` e `--hybrid-mode` (`auto`, `pc1-mobile2`, `mobile1-pc2`, `dual-mobile`, `pc1-pc2`).
3. **`src/brum-core-pc-service.js` & `native/brum-core-pc/main.cpp`:** suporte a `runDesktopGamepadBridge()` (`--desktop-gamepad 1`) nas portas `8089..8094` com sinalização `BRUM_REMOTE_SERVER` / `BRUM_REMOTE_QR` / `BRUM_CORE_READY`, captura de `BRUM_REMOTE_QR_P2` e desligamento limpo em `quitActiveSession`.
4. **Regressões cobertas em testes (`tests/mobile-bridge.test.js`, `tests/brum-input-core.test.js`, `tests/brum-core-pc-service.test.js`):** validação de entrada/replay de `gamepad_launch`, emissão de argumentos híbridos no host e ciclo completo de `launchDesktopGamepad` no binário nativo.

# Validação PC 2.1.34

## Verificação de código, staging e testes automatizados

- **Manifesto e staging do runtime (`verify-brum-runtime.cjs`):** `3.047` arquivos (`259.973.836` bytes) verificados por tamanho, SHA-256, arquitetura PE `x64`, exportações obrigatórias da ABI Libretro, dependências importadas e referências de licença para os `33` sistemas clássicos.
- **Bateria direcionada (`81/81` testes aprovados, `0` falhas):**
  - `tests/brum-runtime-package.test.js` (`13/13`): allowlist, rejeição de binários truncados/arquitetura incorreta/imports ausentes/exports ausentes, bloqueio de mídias/BIOS/saves/symlinks, proibição de caminhos de desenvolvimento em `native/brum-core-pc/main.cpp`, fontes substitutas livres do Dolphin e hook `beforePack`.
  - `tests/brum-core-pc-configuration.test.js`: detecção de host e núcleos via `resources/brum-runtime` em perfil limpo sem RetroArch, precedência de pasta escolhida pelo usuário, preservação de BIOS/configurações em `system`, continuidade de `portable/settings.xml` e `portable/mlc01` do Cemu entre upgrades/downgrades com backups SHA-256, bloqueio de junctions e rejeição de assets adulterados.
  - `tests/brum-core-pc-host.test.js` e `tests/brum-core-pc-service.test.js`: self-test nativo (`BRUM_CORE_SELF_TEST PASS`), execução Libretro direta com persistência de SRAM, encerramento concorrente sem thread órfã, IPC `QUIT` e proteção de perfil.
  - `tests/murb-pc-distribution.test.js`, `tests/controller-model.test.js`, `tests/brumnews.test.js` e `tests/update-service.test.js`: todos aprovados.

## Inspeção do pacote final e smoke test em perfil limpo (`verify-pc-package-2.1.34.cjs`)

- **Executável portátil (`BRUMCLASSICS-OFICIAL.exe`):** `680.053.367` bytes, SHA-256 `255f62e83b61640c1445352b0c592f783c792227f8f466d03c9fca35d5362b46`.
- **Paridade do `app.asar`:** `197` arquivos de `src/` idênticos byte a byte à worktree, metadados `2.1.34` (`official`), paridade completa de `node_modules` de produção (`qrcode`, `adm-zip`, `ws`, `three` carregados e PNG QR de `1.619` bytes renderizado) e zero arquivos privados/proibidos.
- **Recursos nativos e fontes correspondentes:**
  - `resources/brum-core-pc.exe` (SHA-256 `2ca31aa1ee623204bb70b6cd967ce928e89db2d584b13a9427da0a42593b77a5`) aprovado em `--self-test`.
  - `resources/brum-ios-bridge.exe` (SHA-256 `28a9af70c41bd77e7058b967c28c16cdffec5cc66d80a28cfa7291ae0aad03a8`), `859` arquivos em `resources/ios-bridge-source` e `386` registros de licença verificados contra `Cargo.lock`.
  - `164` arquivos em `resources/brum-core-pc-source` (`native/brum-core-pc`, `native/on-brum`, `native/BRUM-HOST-LICENSE.md`, `scripts/build-brum-core-pc.ps1`) verificados byte a byte.
  - `3.047` arquivos em `resources/brum-runtime` revalidados dentro de `dist/win-unpacked/resources/brum-runtime`, mais as `10` DLLs redistribuíveis MSVC VC143 adjacentes ao host.
- **Smoke test em perfil limpo (`cleanProfileSmoke33Of33: true`):** com `userData`, `LOCALAPPDATA` e `PORTABLE_EXECUTABLE_DIR` isolados em diretórios temporários vazios (sem RetroArch ou Cemu externo e sem caminhos `H:\`), `runtimeInfo()` confirmou `hostAvailable: true` e **`33/33` sistemas com núcleo encontrado** em `resources\brum-runtime`, além do staging privado verificado para `system/PPSSPP`, `system/dolphin-emu` e `runtime/cemu/Cemu.exe`.

## Limites

- Os testes comprovam a presença, integridade e carregamento diagnóstico do pacote em perfil limpo, não certificando compatibilidade comercial completa de todos os 33 sistemas nem substituindo firmware fornecido pelo usuário.

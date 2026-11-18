# BRUMCLASSICS OFICIAL 2.1.25

Correção no host **BRUM Core PC** (`brum-core-pc.exe`) para garantir que controles reconhecidos pelo Cemu funcionem normalmente **dentro dos jogos** do **Nintendo Wii U**.

## O que foi corrigido nesta versão

- **Normalização automática do Jogador 1 para `Wii U GamePad` (`normalizeCemuPlayer1ProfileToGamePad`):** perfis existentes (`controller0.xml` e perfis nomeados vinculados por `<profile>`) que tenham sido salvos no Cemu como `Wii U Pro Controller` ou `Wii U Classic Controller` são convertidos automaticamente para `Wii U GamePad` (deslocando os índices de mapeamento `12..25` para `11..24` e removendo `Home` `11`), preservando os botões personalizados e o controle (`XInput`, `SDLController`, `DirectInput` ou `WGIGamepad`) configurados pelo usuário.
- **Reatribuição inteligente de slot XInput e fallback de teclado seguro:** se o `<uuid>` XInput salvo apontar para um slot desconectado enquanto outro controle XInput estiver ativo, o host atualiza o vínculo para o slot conectado e preenche os mapeamentos padrão de teclado caso o bloco `<api>Keyboard</api>` esteja vazio.
- **Proteção por jogo e filtro de botões presos:** limpa eventuais linhas `controller1..8=` em `portable/gameProfiles/*.ini`, nunca aciona `winmm`/`joyGetPosEx` enquanto qualquer controle XInput estiver ativo e suprime bits presos desde o quadro 0 no fallback DirectInput.

## Verificação desta entrega

- `build-brum-core-pc.ps1` + `brum-core-pc.exe --self-test` (`tripleEscape=1`, `inputMapping=1`, `cemuInput=1`) aprovados.
- `npm run check` e `npm run check:updates`: aprovados (`código 0`).
- `npm test`: `954` aprovados, `1` opcional ignorado (`brum-core-pc-real-core.test.js`); `tests/update-helper.windows.test.js` falhou por tempo sob execução concorrente e foi reexecutado junto de `tests/brum-core-pc-host.test.js` com `10/10` aprovados (`0` falhas).
- Empacotamento Windows (`npm run build:official`), auditoria ASAR (`scripts/verify-release-source.js`, `official`, `2.1.25`, `196` arquivos) e `dist\win-unpacked\resources\brum-core-pc.exe --self-test` / `--describe 1` validados.

## Artefato oficial e verificação

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Tamanho:** `411267256` bytes
- **SHA-256:** `824e7325a906cea5f22de3dfd6a6dfbbc0f0602b9eca1754f53c72d2aad50334`

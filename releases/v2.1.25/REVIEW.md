# Revisão Técnica — BRUMCLASSICS OFICIAL 2.1.25

## Escopo da correção

- **Causa raiz identificada no ambiente local (`controllerProfiles/controller0.xml` e `nijoijo.xml`):**
  1. Um perfil salvo manualmente nas configurações do Cemu (e preservado intacto pelo script local) definiu Player 1 (`controller0.xml` / `nijoijo.xml`) com `<type>Wii U Pro Controller</type>` e bloco `<api>Keyboard</api><mappings />` vazio.
  2. Embora jogos como *Mario Kart 8* aceitem `Wii U Pro Controller` na porta 0, títulos do Wii U que exigem o **Wii U GamePad (`VPAD`)** para 1 jogador — como *Pokkén Tournament* (`00050000-101df400`) — ignoram o controle dentro da partida quando o Jogador 1 não está em `Wii U GamePad`, mesmo com o Cemu reconhecendo o dispositivo na configuração.
- **Alterações aplicadas (`b59043b`):**
  - Fatorados helpers compartilhados de XML (`buildCemuXInputMappingsXml`, `buildCemuXInputControllerBlock`, `buildCemuKeyboardMappingsXml`, `buildCemuKeyboardControllerBlock`) e adicionado `normalizeCemuPlayer1ProfileToGamePad` para converter perfis de Jogador 1 (`controller0.xml` e `<profile>` nomeado seguro) para `<type>Wii U GamePad</type>`, deslocando os índices `12..25` -> `11..24`, removendo a entrada `11` (Home de Pro/Classic) e preenchendo fallback de teclado quando vazio.
  - Adicionado `resolveOrRetargetCemuXInputSlot` para manter o slot configurado quando conectado ou reatribuir para o slot XInput vivo quando o slot anterior estiver desconectado.
  - Adicionado `sanitizeCemuGameProfilesControllers` em `portable/gameProfiles/*.ini` e supressão de bits presos desde a primeira leitura (`stuckJoyButtonMask`) no fallback `winmm`, com `allowJoyFallback = !anyLiveXInput`.
  - Adicionados testes unitários em `--self-test` e `tests/brum-core-pc-host.test.js`, além da sincronização do host com o diretório local de desenvolvimento/teste.

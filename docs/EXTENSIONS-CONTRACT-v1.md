# BRUM CLASSICS — Contrato Oficial de Extensões v1 e Extensão 001: Pokédex Universal

**Versão do Contrato:** `1.0.0` (`schemaVersion: 1`)
**Identificador da Extensão 001:** `brum.ext.pokedex`
**Responsabilidades:**
- **Antigravity (Backend — Fases 1 e 2 entregues):** arquitetura modular de extensões, catálogo estruturado e versionado de espécies (1ª à 7ª geração, `#001`..`#802` até Pokémon Sun & Moon), matriz de compatibilidade separada por plataforma (`windows`, `ios`, `android`), adaptador C++17 compartilhado de detecção em tempo real e inspeção de save para o piloto **Pokémon FireRed (`BPRE` v1.0/v1.1)**, persistência isolada por perfil independente de saves/ROMs, separação entre abas **Pokémon** (`normal`) e **Shinies** (`shiny`), redação estrita de espécies não descobertas (`???` + silhueta + número oficial visível), sincronização offline-first CRDT PC ↔ Mobile, backup/restauração verificados com `SHA-256` e emissão de eventos `pokedex_discovery`.
- **Codex (Frontend e Validação Visual — Fase 3):** seção **Extensões** no Gamepad Mobile, Pokédex inicialmente fechada com animação de abertura por toque, visualização horizontal dividida (painel esquerdo de detalhes da primeira captura / painel direito com lista rolável ordenada por número oficial, silhuetas pretas, seleção por toque e abas **Pokémon** e **Shinies**), e popup visual para eventos `pokedex_discovery`.

> **Regra de Isolamento entre Agentes:** os arquivos de backend (`shared/brum-core/PokemonFireRedAdapter.*`, `src/extensions/*`, `ios/BRUMCLASSICSMobile/Extensions/*`, `android/.../mobile/extensions/*`) não modificam views de interface para evitar conflitos com o trabalho visual do Codex na Fase 3.

---

## 1. Arquitetura Modular de Extensões (`schemaVersion: 1`)

### 1.1 Manifesto Declarativo (`BrumExtensionManifest`)

```json
{
  "id": "brum.ext.pokedex",
  "number": "001",
  "schemaVersion": 1,
  "version": "1.0.0",
  "title": "Pokédex Universal",
  "shortTitle": "Pokédex",
  "description": "Coleção permanente e sincronizada de Pokémon descobertos pelo jogador no ecossistema Brum Classics.",
  "category": "gamepad-extension",
  "codeExecutionPolicy": "native-compiled-only",
  "defaultEnabled": true,
  "permissions": [
    "brum-core:events.read",
    "brum-core:memory.read",
    "storage:isolated.readwrite",
    "sync:lan.readwrite",
    "gamepad:ui.extension",
    "notifications:discovery.emit"
  ],
  "capabilities": [
    "universal-collection",
    "normal-and-shiny-tabs",
    "automatic-capture-detection",
    "offline-first-lan-sync",
    "verified-backup-restore",
    "discovery-notifications"
  ],
  "platforms": ["windows", "ios", "android"],
  "uiContract": {
    "section": "Extensões",
    "entryPoint": "brum.ext.pokedex",
    "initialState": "closed-device",
    "openAnimation": "pokedex-hinge-open",
    "orientation": "horizontal-split",
    "tabs": ["pokemon", "shinies"]
  }
}
```

- **Segurança iOS/Mobile:** `codeExecutionPolicy` deve ser sempre `"native-compiled-only"`. Qualquer manifesto que solicite execução dinâmica ou código remoto é rejeitado imediatamente.
- **Armazenamento Isolado por Perfil:**
  - Windows: `<userData>/extensions/brum.ext.pokedex/profiles/<profileId>/collection-v1.json`
  - iOS: `Application Support/Extensions/brum.ext.pokedex/profiles/<profileId>/collection-v1.json`
  - Android: `files/extensions/brum.ext.pokedex/profiles/<profileId>/collection-v1.json`
  - O armazenamento é completamente independente dos arquivos `.srm`/`.sav` e do Save Vault: apagar, reiniciar ou substituir o save de qualquer jogo **nunca** remove registros da Pokédex Universal.

---

## 2. Regras de Domínio e Projeção para o Frontend (Codex)

1. **Unicidade por Espécie e Categoria (`normal` vs `shiny`):**
   - Chave primária lógica: `(ownerProfileId, nationalDexNumber, category)` onde `category ∈ { "normal", "shiny" }`.
   - A primeira captura confirmada é preservada permanentemente. Capturas subsequentes da mesma espécie e categoria retornam `recorded: false, duplicate: true`, não sobrescrevem `firstCapturedGame` / `capturedAt` / `captureLocation` e não emitem nova notificação.
   - Capturar um Pokémon `shiny` registra exclusivamente na categoria `"shiny"` (aba **Shinies**), **sem** sobrescrever nem criar automaticamente o registro `"normal"` (aba **Pokémon**). A mesma espécie pode existir nas duas abas de forma independente.
2. **Espécies Não Descobertas (Invariante de Redação — Seção 5):**
   - Na aba `tabs.pokemon`, espécies pertencentes às gerações habilitadas que ainda não foram capturadas na categoria `normal` são entregues pelo backend **já redigidas**:
     - `nationalDexNumber`: número inteiro visível (ex.: `1`)
     - `formattedNumber`: string de 3 dígitos visível (ex.: `"001"`)
     - `discovered`: `false`
     - `silhouetteOnly`: `true`
     - `name`: `"???"`
     - `genus`: `"???"`
     - `description`: `"???"`
     - `spriteAsset`: `{ "activeKey": "pokedex/silhouette/001", "silhouetteKey": "pokedex/silhouette/001" }` (sem `normalKey` ou `shinyKey`)
     - `capture`: `null`
   - Na aba `tabs.shinies`, são listados **exclusivamente** os Pokémon shiny já capturados (`discovered: true, isShiny: true`).
3. **Localização no Jogo:**
   - Quando o adaptador determina com segurança a seção de mapa (ex.: `0x58 -> "Pallet Town"`, `0x65 -> "Route 1"`, `0x7F -> "Mt. Moon"`), o nome oficial é armazenado em `captureLocation`.
   - Quando a localização não puder ser determinada com segurança, o backend grava e retorna `"Localização desconhecida"`.

---

## 3. Endpoints HTTP/TLS, Eventos WebSocket/SSE e APIs Locais para o Codex

### 3.1 Ponte LAN (`mobile-bridge.js` — Windows ↔ iOS ↔ Android)

Todos os endpoints abaixo exigem autenticação Bearer do dispositivo pareado:

- `GET /v1/extensions`
  - Lista as extensões registradas, estado `enabled` por perfil, `uiContract` e `summary`.
- `POST /v1/extensions/:extensionId/enabled`
  - Body: `{ "enabled": true | false }`. Ativa ou desativa a extensão para o perfil ativo.
- `GET /v1/extensions/pokedex/state?platform=<ios|android|windows>&view=1`
  - Retorna o documento de sincronização (`records`, `syncRevision`, `contentSha256`) e, quando `view=1`, o objeto `view` completo já projetado e redigido para as abas `pokemon` e `shinies`.
- `POST /v1/extensions/pokedex/sync?platform=<ios|android|windows>`
  - Body: `{ "ownerProfileId": "primary", "records": [ ... ] }`.
  - Executa mesclagem determinística CRDT (união sem duplicação; em caso de conflito na mesma chave `(nationalDexNumber, category)`, vence a captura com `capturedAt` mais antigo, com desempate determinístico por `captureId`). Retorna `{ ok: true, addedCount, replacedWithEarlierCount, preservedCount, totalRecords, syncRevision, contentSha256, state, view }`.
- `GET /v1/extensions/pokedex/backup`
  - Exporta pacote completo `brum.ext.pokedex.backup` com `contentSha256` verificado.
- `POST /v1/extensions/pokedex/restore`
  - Valida o checksum `SHA-256` canônico dos registros e mescla/restaura a coleção.

### 3.2 Eventos em Tempo Real (WebSocket `/v1/ws` e SSE `/v1/events`)

- **`pokedex_discovery`:** emitido exclusivamente na **primeira** captura de cada `(nationalDexNumber, category)`:
  ```json
  {
    "type": "pokedex_discovery",
    "eventId": "pokedex-discovery:primary:25:normal",
    "discovery": {
      "eventId": "pokedex-discovery:primary:25:normal",
      "type": "pokedex_discovery",
      "extensionId": "brum.ext.pokedex",
      "ownerProfileId": "primary",
      "nationalDexNumber": 25,
      "formattedNumber": "025",
      "speciesName": "Pikachu",
      "category": "normal",
      "isShiny": false,
      "spriteAsset": {
        "normalKey": "pokedex/normal/025",
        "shinyKey": "pokedex/shiny/025",
        "activeKey": "pokedex/normal/025"
      },
      "gameTitle": "Pokémon FireRed Version",
      "gameId": "classic-firered",
      "systemId": "gba",
      "capturedAt": "2026-11-22T10:00:00.000Z",
      "captureLocation": "Viridian Forest",
      "title": "Novo Pokémon descoberto!",
      "headline": "025 — Pikachu",
      "subtitle": "Registrado na Pokédex Universal"
    }
  }
  ```
- **`pokedex_synced`:** emitido quando a coleção do perfil é atualizada por sincronização ou restauração.

### 3.3 Pontos de Entrada por Plataforma para a Fase 3 (Codex)

- **Windows (Electron Main / IPC):**
  - `ipcRenderer.invoke('extensions:list')`
  - `ipcRenderer.invoke('extensions:set-enabled', { extensionId: 'brum.ext.pokedex', enabled })`
  - `ipcRenderer.invoke('pokedex:get-view', { platform: 'windows' })`
  - `ipcRenderer.invoke('pokedex:export-backup')` / `ipcRenderer.invoke('pokedex:restore-backup', bundle)`
  - Evento IPC para popup no desktop: `'extensions:pokedex-discovery'`
- **iOS (`ios/BRUMCLASSICSMobile/Extensions/`):**
  - `PokedexUniversalStore.projectedView(profileID:platform:)` -> retorna `PokedexProjectedView` (`tabs.pokemon`, `tabs.shinies`, `summary`).
  - `PokedexUniversalStore.recordCapture(...)` e notificação local `NSNotification.Name("BrumPokedexCaptureDetectedNotification")` emitida automaticamente por `BrumLibretroEngine.mm` ao detectar captura no mGBA.
  - `BridgeClient.fetchPokedexState(platform:)`, `BridgeClient.syncPokedex(_:platform:)`, `BridgeClient.exportPokedexBackup()`, `BridgeClient.restorePokedexBackup(_:)`.
- **Android (`com.brumclassics.mobile.extensions`):**
  - `PokedexUniversalStore` + `PokedexUniversalEngine` (`projectView()`, `recordCapture(...)`, `mergeSyncPayload(...)`, `toSyncStateJson()`).
  - `BrumCoreBridge.drainPokedexCaptures()` retorna capturas detectadas pelo núcleo nativo (`libbrumcore.so`).
  - `BridgeClient.fetchPokedexStateBlocking(...)` e `BridgeClient.syncPokedexBlocking(...)`.

---

## 4. Fontes de Dados e Licenciamento

- **Catálogo de Espécies (`pokedex-species-catalog-v1.json`, 802 espécies da 1ª à 7ª geração):** gerado deterministicamente por `scripts/generate-pokedex-catalog.py` a partir das tabelas CSV do projeto `PokeAPI/pokeapi` (<https://github.com/PokeAPI/pokeapi>, licença **BSD-3-Clause**). Nenhum sprite binário proprietário de terceiros é embutido no repositório.
- **Estruturas Técnicas de Memória/Save Gen 3 (`PokemonFireRedAdapter.hpp/.cpp`):** implementação própria em C++17 somente leitura baseada na documentação técnica pública do projeto `pret/pokefirered` (<https://github.com/pret/pokefirered>).

## Limites da versão piloto e integridade v1

O catálogo offline de 802 espécies fornece dados para a coleção e não certifica 802 jogos. O adaptador de captura ativo é somente o piloto FireRed BPRE; fixtures sintéticas e boot não substituem captura interativa validada no aparelho. A data indica o primeiro registro observado, não uma recuperação da data histórica de captura. A arte exibida é estilizada.

O hash v1 conserva os 10 campos e o timestamp ISO válido recebido, incluindo sua precisão e offset; não converter `Z` para `.000Z`. As entradas rejeitam `|`, CR e LF nos campos usados pelo hash. Empates no instante (milissegundos) usam `captureId`, sem comparar a grafia do timestamp. A mesclagem valida todo o lote e o perfil de cada registro antes de alterar a coleção; confirmação em memória ocorre depois da persistência. Popups remotos respeitam o estado habilitado e o perfil local e não reaparecem para registros duplicados.

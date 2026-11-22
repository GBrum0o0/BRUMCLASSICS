# BRUMCLASSICS MÓVEL iOS 0.25.0 — Atualizações pelo iPhone com SideStore

- **Fonte oficial SideStore:** disponibiliza `sidestore-source.json` na branch `sidestore-source` apontando exclusivamente para as releases oficiais `ios-v*` verificadas no GitHub (nunca `/releases/latest` de PC/Android), com versão, build (`58`), `minimumOsVersion` (`16.0`), tamanho em bytes e `SHA-256` validados após publicação do `.ipa`.
- **Integração no Perfil do iPhone:** adiciona o botão **Verificar atualização**, consulta prioritária à fonte SideStore (com fallback seguro para `ios-update.json`), detecção do esquema `sidestore://` e encaminhamento para adicionar a fonte ou enviar o `.ipa` ao SideStore mantendo o download para Sideloadly.
- **Backup de migração com integridade verificada:** permite exportar e restaurar saves integrados (`IntegratedEmulator/Saves`) e vínculos JSON (`ClassicsEverywhere`) com conferência `SHA-256` e cópia preventiva antes de trocar do Sideloadly para o SideStore.

**Validação:** geração e validação da fonte SideStore (`test_sidestore_source.py`), parser Swift + deep links e backup/restauração verificados (`SnapshotTests`), validação do pacote (`validate_ipa.py`) e simulador/compilação no workflow passam em CI; instalação no SideStore real, renovação com StosVPN e atualização sem PC aguardam validação em iPhone físico.

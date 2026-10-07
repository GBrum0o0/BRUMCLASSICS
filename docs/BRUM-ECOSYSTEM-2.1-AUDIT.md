# Auditoria inicial — Brum Classics / Brum Core 2.1 Beta

Esta auditoria precede mudanças de arquitetura. A linha `codex/brum-backends` é experimental; `main` e as releases Stable não devem ser promovidas ou substituídas sem validação e aprovação do usuário. O código-fonte do Launcher PC está fora deste repositório público Mobile; não editá-lo como se fosse uma branch Beta nem publicar seu código por acidente.

## Mapa de execução existente

| Responsabilidade | Implementação atual | Reutilização / risco |
| --- | --- | --- |
| Launcher PC | Electron `src/main.js`, `retro-service.js`, `classic-session.js`, serviços de biblioteca/perfil/sessão | CLASSICS executa RetroArch externo; não há host Libretro PC integrado com callbacks de vídeo/input por tela. Não confundir este fato com BRUM Core integrado Mobile. |
| Ponte PC–Mobile | `src/mobile-bridge.js`, `mobile-tls.js`; protocolo 10; HTTPS com certificado fixado, pareamento por QR/código, bearer token por dispositivo, WebSocket de eventos | Reutilizar autenticação, identidade do dispositivo pareado, snapshot, eventos e comando `bcard_launch`. Não abrir comandos Gamepad/saves a qualquer host na LAN. |
| Biblioteca/metadata | Snapshot PC `safeGame`, perfis, sessões, conquistas, coleções e atividade; Mobile mantém snapshot offline | `lastPlayedAt`, horas e conquistas já existem. O vínculo automático Mobile↔PC por título em `PocketClassicsStore.launcherGame(for:)` não prova identidade da ROM e não pode autorizar save sync. |
| iOS Mobile | SwiftUI `GamingModeView`, `GameDetailView`, `PocketClassicsStore`, `AppStore`, `BridgeClient`, `EmulationFoundation`, `BrumLibretroEngine` | Card de ROM pode iniciar direto; Launcher card abre painel. BRUM Core calcula SHA-256 e salva SRAM sob `Saves/<sistema>/<hash>.srm` com manifesto. DS/3DS têm atlas/ScreenManager locais, não transporte PC. |
| Android Mobile | `MainActivity`, `ClassicsRepository`, `BridgeClient`, `IntegratedEmulatorActivity`, `SaveManifestStore` | Gaming Mode já abre detalhe, mas separa jogos PC/locais. ROM integrada possui SHA-256, save `.srm` e manifesto. Paridade com iOS deve ser reavaliada antes de 2.1.0. |
| Saves PC | `save-backup-service.js` registra caminhos manuais, versões com SHA-256 e perfil; `main.js` registra automaticamente `resumeInfo().stateDirectory` | Essa automação cobre `retro-states` (save states), não SRAM/EEPROM/Flash/memory card. `restore()` copia diretamente ao destino e não é transação atômica. Não reutilizar como sincronização nativa sem adaptador e proteção. |
| Perfil portátil PC | `portable-profile-service.js` produz `.brumprofile` criptografado | Dados de perfil e biblioteca, não arquivo de save nativo. Arquivo de saves separado deve manter vínculo e caminho de recuperação. |
| Conquistas | RetroAchievements PC em `retro-service.js`; dados móveis em snapshot e progresso local iOS | Save sync não pode depender de estados rápidos nem burlar Hardcore. Mostrar apenas dados comprovados. |
| Descoberta/estado | QR contém host/alternativos, porta e pin; `AppStore.connection`/`syncState` Android vêm da ponte | Indicador do Gaming Mode deve usar essa fonte, não inventar probe paralelo. |

## Lacunas funcionais que impedem declarar os pilares concluídos

1. Identidade de ROM PC precisa ser calculada e comparada com `CanonicalGameIdentity` iOS / `EmulationIdentity` Android. ID da biblioteca ou título não bastam. Arquivos compactados/discos podem requerer identidade canônica de conteúdo, formato e revisão.
   A auditoria encontrou divergência concreta: Android devolve a própria extensão como `systemId` para `.smc`, `.gen`, `.z64` e `.v64`, enquanto iOS normaliza respectivamente para `sfc`, `md` e `n64`. Alterar IDs persistidos Android sem migração quebraria saves existentes. Foi adicionado `portableGameId` para normalizar a comparação futura sem alterar o ID persistido; ainda falta usar esse identificador no protocolo de sync e validar os formatos de disco.
2. Falta um `SaveAdapter` PC por core/formato que encontre o save persistente nativo, faça flush seguro e separe explicitamente save state. A maioria dos sistemas pesados não usa apenas `RETRO_MEMORY_SAVE_RAM`.
3. Falta protocolo autenticado de manifestos/revisões, ancestralidade, conflitos, transferência temporária validada e aplicação atômica fora de sessões ativas. Backup e sync devem permanecer entidades distintas.
4. Falta um host PC capaz de fornecer tela secundária e aceitar input/touch em tempo real. A sessão Sunshine/Moonlight existente transmite o jogo inteiro e não satisfaz a segunda tela interativa DS/3DS.
5. Falta API de extensões versionada com capacidades/permissões e sandbox. Uma tela de Gamepad sem backend não satisfaz o pilar.
6. O Gaming Mode atual expõe detalhes técnicos e separa PC/Local. O iOS ainda tem toque em cartão local que pode abrir execução diretamente. Redesign precisa manter rotas de execução e integração existentes, sem dizer que Gamepad está pronto antes de haver sessão real.
7. Lançamento 2.1.0 requer paridade e testes reais em iOS, Android e Launcher. Builds/testes locais não demonstram LAN, áudio/vídeo/touch, instalação ou restauração após falha.

## Sequência segura e critérios de prova

1. Preservar Stable e criar uma linha Beta versionada para qualquer alteração ao Launcher PC antes de editar as fontes Stable. Não copiar fontes privadas para o repositório público Mobile.
2. Consolidar identidade por hash e adaptadores de save nativo; testes de mismatch, interrupção, corrupção e conflito precedem escrita remota.
3. Estender a ponte autenticada existente com capacidades/versionamento, separando controle de transferência/stream. Input deve ter sequência, timeout e liberação no disconnect.
4. Integrar Game Detail e Gaming Mode aos metadados reais, preservando os comandos de abrir no PC e o streaming atual. Gamepad só deve ser acionável quando a sessão complementar for funcional.
5. Validar ida e volta de save, backup, restore e conflito em dois dispositivos; DS/3DS com vídeo secundário, toque e controle virtual em LAN; regressão de perfis, conquistas, biblioteca e lançamento atual.

## Correção isolada iniciada no Launcher Beta local

Na cópia Beta local do Launcher PC (Git sem remoto), a restauração de `save-backup-service.js` agora verifica todos os hashes antes de tocar no save atual, exige que a cópia pré-restauração tenha êxito, rejeita restauração durante jogo ativo, prepara arquivos temporários e usa journal para reverter operação interrompida. Os testes cobrem sucesso, backup adulterado, sessão ativa e recuperação após interrupção.

O Launcher Beta também consulta, em tempo de execução, `GET_CONFIG_PARAM savefile_directory` na interface UDP local do RetroArch e procura somente arquivos persistentes com o nome exato do conteúdo e extensões nativas conhecidas (como `.srm`/`.rtc`). Arquivos ambíguos, compartilhados ou específicos de core não são atribuídos automaticamente. O registro e o manifesto do backup agora distinguem `native`, `savestate` e `manual`, preservando o backup anterior de estados. Novos backups automáticos também recebem um `canonicalGameId` calculado por SHA-256 do conteúdo quando possível; CUE/GDI/M3U seguem a mesma ordem de arquivos e prefixo versionado do iOS. Isso **não** demonstra ainda compatibilidade entre todas as identidades PC/iOS/Android, transporte autenticado, resolução de conflito ou suporte a memory cards de cores pesados. A detecção de save nativo e a identidade de disco precisam de teste com RetroArch e ROMs reais antes de serem liberadas.

Status: **auditoria inicial e hardening em Beta; nenhum dos três pilares foi certificado de ponta a ponta**.

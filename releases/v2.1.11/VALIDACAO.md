# Validação — Windows 2.1.11 experimental

Correções locais GBA sobre 2.1.10, na cópia isolada de integração. Não substitui a árvore de trabalho do Antigravity nem incorpora fontes adicionais que ele possa alterar posteriormente. Publicação solicitada pelo usuário após o aviso de que ainda existem defeitos gráficos e sonoros.

Fonte interna verificada: `1cdd6834eb3ea32cb053b86e5c114723589551ce`; árvore `4c4b3bd8d0f65c401fc9699c9d73dc7c59f99f0f`. Versão 2.1.11, brumEdition official e brumStage experimental; distribuição empacotada no formato já usado pelo atualizador.

## Verificação do core

- 270 testes nativos aprovados, incluindo 17 regressões novas com reprodução antes da correção: IRQ/MSR, Flash128, prioridades, affine BG/OBJ, clock/roteamento/FIFOs, timers e invariância do PCM ao agrupamento de ciclos.
- Suíte geral: 838 testes, 837 aprovados, zero falhas e um teste opcional ignorado. Sintaxe aprovada.
- Host/captura: 11 testes aprovados, incluindo programação e reabertura de um snapshot Flash de 128 KiB por ROM sintética autoral; cópia SRAM independente e ROM preservadas.
- Compilação nativa e host com MSVC C++17, /W4 e /WX.
- Emerald e FireRed executaram 1.200 frames cada no host real, código de saída zero e framebuffer capturado, sem dispositivo de áudio nem saves preexistentes. O probe separado também capturou PCM e verificou o SHA256 das ROMs sem alteração.
- Emerald saiu da tela branca após identificar corretamente a Flash. O host mostrou as introduções; a execução instrumentada com Start também avançou à sequência do título. As capturas ainda apresentam falhas.

Não houve validação auditiva por alto-falantes, gameplay inteiro, batalha ou salvamento dentro dos próprios Pokémon. A persistência foi verificada por fixture sintética, não inferida do log de encerramento dos jogos. Não há parecer independente final limpo: o revisor foi interrompido pelo limite de uso.

## Preservação e pendências

Originais, perfis e Vault não foram usados como área de teste. Nenhum arquivo pessoal é distribuído. Snapshot SRAM antigo não é convertido silenciosamente em Flash128; incompatibilidade bloqueia restauração e preserva o arquivo. O novo formato é separado e mantém os dois bancos.

Permanecem janelas/alpha/fades incompletos, precisão por linha/latches afins pendente, casos especiais OBJ/bitmap, PSG wave/noise/envelope/sweep/length e mixer/PWM incompletos, Flash64/EEPROM não adicionados e limitações preexistentes dos outros sistemas. Não anunciar GBA nem os 32 consoles como concluídos.

## Pacote e distribuição

- Build Windows x64 concluída com código zero. Portátil versão 2.1.11, 394.356.943 bytes.
- 188 arquivos de fonte do ASAR conferidos contra a fonte interna. Dependências isoladas (QR, ZIP, Three.js, WebSocket), sessão JS/nativa e save sintético aprovados.
- App-ready, página do jogo e Steam preservados; primeiro acesso/reabertura/novo download, BRUMWORLD e sentinela de perfil passaram em diretórios temporários. O wrapper de boot registrou aviso BigInt ao inspecionar o caminho virtual; o teste independente de primeiro acesso com arquivo executável regular passou.
- ASAR e host extraídos diretamente do portátil têm os mesmos hashes dos recursos verificados. O extrator reportou o aviso esperado de dados após o arquivo autoextraível, não falha de integridade.
- Portátil SHA256: `a64563e02ae2d793dc133ec1a73b506411be97d054b9a4ff0a479dc329595382`.
- ASAR SHA256: `b36a2087fc9edab3cb6fab17b26598606f48a19b39b7a19baf287b8a7b5dbca3`.
- Host SHA256: `a1fb4962bda453018e7ccd2ef24b338795fef9f1b44f35fb136c8f2e83536eb3`.

## Publicação e atualização ao vivo

Release `v2.1.11` publicada como Latest oficial, não rascunho e não prerelease, no commit público `86107dd9d7ddcec5afac8269f1651c2c04ea7962`. Os três anexos (portátil, notas e SHA256SUMS) tiveram tamanho e digest SHA256 confirmados na API antes da publicação. Estágio experimental permanece explícito.

O serviço real de atualização, simulando 2.1.10 em perfil temporário, detectou 2.1.11 e baixou os 394.356.943 bytes, chegando a `ready / 100%`, com SHA256 `a64563e02ae2d793dc133ec1a73b506411be97d054b9a4ff0a479dc329595382`. Seleção pela ponte 2.1.0-beta.3 também compatível. Sentinela de perfil preservada. Não foi chamada instalação nem reiniciado o Launcher pessoal; a aplicação da atualização depende da confirmação do usuário.

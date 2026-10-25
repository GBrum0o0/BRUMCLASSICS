# Validação — Launcher PC 2.1.6

## Procedência

- Fonte limpa: `adc6a2cf503ba8b82b70484d052f9e6d163a4c5b`.
- Árvore: `20c5c3e90689aa0a0f8b7f0a9312d202e585df7e`.
- Módulos autorais importados do snapshot Antigravity `1eb2710d4fbf0275750b1cbeac687cc325e0e175`; integração e host compilados nesta entrega.
- Windows x64, versão 2.1.6, edição técnica distribution, marca OFICIAL, estágio experimental.

## Evidências locais

- Suíte completa: 833 testes, 832 aprovados, zero falhas, um ignorado por exigir DLL libretro real opcional, fora do caminho M.U.R.B.
- Verificação sintática e build de distribuição concluídas com código de saída zero.
- Testes nativos autorais: 236/236 aprovados; `gameplayReady=false` permanece explícito.
- Host compilado com avisos tratados como erros. Adaptadores de controles, roundtrip de save GB/GBC e execução sintética NES verificados; Start NES reproduzido em falha e corrigido antes da validação final.
- Electron real: 32 módulos apresentados como experimentais, somente ação autoral, zero consultas a estado externo no lançamento, duas capturas de interface.
- ASAR: 188 fontes correspondentes à árvore limpa. Dependências testadas em cópia isolada, sem node_modules do desenvolvimento.
- Serviço JavaScript empacotado abriu o host nativo empacotado e confirmou um save sintético isolado.
- Entrada principal chegou a app-ready em perfil temporário; página do jogo e integração Steam preservadas.
- Primeiro acesso testado separadamente com executável regular: abertura inicial, reabertura sem repetição, mudança da identidade no mesmo caminho e perfil preservado. O wrapper de entrada principal apresenta aviso BigInt no teste de identidade; não substitui esse teste separado nem valida instalação pessoal.
- ASAR e host extraídos diretamente do portátil conferidos contra os arquivos verificados de produção.

## Artefatos

- Portátil: 394298562 bytes; SHA-256 `22c508447a65137e95132acc530b051f046efc09b5ea3c671bdf31df2baa84ad`.
- ASAR: SHA-256 `9ea486d2e272001f09690a9a5c06bff7608fae580e7f47ea13d8b3484b20c285`.
- Host: SHA-256 `bb34d19475e61cc0074b57fc1f6c33ad3388890540b9374f0c13f7aedb58bfe9`.

## Revisão e limites

Revisão independente não encontrou falha crítica de integridade ou bypass para fallback. Foram corrigidos dois apontamentos importantes: aceitar extensões desconhecidas e truncar máscaras de controles dos novos módulos. Testes de regressão cobrem ambos.

Esta entrega não certifica jogos comerciais nem os 32 sistemas. São protótipos, sem garantia de gameplay; Arcade genérico permanece indisponível. Não houve teste físico de controles nem instalação sobre perfil pessoal. Leia RELEASE-NOTES.md antes de atualizar: o lançamento externo foi removido, mas seus arquivos, saves antigos e Vault foram preservados; saves de teste são isolados e não são ativados automaticamente.

Publicação e download pelo atualizador são verificações separadas, registradas após a disponibilização dos assets no GitHub.

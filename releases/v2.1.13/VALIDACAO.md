# Validação — Launcher PC 2.1.13 experimental

Fonte interna: `2e6a2221330170d6ab56daf498c069cb07d5c5c8`, árvore
`ec81dd15022207723278413a9461a709b4ab5264`. Incremento sobre 2.1.12; publicação
solicitada pelo usuário após correções e validação.

## Engine e integração

- 57 regressões adicionais sobre os 270 testes anteriores: 16 áudio, 15 composição,
  16 LCD/afim/cadência e 10 HLE. 53 tiveram RED observado antes da correção e 4 são
  controles adicionais de comportamento já correto.
- Runner direcionado: 92 verificações de GBA aprovadas. Build nativo completo
  MSVC `/W4 /WX`: 327 testes aprovados, `gameplayReady=false` mantido.
- Suíte do Launcher: 847 testes, 846 aprovados, zero falhas e um opcional ignorado.
  Sintaxe aprovada. Inclui o fluxo de recuperação de snapshots antigos com
  preservação do original e backup, fixtures de persistência e captura real.
- Revisões independentes de áudio, composição/LCD e HLE/afim. Erros encontrados
  no clock de ruído, latches DMA, recarga HBlank e contagem HLE foram corrigidos
  com regressões. Pedidos HLE acima de 65.536 cálculos são recusados antes de escrever,
  não truncados silenciosamente.
- APU/compositor são autorais. Seno Q14 gerado matematicamente para os contratos
  HLE; não contém BIOS/tabela extraída de Nintendo ou código de emulador externo.

## ROMs reais, somente leitura

Execução de 2.400 frames por jogo, com Start nos frames 900/1800 e A nos 2100/2250, sem
carregar saves originais. Hash antes/depois idêntico em ambas as ROMs.

- Emerald: título com logo completo de Pokémon e avanço para New Game/Option.
- FireRed: título e avanço para a tela de instruções.
- PCM: 1.928.520 frames estéreo por jogo, a 48 kHz. Contagem não comprova fidelidade
  musical; valores no extremo não são, isoladamente, prova de clipping indevido.
- Host real Windows, janela oculta, áudio aberto: 360 frames desenhados por jogo,
  `audioDevice=1`, 289.074 frames PCM enviados, captura 240×160 e encerramento 0.

`saveCommitted=1` no host não é apresentado como prova de save dos Pokémon:
um flush pode não ter dados sujos. Persistência foi exercitada separadamente
pelas fixtures. Não houve partida completa, batalha ou save/reabertura dentro
dos jogos comerciais. Não houve escuta humana nem telemetria de underruns.

## Ressalvas e transparência

A primeira suíte concorrente teve um timeout no teste de 360 FPS; 25 testes direcionados
posteriores passaram e a suíte completa final passou. Um teste editorial detectou
BRUMNEWS ainda marcando 2.1.12; o HTML foi corrigido. O primeiro pacote com HTML
anterior foi recusado pela comparação de hashes, exigindo nova geração.

Mosaic, timing/raster, alguns detalhes de PSG e PWM/filtragem continuam incompletos
ou aproximados. Trigonometria HLE não cardinal não foi certificada bit a bit contra
BIOS original. Nenhuma conclusão de compatibilidade total foi inferida dos testes.

## Pacote e publicação

- Portátil Windows x64, versão 2.1.13/official/experimental, 394.376.896 bytes.
- 189 arquivos de fonte do ASAR conferidos contra a fonte interna validada.
- Dependências empacotadas e sessão/save GB sintético aprovados com JavaScript
  do ASAR e host nativo reais, sem dados pessoais.
- Recuperação GBA exercitada no pacote: cancelar preservou o SRAM original;
  confirmar criou backup idêntico e Flash128 separado aceito pelo host;
  próxima abertura reutilizou o slot. Fixtures autorais em perfil temporário.
- Inicialização app-ready, elementos Steam/detalhes e perfil isolado aprovados.
  Primeiro acesso, reabertura, novo download no mesmo caminho, BRUMWORLD e
  preservação da sentinela do perfil aprovados em teste independente.
- Wrapper de boot mantém o aviso BigInt preexistente no caminho virtual ASAR;
  o teste independente de primeiro acesso com executável regular passou.
- ASAR e host extraídos diretamente do portátil conferidos por SHA256 contra
  os recursos acima. Aviso esperado de dados adicionais do autoextraível,
  sem divergência de conteúdo.

SHA256:

- Portátil: `3af8ef01706eb2718b70978060cc1c5fdd8ec82c55cc11321fbd6f0062c749e6`.
- ASAR: `6096efa5f7466ed1a495f67e52fa6c73e1312bc5c42c83eaf02ee77a3ab405db`.
- Host: `e819c7e9cdad171c49f2acc8f720e5e29f13d3cad34e9d307d62b4a273afa67a`.

Nenhuma instalação pessoal ou reinicialização foi executada. O teste ao vivo do
atualizador só pode ocorrer após a publicação; seu resultado será registrado
separadamente, sem antecipar sucesso.

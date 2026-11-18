# BRUM Core: abertura verificável e diagnóstico local

Revisão de 13/10/2026 para o pacote experimental 0.15.1 build 48. Estes
controles diagnosticam a inicialização do host; não certificam compatibilidade
de jogos, desempenho de 3DS/GameCube ou ausência de crashes nativos.

## Comportamento implementado

- O registro verifica arquivos regulares não vazios para todos os núcleos,
  incluindo os sistemas da lista ativa. A presença autoriza uma tentativa de
  abertura; não é apresentada como execução comprovada.
- A busca de ROMs agora inclui também formatos que já possuíam rota mas eram
  omitidos pelo scanner: Arcade `.7z`, GameCube `.gcm`/`.ciso` e formatos
  adicionais de 3DS. ELF/APP/AXF continuam exigindo a pasta 3DS correspondente.
- O host distingue biblioteca ausente de biblioteca que o iOS recusou carregar.
  O erro de `dlopen`, a API e símbolos ausentes são preservados no diagnóstico.
- O formato é confrontado com `retro_get_system_info().valid_extensions` do
  núcleo efetivamente carregado. Nenhum formato é habilitado apenas pela pasta.
- A geometria distingue imagem atual de capacidade máxima anunciada. Azahar
  reserva até 7200×4800, mas o layout nativo é 400×480; isso não torna a imagem
  nativa inválida nem causa uma alocação do máximo. As verificações de alocação
  permanecem no caminho que recebe o frame efetivo.
- Avisos e erros de `GET_LOG_INTERFACE`, `SET_MESSAGE` e `SET_MESSAGE_EXT`
  sobrevivem ao encerramento. Há limite de 32 mensagens/2048 caracteres, com
  último erro preservado separadamente mesmo quando o histórico gira.
- O relatório registra fase, versão do app/core, formato/hash do conteúdo,
  núcleos de CPU disponíveis, memória física e contadores de frames/áudio.
  Amostras ausentes incluem o preenchimento inicial dos buffers; esse contador,
  isoladamente, não prova defeito de áudio ou indica uma otimização a aplicar.
- Erros do host ao reativar áudio ou recriar a saída são preservados por um
  checkpoint local, mesmo se a notificação visual desaparecer. Registrar esse
  erro não transforma a sessão de vídeo em uma falha de carregamento.
- A inicialização escreve marcadores antes de operações nativas. Uma tentativa
  anterior sem término conserva sua última fase, sem atribuir automaticamente
  a causa a crash, pressão de memória ou encerramento pelo usuário.
- Só a primeira imagem apresentada, após retorno de `retro_run` sem shutdown,
  sinaliza início à interface. Tentativas recusadas não iniciam o cronômetro nem
  entram em jogos recentes. O botão Sair também funciona após `stopCore`.
- O tempo de uma sessão integrada pode ser registrado com a pasta de logs do
  RetroArch configurada; esses logs continuam contabilizados por delta próprio.

O arquivo local fica em
`Application Support/IntegratedEmulator/Diagnostics/last-session.json`.
O app não o envia automaticamente. Em uma falha há **Copiar relatório**; tocar
no status do núcleo abre o compartilhamento explícito. Caminhos da ROM, do
pacote e do sandbox são substituídos por `<local>`. Não há bytes de ROM/BIOS,
chaves ou credenciais no contexto registrado.

## Verificação

- Testes portáteis: formatos exatos/case-insensitive e contratos A/V inválidos.
- XCTest: núcleo simulado exclusivo do simulador para recusa de conteúdo,
  extensão incompatível, timing inválido, shutdown no primeiro frame,
  sinalização de início única, produção de áudio e saída após falha.
- XCTest: retenção/redação dos relatórios, logs concorrentes limitados e
  contagem de sessão integrada independente dos logs externos.
- O probe é recurso do bundle de testes. O validador de IPA rejeita tanto esse
  dylib quanto qualquer `.xctest`, prevenindo sua distribuição ao usuário.

O contrato das mensagens segue o
[header oficial Libretro](https://github.com/libretro/libretro-common/blob/master/include/libretro.h).

## Aceitação ainda necessária

Executar ROMs legítimas em iPhone: 3DS, GameCube, Arcade e demais candidatos,
com vídeo/áudio/controles, pausa/retorno, save/reabertura e medição térmica.
Usar os relatórios para separar falha do conteúdo, do núcleo, do host ou da
plataforma. A execução ainda passa pela thread principal e o renderer GLES
ainda faz readback; esta revisão não elimina esses gargalos nem promove os
backends experimentais à lista de produção.

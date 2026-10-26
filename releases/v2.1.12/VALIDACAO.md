# Validação — 2.1.12 experimental, Windows PC

Publicação solicitada após a implementação do fluxo de recuperação de snapshots GBA incompatíveis. Correção funcional em `d6457380c32e86269c12f2575f681476837804d2`, sobre a fonte 2.1.11. Fonte final 2.1.12: `bfd521f1a32a44354418160f9952302ea96f180a`; árvore `4f1aee59797dcffe17b16080ff909cbc5207745f`.

## Escopo e evidências

- Reprodução do erro com o host real da 2.1.11, uma ROM sintética autoral Flash1M e container SRAM antigo válido de 64 KiB.
- 9 testes específicos aprovados: cancelamento, backup idêntico, Flash128 novo aceito pelo host real, reuso do arquivo na próxima abertura, corrupção/identidade estrangeira, troca de perfil/ROM/save durante consentimento, destino/backup existente, reserva de sessão, falha de perfil e limpeza de temporário em falta de espaço.
- Revisão independente somente de leitura aprovou a implementação, com um P3 de limpeza de temporário corrigido após reprodução RED/GREEN. Revisor verificou a correção e a liberação da reserva em falha de perfil, executando os dois testes direcionados.
- Suíte geral reexecutada sobre 2.1.12: 847 testes, 846 aprovados, zero falhas e um teste opcional ignorado; sintaxe aprovada, incluindo o módulo novo.
- Vault e sua lista de formatos aceitos não foram ampliados; core nativo não sofreu mudanças nesta correção.
- O original não é movido, apagado ou convertido. O novo slot só é criado após confirmação explícita, backup exclusivo/sincronizado e verificação de hash. Incompatibilidades fora do caso elegível continuam bloqueadas.
- O novo slot usa publicação exclusiva por hard link em um staging sincronizado do mesmo volume. Sistemas de arquivos sem esse recurso abortam com os dados antigos preservados, sem fallback de sobrescrita.

A interação física do usuário com o diálogo nativo não é apresentada como teste automatizado. As opções de confirmação e seu padrão de cancelamento foram verificadas, e a transição completa do serviço foi exercitada com o host real. Gameplay, fidelidade de áudio/vídeo e conversão do progresso não fazem parte desta validação.

## Pacote e atualização

- Build Windows x64 concluída, versão 2.1.12/experimental, portátil de 394.367.755 bytes. 189 arquivos de fonte do ASAR correspondem às fontes internas.
- JavaScript empacotado e host nativo exercitados com snapshot SRAM legado sintético: cancelar preservou o original; confirmar criou backup idêntico e slot Flash128 aceito pelo host; próxima abertura reutilizou o slot sem novo consentimento. ROM e arquivo original permaneceram idênticos. Perfis temporários, sem dados pessoais.
- Dependências QR/ZIP/Three.js/WebSocket, sessão GB/save sintético, inicialização app-ready e preservação de Steam/página do jogo aprovadas.
- Primeiro acesso, reabertura, novo download no mesmo caminho, BRUMWORLD e sentinela do perfil aprovados. Wrapper de boot apresentou o aviso BigInt já conhecido ao usar o caminho virtual; teste independente de primeiro acesso com executável regular passou.
- ASAR e host extraídos diretamente do portátil correspondem aos recursos verificados. Aviso esperado de dados adicionais após o arquivo autoextraível, sem divergência de hash.
- Portátil SHA256: `bb86d9ea6e5a903d61db3b04d438cbca982926caf5ed76836bf16e21939f61a6`.
- ASAR SHA256: `de62f18c78dd51bdc1c81a02ce889bd412fc876db83cb36bc3df6fb3b13f5f41`.
- Host SHA256: `b6cd78a499fee0695071e104c6a30cda2f3a98da0cccac85694160a86b6c110c`.

Resultados de publicação e atualização ao vivo serão registrados após confirmação. Nenhuma instalação pessoal foi autorizada ou executada.

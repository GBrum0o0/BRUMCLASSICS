# BRUMCLASSICS 1.72.0 — Conexões previsíveis

Esta atualização torna as integrações mais claras, estáveis e honestas sobre os recursos disponíveis em cada loja.

- Cada loja diferencia conexão ativa, cliente não encontrado, login necessário, biblioteca preservada no cache, sincronização parcial e monitoramento local ativo.
- A tela de detalhes mostra a última sincronização bem-sucedida, a quantidade de jogos e separa propriedade confirmada, instalação detectada, assinatura, Família Steam e registro local.
- O novo botão **DIAGNOSTICAR CONEXÃO** verifica cliente, acesso, biblioteca, origem dos jogos e monitoramento, apresentando uma orientação direta sem logs técnicos.
- A reautenticação é guiada para Steam, Epic, GOG e EA conforme o mecanismo seguro disponível.
- Uma fila central impede que duas lojas reconstruam a biblioteca simultaneamente; nenhuma solicitação é descartada se outra estiver em andamento ou falhar.
- Sincronizações estáveis atualizam somente os cartões modificados. A grade completa só é reconstruída quando jogos entram, saem ou mudam de posição.
- O último snapshot válido permanece carregado quando uma loja ou credencial falha, preservando coleções, favoritos, capas e demais dados locais.
- Steam continua usando APIs públicas; Legendary permanece identificado como terceiro; integrações locais não recorrem a endpoints privados.
- A BRUMWORLD foi atualizada para explicar os novos estados, o diagnóstico e a preservação do catálogo.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações de código ou protocolo nesta atualização exclusiva do launcher Windows.

Validação: 634 testes automatizados aprovados, zero falhas, fluxo visual completo de Conexões aprovado, auditoria de dependências sem vulnerabilidades e comparação integral dos 131 arquivos de `src` no pacote ASAR.

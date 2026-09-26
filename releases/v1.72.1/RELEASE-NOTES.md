# BRUMCLASSICS 1.72.1 — Instalação Steam corrigida

Esta atualização corrige falsos erros de instalação em jogos da Steam que já estão baixados e prontos para jogar.

- O launcher verifica primeiro o estado oficial do manifesto, a pasta instalada e o executável local.
- Contadores históricos de download mantidos pela Steam não substituem uma instalação já confirmada.
- A estimativa de pouco espaço passa a ser apenas um aviso durante uma transferência, sem criar um erro terminal por conta própria.
- Antes de mostrar um erro informado pela loja, o launcher realiza uma última verificação local de integridade.
- Erros antigos de instalação deixam de aparecer assim que o jogo é reconhecido como íntegro.
- O caso real do Counter-Strike 2 com manifesto instalado e contadores antigos recebeu um teste de regressão dedicado.

Android 0.20.0 e iOS 0.11.0 permanecem compatíveis e não receberam alterações nesta atualização exclusiva do launcher Windows.

Validação: 637 testes automatizados aprovados, zero falhas, dependências de produção sem vulnerabilidades conhecidas e comparação integral dos 131 arquivos de `src` no pacote ASAR.

# BRUMCLASSICS OFICIAL 1.74.1

Esta correção estabiliza a biblioteca durante a rolagem, especialmente para contas com centenas de jogos.

## Correções

- Os cartões já exibidos permanecem montados ao subir ou descer.
- Novos jogos são acrescentados progressivamente em páginas de 24.
- A grade não é mais reconstruída continuamente pelo scroll.
- A ordem visual não depende mais de uma estimativa de colunas diferente do grid real.
- Capas carregadas permanecem visíveis e animações de entrada não são repetidas.
- Atualizações incrementais de um jogo também evitam repetir a animação do cartão.

O teste visual usou uma biblioteca simulada com 240 jogos, carregou 144 cartões durante a rolagem e confirmou ordem estável, identidade preservada, ausência de duplicatas e nenhuma reconstrução dos primeiros cartões.

Android 0.20.0 e iOS 0.11.0 continuam compatíveis e não foram alterados.

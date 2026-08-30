# BRUMCLASSICS OFICIAL 1.45.5 — Correção da tela preta

Esta é uma correção emergencial para a tela preta que podia ocorrer ao iniciar a versão 1.45.4.

## Causa corrigida

O modelo do novo sorteador e o renderer declaravam `drawRecommendationWithoutRepeat` no mesmo escopo global. O navegador interrompia o carregamento do renderer antes de liberar a interface, mantendo somente o fundo preto.

## Alterações

- A referência interna do renderer agora usa um nome isolado, sem colisão global.
- O ciclo sem repetição de **O que jogar agora?** permanece integralmente ativo.
- Um novo teste compila em conjunto todos os scripts globais na mesma ordem do HTML.
- A suíte completa passou com 390 testes.
- BRUMNEWS e a linha do tempo foram atualizadas.

Nenhum cache, conta, biblioteca, coleção, favorito, capa personalizada, anotação, save ou caminho pessoal é apagado ou recriado.

O BRUMCLASSICS MOVEL permanece na versão 0.10.1 porque esta correção é exclusiva do launcher Windows.

## Arquivos

- `BRUMCLASSICS OFICIAL.exe` — executável de nome fixo usado pelo atualizador e pela barra de tarefas.
- `BRUMCLASSICS-OFICIAL-1.45.5-portable.exe` — cópia versionada compatível.
- `BRUMCLASSICS-OFICIAL-1.45.5-COMPLETO.zip` — pacote público limpo com RetroArch, RETROGAMES vazia e APK.
- `BRUMCLASSICS-MOVEL-0.10.1-debug.apk` — aplicativo Android complementar.
- `SHA256SUMS.txt` — hashes SHA-256 dos arquivos publicados.

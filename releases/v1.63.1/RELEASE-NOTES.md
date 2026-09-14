# BRUMCLASSICS 1.63.1 — Inicialização responsiva

Esta atualização corrige prioritariamente o estado **“Não respondendo”** observado após a preparação integral de conquistas da versão 1.63.0.

## Correções

- O loading inicial não fica mais sempre acima das outras janelas e é exibido sem tomar o foco.
- O launcher é liberado após no máximo seis segundos de preparo de conquistas.
- Consultas restantes continuam em segundo plano e preservam o cache local solicitado.
- Migrações de pontuação são consolidadas em uma única atualização de perfil.
- Catálogos localizados em massa são persistidos em lotes, sem regravar o arquivo inteiro a cada jogo.
- Perfis válidos deixam de ser regravados desnecessariamente em toda abertura.
- A associação por título usa um índice linear em vez de comparar cada conquista com todas as demais.

## Resultado medido

No perfil real usado para validar a falha — aproximadamente 17 MB, 349 jogos com catálogo e mais de 21 mil conquistas — a projeção completa caiu de cerca de **24 segundos para 135 ms**. Em um teste real de abertura, a janela apareceu no quinto segundo, marcou a inicialização como pronta no sexto e permaneceu respondendo durante mais 30 segundos de sincronização em segundo plano.

Android 0.19.0 e iOS 0.10.0 não precisam de atualização para esta correção exclusiva do launcher Windows.

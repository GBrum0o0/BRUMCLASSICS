# BRUMCLASSICS OFICIAL 1.49.1 — Primeiro acesso, CLASSICS e navegação

Esta é a versão recomendada após a validação final da 1.49.0. Inclui todos os recursos da atualização: primeiro acesso Steam + BRUMWORLD, correção dos botões X, identificação de ROMs por hash e Voltar no aplicativo Android.

## Correções finais

- Indisponibilidade do catálogo RetroAchievements passa a ser erro temporário, sem apagar o progresso válido já sincronizado.
- Hash de ROM incompatível não recebe associação apenas porque o título é idêntico. O fallback por título fica restrito aos formatos sem algoritmo de hash implementado no launcher.
- Diálogos seguem a ordem real de abertura, e não a posição no HTML. Escape fecha apenas a camada superior e o foco retorna ao controle anterior.
- MOVEL 0.13.1 alinha os dois manifestos Android, usa versionCode 20 e habilita Predictive Back no manifesto efetivamente usado pelo build.
- O build do APK verifica os metadados compilados, impedindo publicar uma versão incompatível com a atualização instalada.

## Como usar

No primeiro acesso, conecte a Steam com os links oficiais, abra a BRUMWORLD ou continue sem conta. Para rever o guia: **Configurações → Conexões → Abrir guia de primeiro acesso**.

Para CLASSICS: atualize a biblioteca ou as conquistas. A Web API Key importa progresso; para desbloquear durante o jogo, autentique também o **login de execução** do RetroAchievements. ROMs precisam corresponder a um hash aceito pelo conjunto oficial. Renomear o arquivo não resolve incompatibilidade de dump, revisão ou tradução.

No celular: Voltar retorna dos detalhes, B-CARD e BRUMMOMENTS, limpa pesquisa/filtros e volta à Início. Na Início, dois toques dentro de 1,8 segundo encerram o app.

## Preservação e atualização

Contas, biblioteca, coleções, favoritos, capas, mídias, notas, saves e configurações são preservados. Atualize o desktop em **Configurações → Sistema → Atualizações** e o celular em **Perfil → Atualizações**. Instale o APK 0.13.1 sobre o anterior, sem desinstalar.

Também inclui o B-CARD: um gesto para cima envia ao computador pareado o jogo instalado escolhido no celular. O desktop valida a solicitação e CLASSICS permitem Novo jogo, autosave ou save manual.

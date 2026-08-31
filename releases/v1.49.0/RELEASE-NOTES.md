# BRUMCLASSICS OFICIAL 1.49.0 — Primeiro acesso e CLASSICS confiáveis

## Primeiro acesso

- Perfis novos recebem uma tela direta com conexão Steam e acesso à BRUMWORLD.
- SteamID64 e Web API Key possuem links oficiais dentro do fluxo; falhas mantêm os dados preenchidos para nova tentativa.
- A Steam é recomendada, nunca obrigatória. O usuário pode continuar somente com CLASSICS ou jogos manuais.
- O guia pode ser reaberto em **Configurações → Conexões**.

## RetroAchievements nos CLASSICS

- A identificação principal passa a usar o hash da ROM segundo as regras oficiais do RetroAchievements.
- GB/GBC/GBA, NES, SNES, Nintendo 64, Nintendo DS, Mega Drive e Arcade recebem tratamento específico.
- A associação por título permanece somente como fallback conservador e recusa resultados ambíguos.
- Jogos sem ID são reprocessados mesmo quando o arquivo da ROM não mudou.
- Limites e falhas temporárias da API usam retentativas, não apagam progresso válido e voltam a ser tentados em outro boot.
- A interface separa ROM não reconhecida, título ambíguo, plataforma sem suporte e indisponibilidade temporária.
- Arquivos ISO deixam de ser classificados automaticamente como PSP; assinaturas conhecidas de PSP, PS1 e PS2 são inspecionadas.

Uma ROM pode continuar sem conquistas quando seu dump ou tradução não corresponde a um hash aceito pelo conjunto oficial. O launcher informa esse estado; não cria uma associação falsa pelo nome.

## Voltar e botões X

- Todos os botões X dos diálogos possuem fechamento delegado comum.
- Escape fecha somente a camada que está no topo.
- Diálogos de início de CLASSICS e configuração de controle cancelam corretamente suas ações pendentes.
- BRUMCLASSICS MOVEL 0.13.0 faz Voltar retornar por detalhes, B-CARD, BRUMMOMENTS, pesquisa, filtros e abas. Na Início, dois toques encerram o aplicativo.

## B-CARD incluído nesta publicação

- Jogos confirmados como instalados aparecem em uma área própria da Início do celular.
- Um gesto para cima envia uma solicitação autenticada; o launcher revalida o jogo antes de abrir.
- CLASSICS mantêm as escolhas Novo jogo, autosave e save manual.

## Preservação

Contas, biblioteca, coleções, favoritos, capas, mídias, anotações, saves, save states, configurações e caminhos não são limpos nem recriados. A edição pública continua usando um perfil `distribution` isolado do perfil pessoal `official`.

## Instalação

Use **Configurações → Sistema → Atualizações** no launcher ou baixe o executável fixo da Release. No Android, instale o APK 0.13.0 sobre a versão anterior para manter cache offline, galeria, anotações e pareamento.

# Histórico de versões

## 1.49.1 — Proteções da validação final

- Catálogo RetroAchievements indisponível preserva o progresso em cache.
- Hash incompatível não é substituído por título semelhante.
- Pilha real de diálogos e restauração de foco; 18 diálogos verificados no Electron.
- APK MOVEL 0.13.1 usa versionCode 20 e Predictive Back no manifesto real de build.
- Build confere manifesto, Gradle e metadados do APK para prevenir divergências.
- Inclui todas as novidades 1.49.0: primeiro acesso Steam + BRUMWORLD, Voltar e B-CARD.

Veja [notas e orientações](releases/v1.49.1/RELEASE-NOTES.md).

## 1.49.0 — Primeiro acesso e CLASSICS confiáveis

- Primeiro acesso por perfil apresenta a conexão Steam e a BRUMWORLD sem obrigar vinculação.
- Links de SteamID64 e Web API Key usam somente páginas oficiais permitidas.
- ROMs CLASSICS são identificadas prioritariamente pelos hashes oficiais do RetroAchievements.
- Sistemas com formatos próprios recebem normalização de hash; ISO deixa de significar PSP automaticamente.
- Falhas temporárias usam retentativa e preservam o último progresso válido.
- Botões X e Escape fecham apenas o diálogo superior.
- BRUMCLASSICS MOVEL 0.13.0 corrige Voltar, gesto lateral e saída por toque duplo.
- Inclui o B-CARD: gesto autenticado para iniciar no computador um jogo instalado listado no celular.
- 416 testes automatizados aprovados; APK assinado e auditado.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

Veja [detalhes e limites](releases/v1.49.0/RELEASE-NOTES.md).

## 1.47.0 — Correções da auditoria

- Vínculo Ubisoft local preservado ao reabrir; recuperação segura de confirmações anteriores.
- Steam separa software e DLC sem usar catálogo como prova de propriedade.
- Botão direito corrigido na causa: removida referência à ação Fila inexistente.
- Sessões sem fim conhecido marcadas como interrompidas, com backup e sem horas inventadas.
- Cache de conquistas persistido e monitoramento adaptativo encerrado junto da sessão.
- BRUMWORLD, linha do tempo e guias do MOVEL 0.11.0 atualizados.

Veja [detalhes e limites](releases/v1.47.0/RELEASE-NOTES.md).

## 1.46.1 — Menu contextual restaurado

- O botão direito volta a abrir as opções do jogo sem selecioná-lo.
- Clique normal ignora eventos de botões secundários do mouse.
- Seleções múltiplas permanecem intactas ao consultar opções individuais.
- Ações em lote aparecem somente quando o jogo acionado pertence ao grupo selecionado.
- Botão Menu e Shift + F10 continuam funcionando pelo teclado.
- Testes de regressão cobrem os gestos individuais e em lote.
- BRUMNEWS e linha do tempo atualizadas.

## 1.46.0 — Móvel, segurança e jornada

- BRUMCLASSICS MOVEL 0.11.0 reorganiza a Início com último jogo, Favoritos, Quero jogar e Minha jornada.
- Favoritos e Quero jogar sincronizam com o perfil ativo e permanecem disponíveis offline.
- Ponte local passa a usar HTTPS com certificado fixado pelo QR Code.
- APK utiliza uma identidade de assinatura estável, fora do pacote público.
- Sincronização Steam libera a biblioteca antes de atualizar conquistas em segundo plano.
- Falha de leitura das contas protegidas não é mais exibida como desconexão falsa.
- Logs de sincronização possuem limite e rotação automática.
- BRUMNEWS e linha do tempo atualizadas.

## 1.45.5 — Correção da tela preta

- Corrige a tela preta que podia prender o launcher após a atualização 1.45.4.
- Elimina uma colisão de nome global entre o modelo do sorteador e o renderer.
- Preserva o ciclo sem repetição de “O que jogar agora?”.
- Adiciona validação conjunta dos scripts globais carregados pela interface.
- Contas, biblioteca, coleções, saves, capas e configurações não são recriados nem removidos.
- BRUMNEWS e linha do tempo atualizadas.

## 1.45.4 — Sorteio sem repetição

- “O que jogar agora?” deixa de alternar entre os mesmos poucos títulos.
- O ciclo considera até 24 candidatos compatíveis.
- Cada candidato aparece uma vez antes de o ciclo recomeçar.
- O último jogo não se repete imediatamente na troca de ciclo.
- Cópias de lojas diferentes ocupam uma única vaga conforme a Loja Prioritária.
- Mudanças de tempo ou tipo reiniciam o ciclo com os novos critérios.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.45.3 — Atividades mais diretas

- Atividades recentes exibe no máximo os 10 registros mais novos.
- O limite vale também para filtros por jogo e por dia.
- Central de Sessões, Metas Pessoais e Coleções Inteligentes foram retiradas da interface.
- Fila Jogar Depois, seus estados e sua ação no menu dos jogos foram retirados.
- O Living Room Mode deixa de mostrar o indicador de fila.
- Dados anteriores permanecem preservados localmente.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.45.2 — Atalho permanente na barra de tarefas

- Corrige o erro de executável não encontrado após atualizar e reabrir por um ícone fixado.
- O launcher cria um atalho estável no menu Iniciar apontando para o executável externo permanente.
- Atalho e janela compartilham o mesmo identificador do aplicativo.
- O atalho é validado e reparado automaticamente em cada inicialização.
- Contas, biblioteca, coleções, saves e configurações permanecem no mesmo perfil.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.45.1 — Companion somente com anotações

- BRUMCOMPANION exibe somente jogos com Onde parei, Objetivos, Dicas ou Comandos preenchidos.
- Jogos ativos sem anotações permanecem ocultos e não revelam seu nome no painel de espera.
- A primeira anotação pode ser criada no Perfil do Jogo do launcher ou do celular.
- Rascunhos offline contam imediatamente como conteúdo.
- Ao apagar todos os campos, o cartão é removido depois de salvar.
- Anotações recentes segue a mesma regra e não mostra cartões vazios.
- BRUMMOMENTS, Quero jogar, galeria offline e resolução de conflitos permanecem disponíveis.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.45.0 — BRUMMOMENTS e sincronização offline

- BRUMCLASSICS MOVEL 0.10.0 ganha a galeria pessoal **BRUMMOMENTS**.
- Celular pareado pode solicitar uma captura do monitor do jogo enquanto uma sessão real está ativa.
- Momentos aceitam localização, nota, categoria e favorito e permanecem disponíveis offline.
- Galeria mantém os originais no armazenamento privado e usa prévias leves na interface.
- Anotações e **Quero jogar** podem ser alterados fora da rede e ficam numa fila persistente.
- Ao voltar à rede local, o aplicativo sincroniza as alterações por revisão e apresenta conflitos para escolha.
- API local do Companion passa ao protocolo 5 sem expor caminhos, tokens ou credenciais.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.44.4 — História completada

- Perfil do Jogo de JOGOS e CLASSICS recebe a ação **HISTÓRIA COMPLETADA**.
- A marca é individual por perfil de jogador e permanece preservada durante refreshes e sincronizações.
- Central de Conquistas ganhou contador e filtro próprios para campanhas concluídas.
- Jogos sem conquistas sincronizadas também podem registrar a história concluída.
- Conclusão da campanha permanece separada de 100% das conquistas.
- Atividades registra conclusão e remoção da marca com data e jogo.
- Estado seguro é sincronizado com o BRUMCLASSICS MOVEL.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.44.3 — Executável permanente e verificação na abertura

- Executável principal passa a usar o nome fixo `BRUMCLASSICS OFICIAL.exe`.
- Primeira abertura migra com segurança o executável versionado para o caminho permanente e mantém o perfil instalado.
- Configurações oferece **ABRIR LOCAL** para localizar e fixar o arquivo correto na barra de tarefas uma única vez.
- Verificação silenciosa de atualização ocorre em toda abertura quando habilitada.
- Atualizações futuras fazem backup, substituem e reiniciam o executável permanente.
- Asset versionado de transição mantém compatibilidade com o atualizador anterior.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## 1.44.2 — Guias completos na BRUMWORLD

- BRUMWORLD ampliada de 11 para 14 páginas com sumário atualizado.
- Guia completo para instalar, parear, sincronizar e usar o BRUMCLASSICS MOVEL offline.
- Guia do BRUMCOMPANION para acompanhar o jogo ativo e editar anotações em tempo real ou offline.
- Atualização do MOVEL explicada com GitHub, fallback local, SHA-256 e confirmação do Android.
- Atualização do launcher explicada com aviso, download, reinício, preservação de perfil e recuperação.
- BRUMNEWS e linha do tempo atualizadas sem apagar o arquivo histórico.

## 1.44.1 — BRUMNEWS compacta e Perfil móvel direto

- A linha do tempo passa a mostrar somente as seis versões mais recentes.
- Todas as notas anteriores continuam disponíveis no arquivo expansível Desde o primeiro build.
- BRUMCLASSICS MOVEL 0.9.1 remove a seção Saúde das conexões do Perfil.
- Pareamento, sincronização, cache offline e atualização pelo GitHub ou rede local permanecem ativos.
- Perfis, contas, bibliotecas, coleções, saves e configurações são preservados.

## 1.44.0 — Atualizações conectadas

- Indicador discreto e aviso único por versão no launcher.
- Atalho **Ver novidades** abre diretamente a central real de atualizações.
- BRUMCLASSICS MOVEL 0.9.0 consulta as Releases oficiais do GitHub.
- Fallback autenticado permite obter o APK pelo launcher pareado na rede local.
- Tamanho, formato e SHA-256 são conferidos antes da instalação pelo Android.
- Package ID, assinatura e dados offline do aplicativo permanecem preservados.
- BRUMNEWS e linha do tempo atualizadas.

## 1.43.4 — Novas atmosferas

- Temas Violeta Nebulosa, Ciano Polar e Rosa Synthwave em Configurações → Experiência → Tema.
- Destaques e brilho de fundo seguem a cor, sem alterar layout, capas ou mídias 3D.
- Seleção atual preservada; novos temas são opcionais e persistem após reabrir.
- Contraste e compatibilidade com os cinco temas anteriores validados.
- BRUMNEWS e linha do tempo atualizadas.
- Mantém o mecanismo de atualização e preservação de perfil da 1.43.3.

## 1.43.3 — Reinício confiável após atualizar

- O helper de atualização passa a ser criado pelo serviço WMI do Windows, fora da árvore de processos do Electron.
- A substituição continua mesmo depois que a versão anterior fecha.
- O launcher atualizado volta com uma janela visível, sem iniciar oculto.
- O helper valida que o novo processo iniciou e mantém restauração, SHA-256 e vínculo de perfil.
- BRUMNEWS e a linha do tempo registram a correção.

## 1.43.2 — Vermelho Arcade

- Novo tema disponível em Configurações → Visual → Tema.
- Destaques, brilhos, foco, progresso e superfícies reativas seguem a cor selecionada.
- Layout, capas personalizadas e mídias físicas 3D permanecem inalterados.
- BRUMNEWS, linha do tempo e arquivo completo atualizados.
- Inclui a preservação de perfil implementada na 1.43.1.

## 1.43.1 — Preservação do perfil nas atualizações

- A identidade do perfil passa a pertencer à instalação, não ao executável baixado.
- Atualizações mantêm contas, biblioteca, coleções, favoritos, anotações, configurações e saves no diretório original.
- Instalações públicas novas continuam usando um perfil limpo e independente.
- Migração de atualização anterior é validada por caminho, versão, transação e SHA-256.
- Vínculos ausentes, inválidos ou conflitantes interrompem a atualização sem trocar silenciosamente de perfil.
- O executável anterior continua disponível para restauração.

## 1.43.0 — BRUMCOMPANION

- Nova segunda tela no APK 0.8.0, em lugar do controle remoto.
- Identificação da sessão ativa de jogos modernos e CLASSICS iniciados pelo launcher.
- Consulta e edição de Onde parei, Objetivos, Dicas e Comandos no celular.
- Sincronização local autenticada, com protocolo móvel v4.
- Rascunhos offline persistentes enviados quando a conexão retorna.
- Mesclagem de alterações em campos independentes e escolha explícita em caso de conflito.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.
- Build reutiliza os assets oficiais existentes para evitar falhas de captura gráfica sem janela.
- Pacotes Windows e Android preservam o formato de publicação sem contas, ROMs ou saves pessoais.

## 1.42.2 — Identidade pública oficial

- A edição publicada passa a se chamar BRUMCLASSICS OFICIAL.
- Executáveis e pacotes usam o padrão `BRUMCLASSICS-OFICIAL-<versão>`.
- O perfil limpo de publicação continua tecnicamente isolado, sem expor dados pessoais.
- Atualizador, BRUMNEWS e linha do tempo reconhecem a nova identidade pública.

## 1.42.1 — Foco da tela de preparação

- A tela intermediária passa a usar uma janela dedicada.
- O launcher permanece minimizado enquanto o jogo é preparado.
- Quando o processo real fica pronto, teclado, mouse e controle recuperam o foco.
- Falhas restauram o launcher com segurança.

## 1.42.0 — Anotações antes de jogar

- JOGOS e CLASSICS exibem Onde parei, Objetivos, Dicas e Comandos durante a abertura.
- O aviso para continuar aparece somente quando o processo real do jogo é detectado.
- Qualquer botão de teclado, mouse ou controle entrega a tela ao jogo.

## 1.41.1 — Anotações na BRUMWORLD

- A revista ganha um tutorial visual para abrir, preencher e salvar anotações por jogo.
- O guia explica a sincronização e consulta offline pelo BRUMCLASSICS MOVEL.

## 1.41.0 — Atualizações e anotações

- Atualização segura pelo próprio launcher com SHA-256 e cópia recuperável da versão anterior.
- Perfil, contas, coleções e saves são preservados durante a troca do executável.
- Perfil do Jogo ganha Onde parei, Objetivos, Dicas e Comandos.
- Anotações passam a sincronizar com o aplicativo móvel.

## 1.40.1 — Capas de CLASSICS na distribuição limpa

- Corrigida a busca de capas dos jogos clássicos em instalações limpas.
- Adicionado fallback público por plataforma e nome, sem exigir chave pessoal.
- Capas encontradas passam a ser armazenadas no cache local e reutilizadas offline.
- Buscas simultâneas entram em fila e não são mais descartadas.
- Jogos adicionados manualmente e atualizações de CLASSICS iniciam a busca das capas ausentes.
- Capas personalizadas, coleções, favoritos, contas, saves e ROMs permanecem preservados.
- Atualização registrada na BRUMNEWS e na linha do tempo interna.

## 1.40.0 — BRUMWORLD

- BRUMWORLD passa a ser o primeiro destaque da BRUMNEWS.
- Revista em tela cheia com dez páginas, capa e sumário interativo.
- Navegação por `A`, `D`, setas, botões laterais e `Esc`.
- Tutoriais visuais de lojas, biblioteca, CLASSICS, Living Room, progresso e aplicativo móvel.
- Atalhos da revista abrem as áreas reais do launcher.

## 1.39.0 — Experiência unificada

- Central de Sessões e recuperação manual.
- Saúde individual das integrações de lojas.
- Prioridade de loja por jogo.
- Conquistas inteligentes e Cofre de Saves.
- Living Room mais fluido e sincronização móvel v3.

O histórico completo permanece disponível dentro da BRUMNEWS no próprio launcher.

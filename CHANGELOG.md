# Histórico de versões

## iOS 0.7.5 — sessões concluídas e jogo recente

- O toque em **Jogar** registra imediatamente o título como o jogo mais recente no cache do iPhone, inclusive sem vínculo com o PC.
- O registro recente local é reaplicado depois de cada sincronização para não desaparecer enquanto o launcher processa as horas.
- Ao sair para o RetroArch, uma sessão persistente acompanha a transição real para segundo plano e é concluída assim que o usuário retorna ao BRUMCLASSICS.
- Sem uma pasta de logs autorizada, o intervalo externo é usado como contingência e entra na mesma fila idempotente de horas para o PC.
- Com logs autorizados, o acumulado gravado pelo próprio RetroArch continua sendo a fonte precisa; o cronômetro de contingência não é somado por cima.
- Reinício do app, retorno de rede e respostas perdidas preservam a sessão e os segundos pendentes sem recriar o banco.
- Novos testes cobrem a transição para segundo plano, conclusão única e crédito sem pasta de logs.

## iOS 0.7.3 — importar uma vez e jogar diretamente

- A conclusão da primeira entrega é gravada no catálogo local do BRUMCLASSICS por identidade exata do arquivo.
- Toques posteriores deixam de abrir a folha de compartilhamento e usam a ROM já copiada pelo RetroArch em `~/Documents/RetroArch/downloads`.
- GBA, GB/GBC, NES, SNES, Nintendo 64, Nintendo DS, Master System, Game Gear, Mega Drive e PC Engine recebem automaticamente o núcleo correspondente pela abertura `retroarch://topshelf`.
- Formatos ambíguos já importados não são reenviados; o RetroArch abre para o usuário selecionar a playlist/núcleo existente.
- A tela passa a considerar tanto a confirmação da edição compatível quanto o registro local da primeira importação.
- Testes garantem que o caminho usado pertence ao sandbox do RetroArch, que o núcleo é determinístico e que caminhos inseguros são rejeitados.

## iOS 0.7.2 — cópia local autorizada para o RetroArch

- Corrige o caso ainda reproduzido no RetroArch reinstalado pela App Store: a URL protegida da pasta não é mais entregue diretamente a outro aplicativo.
- O BRUMCLASSICS lê a ROM enquanto possui autorização e cria uma cópia temporária, privada e excluída do backup.
- A folha de compartilhamento entrega essa cópia comum ao RetroArch; a ROM original permanece no lugar e não é alterada.
- Arquivos temporários antigos são removidos automaticamente.
- A interface distingue o uso normal do RetroArch da App Store da consulta e abertura direta disponíveis somente na edição compatível.
- O vínculo técnico antigo do RetroArch é invalidado uma vez, impedindo que um cache anterior sobreviva à reinstalação do emulador e repita a URL sem permissão; ROMs, capas, horas e conquistas não são apagadas.
- Adicionado teste automatizado que comprova que a cópia é legível e que o arquivo de origem é preservado.
- O IPA sem assinatura passa a ser anexado a uma versão pessoal estável no GitHub, evitando a expiração do artefato do Actions e permitindo que o aviso de atualização abra o download correto.

## iOS 0.7.1 — entrega autorizada ao RetroArch

- Corrige “this file couldn't be opened because you don't have permission to view” ao tocar numa ROM externa.
- O primeiro toque abre a folha de compartilhamento do iOS, mantendo a permissão até a atividade terminar.
- Depois de escolher o RetroArch, o usuário confirma a importação uma vez; a biblioteca devolvida passa a ser a identidade usada nos próximos lançamentos.
- A pasta de origem continua configurável e a ROM original não é movida nem apagada.
- Nomes limpos, capas em cache, vínculos, horas e conquistas são preservados.

## iOS 0.7.0 — CLASSICS Everywhere e abertura direta

- Capas ausentes no PC são procuradas no catálogo Libretro da mesma plataforma e persistidas no celular. Essa correspondência visual não concede conquistas nem propriedade.
- A falta de autorização para logs de horas não impede jogar.

- O nome repetido “CLASSICS in every everywhere” foi substituído por **CLASSICS Everywhere**.
- Nomes brutos como `1636 - Pokemon Fire Red (U)(Squirrels).gba` viram `Pokemon Fire Red` antes da associação com o título oficial e a capa do PC.
- Plataformas reconhecíveis abrem o caminho real com o núcleo correspondente pelo protocolo oficial `retroarch://topshelf`.
- A antiga abertura por nome de playlist permanece somente quando a identidade já foi confirmada pelo RetroArch.
- Formatos ambíguos, como ISO, CHD, ZIP, CUE e M3U, continuam exigindo uma playlist para não escolher o sistema errado.

## iOS 0.6.1 — biblioteca limitada às ROMs do aparelho

- A seção CLASSICS exibe somente arquivos compatíveis realmente detectados na pasta Downloads autorizada.
- Jogos sincronizados do PC sem ROM no iPhone deixam de aparecer nessa tela.
- A pasta é autorizada uma vez e verificada automaticamente nas próximas aberturas.
- A troca de pasta fica em **Perfil → Configurações do app → CLASSICS**.
- Arquivos com o mesmo nome em duas subpastas são omitidos para impedir a abertura do jogo errado.

## iOS 0.6.0 + launcher 1.55.3 — biblioteca real do RetroArch

- A primeira edição do atual `CLASSICS Everywhere` consulta a biblioteca devolvida pelo RetroArch compatível, em vez de manter outra cópia da ROM no BRUMCLASSICS.
- Jogos confirmados no emulador aparecem com as capas e os metadados já sincronizados do PC; tocar na mídia abre o arquivo exato.
- Itens encontrados somente no launcher continuam visíveis, mas são identificados como ainda não jogáveis no iPhone.
- Correspondência restrita à identidade confirmada ou a um único título normalizado; duplicatas ambíguas são omitidas para não iniciar o jogo errado.
- Horas reais dos logs agregados permanecem disponíveis offline e sincronizam apenas os acréscimos com o PC.
- RetroArch noturno oficial compatível documentado com versão, SHA-256, origem e limites do sandbox do iOS.

Veja [configuração do RetroArch compatível](ios/RETROARCH-COMPATIVEL.md) e [instruções do aplicativo](ios/README-IOS.md).

## iOS 0.4.0 + launcher 1.55.2 — primeira versão do CLASSICS Everywhere

- B-CARD: saída única da capa; erros não trazem o cartão de volta ao centro.
- Início: catálogo de ROMs próprias no iPhone, envio para RetroArch e atalho para jogos já importados nele.
- Configuração guiada de RetroArch, proporção, áudio, controles e RetroAchievements, sem sobrescrever saves ou credenciais do emulador.
- Progresso oficial do RetroAchievements salvo offline no iPhone e exibido em Conquistas.
- Launcher: canal autenticado reconsulta a API para o mesmo jogo/conta; preserva coleção, horas, capas e saves. Não aceita conquistas declaradas pelo celular.
- [BRUMWORLD: instalação e limites da integração](ios/BRUMWORLD-IOS-0.4.0.md).


## BRUMCLASSICS MÓVEL iOS 0.3.1 — B-CARD flutuante e Companion

- Capa flutuante limpa com botão Voltar; modo de save movido às configurações do app.
- Captura independente de anotações e painel de desempenho sempre visível.
- Diagnósticos de FPS/sensores e validade das medições pelo recebimento local.
- [Notas completas](ios/RELEASE-NOTES-IOS-0.3.1.txt).

## BRUMCLASSICS MÓVEL iOS 0.3.0 — Companion e sincronização

- Corrigida a rejeição de bibliotecas contendo minutos fracionados.
- Companion alinhado ao Android: notas, jogo ativo, desempenho e momentos; sem controle remoto.
- Navegação com Companion como aba principal, B-CARD no Início e conquistas preservadas.
- Diagnósticos de sincronização, reconexão e preservação de notas offline.
- Testes de modelos, cache, métricas e navegação no simulador iPhone.

Veja [as notas completas](ios/RELEASE-NOTES-IOS-0.3.0.txt).

## BRUMCLASSICS MÓVEL iOS 0.2.1 — Correção do IPA

- Corrigida a referência ao executável no Info.plist.
- Nomes internos ASCII e permissões de execução preservadas no ZIP.
- Validação do IPA compilado e sete testes de regressão de empacotamento.
- Bundle ID e dados preservados; a PWA não foi alterada.

Veja [as notas da correção](ios/RELEASE-NOTES-IOS-0.2.1.txt).

## BRUMCLASSICS MÓVEL iOS 0.2.0 — Sideload pessoal

- Aplicativo iOS nativo em SwiftUI para iOS 16 ou superior.
- IPA sem assinatura produzido automaticamente em executor macOS.
- Compatível com assinatura e instalação pessoal por AltStore ou Sideloadly.
- Bundle ID fixo para preservar biblioteca offline, capas e preferências entre atualizações.
- Artefato mantido fora do histórico Git e sem contas, tokens, ROMs ou caminhos pessoais.

Veja [as instruções de compilação e instalação](ios/README-IOS.md).

## 1.54.0 — Família Steam

- Ativação opcional da biblioteca familiar dentro de Configurações → Conexões.
- Consulta da sessão oficial da Steam para importar somente jogos compartilhados atualmente acessíveis.
- Classificação `family_shared`, separada de compras, licenças gratuitas e instalações locais.
- Deduplicação por AppID: a licença própria sempre vence quando o mesmo jogo também aparece na família.
- Filtro de aplicativos excluídos, indisponíveis, gratuitos da outra conta e itens que não sejam jogos.
- Token temporário protegido pela criptografia do Windows e omitido da interface pública e dos logs.
- Último catálogo familiar preservado quando o token expira ou a resposta é parcial.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.
- 464 testes automatizados aprovados.

Veja [notas, instruções e validação](releases/v1.54.0/RELEASE-NOTES.md).

## 1.53.1 — Nome oficial e capa sem SteamID

- BUSCAR DADOS procura o jogo pelo nome quando o SteamID de referência fica vazio.
- Correspondências ambíguas ou fracas são recusadas, evitando associação silenciosa ao jogo errado.
- Título oficial e AppID aparecem na tela antes de salvar.
- Nome oficial, capa vertical e imagens secundárias são preenchidos a partir do resultado confirmado.
- Jogos não oficiais já cadastrados sem mídia entram no reparo automático do refresh.
- Executável, propriedade, horas, sessões, anotações e BRUMCOMPANION permanecem preservados.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.
- 457 testes automatizados e 104 arquivos empacotados conferidos.

Veja [notas e validação](releases/v1.53.1/RELEASE-NOTES.md).

## 1.53.0 — Jogo não oficial com metadados seguros

- Cadastro explícito de jogos locais fora das lojas, com nome e executável obrigatório.
- SteamID opcional usado somente para nome oficial, capa e imagens secundárias.
- A referência Steam não comprova propriedade, não vincula conta e não habilita instalação pela loja.
- Horas locais, sessões, Living Room, anotações, B-CARD e BRUMCOMPANION continuam ligados ao executável real.
- A biblioteca e o aplicativo móvel identificam a origem não oficial sem expor caminhos locais.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.
- 454 testes automatizados e 104 arquivos empacotados conferidos.

Veja [notas e validação](releases/v1.53.0/RELEASE-NOTES.md).

## 1.52.0 — FPS, temperatura da CPU e AMD/Intel

- FPS real via PresentMon portátil oficial, ativado somente após confirmação.
- Download validado pela origem oficial e pelo SHA-256 publicado no GitHub.
- Temperatura da CPU por sensor identificado do LibreHardwareMonitor, OpenHardwareMonitor ou ACPI confiável.
- Uso de GPU por processo e VRAM para AMD e Intel pelos contadores nativos do Windows.
- NVIDIA mantém `nvidia-smi` e recebe fallback para os contadores do Windows.
- Métricas ausentes continuam como indisponíveis; nenhum valor é estimado.
- BRUMWORLD e linha do tempo atualizadas.

Veja [notas e limites](releases/v1.52.0/RELEASE-NOTES.md).

## 1.51.0 — Remoção segura e B-CARD por categoria

- Remover da biblioteca no Perfil, edição e botão direito, sem apagar arquivos ou saves.
- Cadastro arquivado e proteção contra reimportação automática por varredura.
- EDITAR JOGO corrige a seção sem remover.
- MOVEL 0.15.0 separa B-CARD em JOGOS e CLASSICS.

Veja [notas e instruções](releases/v1.51.0/RELEASE-NOTES.md).

## 1.50.1 — Ciclo de vida do monitor

- MOVEL 0.14.1 exibe a primeira leitura sem sair do Companion e oculta dados offline ou expirados.
- Troca de jogo invalida coletas antigas; troca de PID atualiza o monitor.
- CPU do processo normalizada pelo total de processadores lógicos.
- Limite esclarecido: FPS e temperatura da CPU ainda não têm integração, independentemente de ferramentas instaladas.

Veja [notas e limites](releases/v1.50.1/RELEASE-NOTES.md).

## 1.50.0 — BRUMCOMPANION desempenho ao vivo

- Monitor em tempo real de CPU, GPU NVIDIA, RAM, VRAM, processo e duração da sessão.
- Worker isolado com amostragem de três segundos, iniciado somente durante jogos.
- MOVEL 0.14.0 oferece visões simples e detalhada sem interromper a edição de anotações.
- Configurações permitem desligar totalmente o monitor e o alerta térmico opcional de 85 °C.
- PID e detalhes internos do provedor não são enviados ao celular; histórico fica desativado por padrão.
- FPS e temperatura da CPU sem provedor compatível aparecem como indisponíveis, nunca simulados.
- BRUMNEWS, linha do tempo e BRUMWORLD atualizadas.

Veja [detalhes, limites e validação](releases/v1.50.0/RELEASE-NOTES.md).

## 1.49.2 — Guia por cópia instalada

- Um novo download ou extração apresenta Steam + BRUMWORLD uma vez, mesmo com perfil e contas antigos.
- A visualização fica associada ao arquivo externo da instalação, não ao perfil global nem à extração temporária do Electron.
- Reabrir a mesma cópia não repete o guia, mesmo após fechar o app sem selecionar uma ação.
- A cópia fixa e as atualizações internas preservam a visualização; baixar manualmente de novo não reutiliza um recibo antigo.
- Contas, coleções, favoritos e saves permanecem intactos. O botão CONTINUAR COM MINHAS CONEXÕES deixa isso explícito.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas. Android permanece na versão 0.13.1.

Veja [as notas e como testar](releases/v1.49.2/RELEASE-NOTES.md).

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

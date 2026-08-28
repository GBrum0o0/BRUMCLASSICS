# Histórico de versões

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

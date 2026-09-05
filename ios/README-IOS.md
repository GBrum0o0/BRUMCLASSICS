# BRUMCLASSICS MÓVEL para iOS

Versão 0.7.5: [importação única e abertura direta pelo RetroArch](RETROARCH-COMPATIVEL.md), além de [horas offline e sincronização com o PC](HORAS-OFFLINE.md). A tela **CLASSICS Everywhere** mostra somente ROMs encontradas na pasta autorizada. No primeiro uso, copia temporariamente o arquivo para o sandbox do BRUMCLASSICS e entrega essa cópia legível. Nos próximos toques, formatos reconhecidos abrem diretamente a cópia existente em `RetroArch/downloads`. O jogo já aparece como o mais recente ao iniciar, mesmo sem vínculo com o PC, e a sessão é concluída ao retornar do RetroArch. O IPA sem assinatura é anexado à versão `ios-v0.7.5`.

Cliente iOS nativo em SwiftUI para o BRUMCLASSICS. Ele utiliza o mesmo protocolo local seguro (versão 8) do aplicativo Android e não altera o launcher nem o perfil do usuário.

## O que está implementado

- Início com último jogo, favoritos, “Quero jogar”, jornada e sessão ativa.
- Biblioteca pesquisável com Jogos, CLASSICS, favoritos e instalados.
- Central de conquistas ordenável pelos jogos mais próximos de 100%.
- Estatísticas e distribuição por plataforma.
- Perfil e pareamento pelo QR Code exibido em Configurações → MÓVEL.
- Cache offline do snapshot e das capas no Application Support do iOS.
- Credencial do launcher protegida no Keychain e TLS fixado pelo certificado do QR.
- Fila offline para anotações, favoritos e “Quero jogar”.
- Atualização em tempo real por WebSocket quando o computador está disponível.
- BRUMCOMPANION como segunda tela: jogo ativo, anotações editáveis, métricas e BRUMMOMENTS; sem controle remoto.
- B-CARD separado entre Jogos e CLASSICS, com a preferência Novo jogo / Auto Save / Save Manual nas configurações do app.
- Horas de CLASSICS no iPhone persistidas offline por logs agregados do RetroArch, sem cronômetro fictício de segundo plano.
- Consulta entre aplicativos pela URL `retroarch://library`, com retorno ao BRUMCLASSICS e cache da biblioteca real do emulador. O esquema de URL não autentica o remetente; essa resposta não comprova propriedade ou conquistas.
- Entrega da ROM ao RetroArch com a permissão do iOS no primeiro uso e abertura posterior pela identidade exata da biblioteca.
- Capas locais prioritárias; fallback no catálogo público Libretro da mesma plataforma, com imagens e índices salvos para consulta offline. A busca da capa não estabelece vínculos de conquistas.
- BRUMMOMENTS com captura da sessão ativa, galeria offline, localização, anotação, categoria e favoritos.
- Atualização pessoal: verificação automática de versão no Perfil e acesso ao build do GitHub Actions.

## Abrir e compilar no macOS

1. Instale Xcode 15 ou superior e XcodeGen (`brew install xcodegen`).
2. No Terminal, entre nesta pasta `ios` e execute `xcodegen generate`.
3. Abra `BRUMCLASSICSMobile.xcodeproj`.
4. Em **Signing & Capabilities**, selecione sua equipe Apple e ajuste o Bundle Identifier se necessário.
5. Escolha um iPhone físico. O pareamento local e a câmera não devem ser avaliados apenas no Simulator.
6. Use **Product → Run** para teste ou **Product → Archive** para TestFlight/App Store.

No Windows, `node validate-ios-project.js` confere a estrutura, os endpoints, os comandos remotos, o protocolo, a proteção local, o pin TLS e o AppIcon antes de transferir o projeto ao Mac.

O Windows não possui Xcode nem o SDK do iOS, portanto não compila o aplicativo sozinho. O workflow `github-actions/build-ios-personal.yml` usa um executor macOS do GitHub para produzir um `.ipa` sem assinatura. Copie esse arquivo para `.github/workflows/build-ios-personal.yml` na raiz do repositório e mantenha o projeto iOS na pasta `ios` do repositório.

## Uso pessoal e atualizações

### iOS 0.3.1 — B-CARD e captura

O B-CARD mostra a capa flutuante sem título externo ou marca, com Voltar e gesto para cima. A preferência Novo jogo / Auto save / Save manual fica em **Perfil → Configurações do app → B-CARD · CLASSICS**. Vale somente para clássicos; jogos de PC mantêm a abertura normal.

No Companion, **TIRAR PRINT** fica sempre visível e habilita quando há conexão e jogo ativo, mesmo sem notas. As métricas mostram o estado de espera ou o motivo de indisponibilidade. FPS exige o coletor PresentMon no computador, ativado pelo próprio usuário em Configurações → MÓVEL. Nenhum sensor ou valor é simulado.

Use o IPA 0.3.1 sobre o app existente com a mesma conta de assinatura e Bundle ID.

### iOS 0.3.0 — alinhamento ao Android

Veja o [guia BRUMWORLD do iPhone](BRUMWORLD-IOS-0.3.0.md).

As abas são Início, Biblioteca, Estatísticas, Companion e Perfil. O B-CARD fica no Início; Conquistas pode ser aberto em Estatísticas e Perfil. No Companion, um jogo ativo com anotações mostra Onde parei, Objetivos, Dicas e Comandos para consulta e edição. Jogos sem notas ficam ocultos, mas as métricas válidas da sessão continuam disponíveis. O controle remoto foi retirado.

As notas são guardadas no iPhone antes do envio. Fora da rede, consulte o cache e edite no Perfil do Jogo; alterações pendentes são reenviadas ao reconectar. Se houver conflito, abra o Companion para escolher qual versão manter. O estado ERRO DE SINCRONIZAÇÃO agora traz o motivo no Perfil, separado de OFFLINE e SINCRONIZANDO. Minutos fracionados não impedem mais a leitura da biblioteca.

Use o IPA 0.3.0 sobre a instalação existente, sem desinstalar, com a mesma conta de assinatura e Bundle ID. O workflow testa dados e navegação em simulador iPhone antes de produzir o IPA arm64; a conexão de rede e assinatura no aparelho físico ainda precisam ser verificadas pelo usuário.

### Correção 0.2.1

Use o IPA **0.2.1**, substituindo a seleção do arquivo 0.2.0 no Sideloadly. Esta versão corrige a ausência de `CFBundleExecutable` e utiliza caminhos internos ASCII para evitar incompatibilidades de nomes. O nome visível continua BRUMCLASSICS.

O workflow executa sete testes de regressão e valida o IPA compilado (binário arm64, referência ao executável, permissões Unix, versão e CRC). O artefato inclui `IPA-VALIDATION.json` e SHA-256. Essas verificações não substituem o teste de assinatura e instalação num iPhone real.

Para validar um download: `python3 validate_ipa.py caminho/do/arquivo.ipa --version 0.2.1`.

1. Execute **Build iOS pessoal** na aba Actions do GitHub e baixe o artefato `BRUMCLASSICS-MOVEL-IOS-PESSOAL` no computador.
2. No Windows, assine e instale o `.ipa` no seu iPhone com Sideloadly/AltStore e a sua própria conta Apple.
3. Nas próximas versões, use sempre o Bundle ID `com.brumclassics.mobile.ios` e instale sobre o app anterior. Isso permite que o iOS preserve a biblioteca offline, capas e preferências.
4. Publique `ios-update.json` na raiz do repositório sempre que criar um build. O app consulta esse arquivo ao abrir e também pelo botão **VERIFICAR AGORA** no Perfil.

Não publique o `.ipa` em Releases se quiser mantê-lo pessoal. Artefatos de Actions exigem acesso ao repositório e expiram conforme a retenção configurada. Com uma Apple ID gratuita, a assinatura pessoal precisa ser renovada periodicamente; essa regra é do iOS e não pode ser removida pelo BRUMCLASSICS.

## Privacidade

O aplicativo não recebe senhas de lojas, caminhos locais do PC ou executáveis. A biblioteca do RetroArch devolve somente título, identidade, sistema e núcleo; ROMs não são copiadas de volta para o BRUMCLASSICS. A permissão de leitura da pasta de logs é escolhida pelo app Arquivos; somente os contadores dos jogos vinculados são enviados ao PC pareado. O token do launcher e a Web API Key RetroAchievements ficam no Keychain. O usuário e a chave são enviados apenas ao RetroAchievements para consultar o progresso. Biblioteca, capas, progresso e fila offline usam proteção de arquivos do iOS. O app não oferece comandos de desligamento ou suspensão do PC.

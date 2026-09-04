# BRUMCLASSICS MÓVEL para iOS

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
- BRUMCOMPANION com navegação, pesquisa, volume, save/load e métricas.
- B-CARD separado entre Jogos e CLASSICS, com Novo jogo, Auto Save e Save Manual.
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

1. Execute **Build iOS pessoal** na aba Actions do GitHub e baixe o artefato `BRUMCLASSICS-MOVEL-IOS-PESSOAL` no computador.
2. No Windows, assine e instale o `.ipa` no seu iPhone com Sideloadly/AltStore e a sua própria conta Apple.
3. Nas próximas versões, use sempre o Bundle ID `com.brumclassics.mobile.ios` e instale sobre o app anterior. Isso permite que o iOS preserve a biblioteca offline, capas e preferências.
4. Publique `ios-update.json` na raiz do repositório sempre que criar um build. O app consulta esse arquivo ao abrir e também pelo botão **VERIFICAR AGORA** no Perfil.

Não publique o `.ipa` em Releases se quiser mantê-lo pessoal. Artefatos de Actions exigem acesso ao repositório e expiram conforme a retenção configurada. Com uma Apple ID gratuita, a assinatura pessoal precisa ser renovada periodicamente; essa regra é do iOS e não pode ser removida pelo BRUMCLASSICS.

## Privacidade

O aplicativo não recebe senhas, tokens de lojas, caminhos locais, executáveis ou ROMs. O token próprio do dispositivo fica no Keychain. A biblioteca e as capas offline usam proteção de arquivos do iOS. O launcher continua pedindo confirmação local para suspender ou desligar o computador.

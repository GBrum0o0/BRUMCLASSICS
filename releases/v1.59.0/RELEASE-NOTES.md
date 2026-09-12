# BRUMCLASSICS 1.59.0 — Central BRUM em todos os dispositivos

Esta versão conecta a Central de Notificações do launcher aos aplicativos móveis oficiais.

## Novidades

- O protocolo móvel 9 entrega conquistas, sessões, saves, instalações, atualizações e avisos ao iPhone e Android.
- Apenas as notificações do perfil ativo são enviadas ao aparelho pareado.
- Leitura individual e “marcar todas como lidas” retornam ao launcher por rotas autenticadas.
- O evento em tempo real `notifications_changed` mantém os aparelhos atualizados sem consultas contínuas.
- O snapshot móvel remove identidade de perfil, chaves de deduplicação, credenciais, tokens e caminhos locais.
- Clientes e caches do protocolo 8 continuam compatíveis com os recursos anteriores.

## Aplicativos complementares

- Android 0.17.0 adiciona a Central BRUM e preserva a assinatura usada na 0.16.0.
- iOS 0.8.0 adiciona a mesma central em SwiftUI e mantém o bundle ID pessoal para instalação sobre a versão anterior.

## Instalação

Feche a versão anterior e execute `BRUMCLASSICS-OFICIAL.exe`. O arquivo versionado é idêntico e existe para conferência. Biblioteca, perfis, contas, favoritos, coleções, saves e configurações permanecem no perfil oficial existente.

O pacote não contém contas, tokens, biblioteca pessoal, ROMs, saves ou chaves privadas. O executável não possui certificado Authenticode comercial, portanto o Windows pode apresentar um aviso de reputação.

# Validação iOS 0.12.0

- Build 23, iOS 16 ou posterior e dispositivos iPhone/iPad.
- Estrutura, endpoints, protocolo móvel 10, proteção local e AppIcon validados antes do envio.
- O workflow macOS executa os testes de simulador e compila o pacote `iphoneos`.
- O IPA sem assinatura é validado por conteúdo, versão, executável arm64, permissões e SHA-256 antes da publicação.
- Bundle ID preservado para manter cache, pareamento e preferências ao instalar sobre a versão anterior.

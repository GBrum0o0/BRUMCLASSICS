# Validação iOS 0.12.1

- Build 24, iOS 16 ou posterior e dispositivos iPhone/iPad.
- Estrutura, endpoints, protocolo móvel 10, proteção local e AppIcon validados antes do envio.
- Testes do empacotador IPA aprovados localmente.
- O workflow macOS executa testes no simulador, compila para `iphoneos` e valida executável arm64, versão, permissões e SHA-256.
- Bundle ID preservado para manter cache, pareamento e preferências ao instalar sobre a versão anterior.

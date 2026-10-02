# Validação da versão 1.76.0

- Serviço de streaming: testes unitários aprovados.
- Ponte móvel: 22 testes aprovados, incluindo autenticação, expiração e bloqueio de repetição.
- Android: testes unitários, compilação Java, C++/BRUM Core, lint e APK debug aprovados.
- iOS: validação definitiva executada no macOS pelo workflow oficial antes de anexar o IPA.
- Segurança: nenhum token de loja, credencial Sunshine ou segredo Tailscale entra no snapshot móvel.
- Rede remota: somente endereço Tailscale é recomendado; encaminhamento público de porta não é usado.
- Testes do launcher: `658 aprovados`, `0 falhas` após correção dos dois contratos editoriais detectados pela primeira execução.
- Executável: `392887163` bytes; SHA-256 `E2C22933CD7EAF55077F67E9ADE5B7CDA3A2B4266B08104CD2051D4BE35F17FA`.

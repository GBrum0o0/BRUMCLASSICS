# Validação 1.49.2

- 432 testes de regressão aprovados, incluindo 13 cenários do primeiro acesso por cópia.
- Sintaxe JavaScript e PowerShell verificadas.
- Perfil antigo com contas e biblioteca não impede o guia numa nova cópia; arquivo pessoal permanece idêntico.
- Reabertura, novo caminho, substituição na mesma pasta e extração com mesmos bytes/mtime testados.
- Cópia fixa criada pelo launcher compartilha a visualização, antes ou depois de dispensar o guia.
- Recibo de atualização tem uso único. O teste real do Windows detectou e corrigiu a reutilização causada por timestamps preservados pelo NTFS.
- IDs de arquivos Windows mantêm precisão integral de 64 bits.
- Helper PowerShell real substituiu um executável de teste, iniciou-o e preservou o guia dispensado. Uma cópia manual posterior apresentou o guia novamente.
- Renderer Electron validou abertura automática com Steam já conectada, reabertura sem repetição, novo download e acesso à BRUMWORLD.
- 18 diálogos passaram nos testes de X/Escape.
- Os 99 arquivos fonte do app.asar público correspondem por SHA-256 ao código testado. A abertura automática e os 18 diálogos também foram testados nesse pacote compilado.
- A migração empacotada 1.49.1 → 1.49.2 preservou o perfil official; uma instalação pública nova permaneceu no perfil distribution.

Testes usam perfis e executáveis temporários, sem reconectar contas nem limpar dados pessoais. O arquivo Android permanece o APK 0.13.1 previamente validado e assinado.

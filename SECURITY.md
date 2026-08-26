# Segurança

## Versões com suporte

Somente a versão mais recente publicada em GitHub Releases recebe correções de segurança.

## Como relatar

Não publique tokens, cookies, senhas, QR Codes, caminhos pessoais ou arquivos de conta em uma issue pública.

Ao relatar um problema:

1. Informe a versão do BRUMCLASSICS e do Windows.
2. Descreva o comportamento sem anexar credenciais.
3. Remova dados pessoais dos logs antes de compartilhar.
4. Para uma vulnerabilidade real, use a opção **Report a vulnerability** do GitHub quando ela estiver disponível no repositório.

## Verificação dos downloads

Compare o SHA-256 dos arquivos baixados com `SHA256SUMS.txt` anexado à Release. No PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\arquivo-baixado.exe'
```


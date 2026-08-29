# BRUMCLASSICS OFICIAL 1.44.0 — Atualizações conectadas

O launcher passa a avisar discretamente quando existe uma versão nova, e o BRUMCLASSICS MOVEL ganha seu próprio fluxo de atualização assistida.

## Launcher

- Um ponto luminoso aparece no ícone de **Configurações** enquanto houver atualização disponível ou pronta.
- Um aviso compacto surge somente uma vez por versão, sem interromper a biblioteca.
- **VER NOVIDADES** abre diretamente **Configurações → Sistema → Atualizações**.
- Download, SHA-256, cópia de recuperação, reinício e vínculo do perfil continuam usando o mecanismo seguro das versões anteriores.

## BRUMCLASSICS MOVEL 0.9.0

- Consulta os APKs publicados nas Releases oficiais do GitHub.
- Se o GitHub estiver indisponível, usa como fallback o launcher pareado na mesma rede local.
- Baixa o APK no armazenamento privado do celular e confere nome versionado, tamanho, formato e SHA-256.
- Abre a confirmação oficial do Android; instalação silenciosa não é utilizada.
- Mantém o identificador do aplicativo, o `versionCode` crescente e a mesma assinatura da 0.8.0, preservando dados offline.
- A tela **Perfil → Atualizações** mostra versão, origem, tamanho, progresso e resultado.

A 0.9.0 é a primeira versão que contém esse atualizador. Portanto, quem ainda possui a 0.8.0 precisa instalar o APK 0.9.0 uma última vez pelo método atual. Depois disso, as versões futuras poderão ser baixadas pelo próprio aplicativo.

## Preservação e privacidade

- Contas, biblioteca, coleções, favoritos, capas, anotações e saves não são recriados.
- O endpoint local do APK exige o pareamento já autorizado do celular.
- Tokens de lojas e caminhos privados não são enviados ao aplicativo.
- Pacote público limpo, com RETROGAMES vazia e sem dados pessoais.

## Arquivos

- `BRUMCLASSICS-OFICIAL-1.44.0-portable.exe`
- `BRUMCLASSICS-OFICIAL-1.44.0-COMPLETO.zip`
- `BRUMCLASSICS-MOVEL-0.9.0-debug.apk`
- `SHA256SUMS.txt`

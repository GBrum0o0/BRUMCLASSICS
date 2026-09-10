# BRUMCLASSICS MÓVEL Android 0.16.0

Esta versão leva ao Android as atualizações do **CLASSICS Everywhere** desenvolvidas para o iOS, preservando biblioteca offline, B-CARD, BRUMCOMPANION, BRUMMOMENTS, pareamento HTTPS e atualização pelo próprio aplicativo.

## Novidades

- Pasta de ROMs autorizada pelo seletor nativo do Android, sem acesso amplo ao armazenamento.
- Abertura direta de GB, GBC, GBA, NES, SNES, N64, NDS, Mega Drive e PC Engine no RetroArch, com núcleo sugerido.
- Vínculo explícito entre a ROM local, o mesmo CLASSICS do launcher e o ID oficial do RetroAchievements.
- Usuário e Web API Key do RetroAchievements protegidos pelo Android Keystore; a chave é usada somente para consulta.
- Conquistas oficiais armazenadas para consulta offline e sincronizadas com o launcher.
- Horas locais lidas preferencialmente dos logs agregados `.lrtl`, com cronômetro persistente de contingência.
- Fila cumulativa e idempotente de horas, evitando duplicação ao reconectar com o PC.
- Último CLASSIC jogado no celular exibido na tela Início e estatísticas com ROMs e tempo locais.

## Instalação

Baixe `BRUMCLASSICS-MOVEL-0.16.0.apk` nesta release e instale sobre a versão anterior. O package ID e o certificado são os mesmos; não é necessário desinstalar nem limpar os dados.

Requer Android 8.0/API 26 ou superior. O RetroArch continua sendo um aplicativo separado. ROMs, BIOS, saves e núcleos não são fornecidos.

Consulte também a [validação](VALIDACAO.md).

# Validação da release 1.49.0

- 416 testes automatizados do launcher aprovados, sem falhas.
- Sintaxe de todos os módulos JavaScript validada.
- Testes novos cobrem hashing de GBA, cabeçalhos NES/SNES, normalização Nintendo 64 e detecção segura de ISO.
- Testes novos confirmam primeiro acesso por perfil, links oficiais e fechamento do diálogo superior.
- Builds separados auditados dentro do `app.asar`: pessoal `1.49.0 / official`; público `1.49.0 / distribution`.
- BRUMCLASSICS MOVEL 0.13.0 compilado; `HomeLibraryTest` aprovado.
- APK package `com.brumclassics.mobile`, versionCode 19, Android 8.0+.
- Assinatura APK v2/v3 verificada com o mesmo certificado estável das versões anteriores.
- SHA-256 do APK: `862A1E4904BEACDCBA0EC947BA4F5811DEA2A20F1A33A1B6BC52CB4B34D029F5`.
- BRUMNEWS, linha do tempo, BRUMWORLD, README, changelog e guias móveis atualizados.

Limite: a validação automatizada comprova os algoritmos, cache, fluxo e empacotamento, mas não desbloqueia uma conquista real em cada ROM do usuário. A disponibilidade e os hashes aceitos pertencem ao RetroAchievements.

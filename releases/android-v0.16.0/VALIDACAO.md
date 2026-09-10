# Validação Android 0.16.0

- `versionCode 24` e `versionName 0.16.0` conferidos no APK.
- Assinatura APK v2/v3 verificada com o mesmo certificado das versões anteriores.
- Testes de biblioteca inicial, desempenho, B-CARD e regras de CLASSICS executados pelo build.
- Scanner limitado a 10.000 arquivos e formatos aceitos explicitamente.
- Catálogo, conquistas, horas, vínculo e sessão ativa são gravados atomicamente ou em preferências privadas.
- Credenciais RetroAchievements são cifradas com chave AES-GCM no Android Keystore.
- Permissões persistentes de pastas são somente de leitura.
- Respostas do RetroAchievements e arquivos `.lrtl` possuem limite de tamanho.
- Envio de horas usa `streamId` e contador cumulativo; confirmações divergentes não são aceitas localmente.
- O APK não inclui ROMs, BIOS, saves, credenciais ou chaves privadas de assinatura.

Pendente de validação física: abertura de cada núcleo instalado e acesso à pasta de logs variam conforme a edição do RetroArch e o provedor de arquivos do aparelho.

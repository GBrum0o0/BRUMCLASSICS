# Validação Android 0.17.0

- `versionCode 25` e `versionName 0.17.0` conferidos no APK.
- Compilação Android, testes unitários e lint vital aprovados.
- Assinatura APK v2/v3 comparada com o certificado estável da versão anterior.
- Rotas de leitura exigem token de pareamento e aceitam somente ID limitado ou a ação explícita de todos.
- Eventos `notifications_changed` solicitam um snapshot novo sem abrir outro perfil.
- O APK não inclui ROMs, BIOS, saves, credenciais ou chaves privadas de assinatura.

Pendente de validação física: aparência em diferentes densidades e fabricantes, além das integrações externas do RetroArch.

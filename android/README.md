# BRUMCLASSICS MÓVEL para Android

Cliente Android nativo complementar ao BRUMCLASSICS. A versão atual é a **0.16.0** (`versionCode 24`) e requer Android 8.0/API 26 ou superior.

## O que está implementado

- Biblioteca, capas, conquistas, estatísticas, anotações e BRUMMOMENTS disponíveis offline após a sincronização.
- Pareamento local autenticado com HTTPS e certificado fixado pelo QR Code do launcher.
- B-CARD e BRUMCOMPANION com sessão ativa e métricas reais disponibilizadas pelo computador.
- Fila offline para mudanças feitas longe do launcher.
- Atualização pelo próprio aplicativo usando releases oficiais assinadas.
- **CLASSICS Everywhere** com pasta de ROMs autorizada pelo seletor nativo do Android.
- Abertura no RetroArch, capa local, jogo recente e contador de horas persistente.
- Consulta oficial do RetroAchievements, com usuário e Web API Key protegidos pelo Android Keystore.
- Sincronização idempotente de horas e conquistas vinculadas quando o computador volta à mesma rede.

ROMs, BIOS, saves, núcleos e credenciais não fazem parte deste repositório nem do APK.

## Compilar

Use JDK 17 e Android SDK 36:

```bash
./gradlew :app:assembleDebug
```

No Windows:

```powershell
.\gradlew.bat :app:assembleDebug
```

O APK publicado em Releases é assinado separadamente com a identidade usada nas versões anteriores. Uma compilação local não substitui essa assinatura.

## Testes

O workflow `Android CI` compila o aplicativo e executa os testes de contrato sem depender de um aparelho. A abertura do RetroArch, o provedor de documentos e a leitura dos logs `.lrtl` também devem ser confirmados em um Android físico.

Veja o [guia de uso](../docs/MOVEL.md), as [notas da versão](../releases/android-v0.16.0/RELEASE-NOTES.md) e a [validação](../releases/android-v0.16.0/VALIDACAO.md).

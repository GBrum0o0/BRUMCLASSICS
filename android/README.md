# BRUMCLASSICS MÓVEL para Android

Cliente Android nativo complementar ao BRUMCLASSICS. A versão atual é a **0.25.0** (`versionCode 37`) e requer Android 8.0/API 26 ou superior.

Em jogos cuja conexão não oferece leitura oficial completa, a aba **Conquistas** pesquisa jogos e mostra imagem, título e descrição do catálogo carregado pelo launcher. Toque em um item para marcar ou desfazer o progresso manual. O launcher 1.62.0 mantém esses registros por perfil e protege confirmações oficiais.

## O que está implementado

- Biblioteca, capas, conquistas, estatísticas, anotações e BRUMMOMENTS disponíveis offline após a sincronização.
- Pareamento local autenticado com HTTPS e certificado fixado pelo QR Code do launcher.
- B-CARD e BRUMCOMPANION com sessão ativa e métricas reais disponibilizadas pelo computador.
- Fila offline para mudanças feitas longe do launcher.
- Atualização pelo próprio aplicativo usando releases oficiais assinadas.
- **CLASSICS Everywhere** com pasta de ROMs autorizada pelo seletor nativo do Android.
- BRUM Core integrado para NES/Famicom, SNES/Super Famicom, Master System, Game Gear, PC Engine/TurboGrafx-16, GB, GBC, GBA, Nintendo DS, Neo Geo AES/MVS, WonderSwan/Color e PlayStation 2 experimental.
- Três slots de estado rápido locais por jogo, separados do save normal e protegidos por identidade de ROM e núcleo.
- Registro multicore com seleção dinâmica de biblioteca, nome, versão e licença; jogos sem núcleo interno aprovado permanecem no RetroArch.
- Consulta oficial do RetroAchievements, com usuário e Web API Key protegidos pelo Android Keystore.
- Sincronização idempotente de horas e conquistas vinculadas quando o computador volta à mesma rede.
- **Gaming Mode** horizontal e direto, aberto pelo botão central JOGAR, sem manter a barra inferior sobre o jogo.
- Duas listas objetivas: ROMs encontradas na pasta autorizada do celular e jogos com instalação confirmada no computador.
- Roteamento automático entre BRUM Core, RetroArch e início seguro no computador pelo B-CARD.
- Navegação inferior com Início, Biblioteca, JOGAR, Estatísticas e Companion; Perfil fica dentro da Início.

ROMs, BIOS, saves e credenciais não fazem parte deste repositório nem do APK. O APK inclui somente núcleos aprovados, suas licenças integrais e a GPL do aplicativo móvel.

## Compilar

Use JDK 17 e Android SDK 36:

```bash
./fetch-mgba-core.ps1
./fetch-skyemu-core.ps1
./fetch-geolith-core.ps1
./fetch-gearsystem-core.ps1
./fetch-nestopia-core.ps1
./fetch-play-core.ps1
./gradlew :app:assembleDebug
```

No Windows:

```powershell
.\fetch-mgba-core.ps1
.\fetch-skyemu-core.ps1
.\fetch-geolith-core.ps1
.\fetch-gearsystem-core.ps1
.\fetch-nestopia-core.ps1
.\fetch-play-core.ps1
.\gradlew.bat :app:assembleDebug
```

O APK publicado em Releases é assinado separadamente com a identidade usada nas versões anteriores. Uma compilação local não substitui essa assinatura.

## Testes

O workflow `Android CI` compila o aplicativo e executa os testes de contrato sem depender de um aparelho. A abertura do RetroArch, o provedor de documentos e a leitura dos logs `.lrtl` também devem ser confirmados em um Android físico.

NES, SNES, Master System, Game Gear, PC Engine/TurboGrafx-16, GB, GBC, GBA, Nintendo DS, Neo Geo e PS2 experimental rodam diretamente no **BRUM Core** conforme a matriz de plataformas. Sistemas restantes podem ser encaminhados ao RetroArch externo, sem serem anunciados como nativos.

Veja o [guia de uso](../docs/MOVEL.md), o [licenciamento móvel](../MOBILE-LICENSING.md), as [notas da versão](../releases/android-v0.25.0/RELEASE-NOTES.md) e a [validação](../releases/android-v0.25.0/VALIDACAO.md).

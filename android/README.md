# BRUMCLASSICS MÓVEL para Android

Cliente Android nativo complementar ao BRUMCLASSICS. A versão atual é a **0.22.1** (`versionCode 32`) e requer Android 8.0/API 26 ou superior.

Em jogos cuja conexão não oferece leitura oficial completa, a aba **Conquistas** pesquisa jogos e mostra imagem, título e descrição do catálogo carregado pelo launcher. Toque em um item para marcar ou desfazer o progresso manual. O launcher 1.62.0 mantém esses registros por perfil e protege confirmações oficiais.

## O que está implementado

- Biblioteca, capas, conquistas, estatísticas, anotações e BRUMMOMENTS disponíveis offline após a sincronização.
- Pareamento local autenticado com HTTPS e certificado fixado pelo QR Code do launcher.
- B-CARD e BRUMCOMPANION com sessão ativa e métricas reais disponibilizadas pelo computador.
- Fila offline para mudanças feitas longe do launcher.
- Atualização pelo próprio aplicativo usando releases oficiais assinadas.
- **CLASSICS Everywhere** com pasta de ROMs autorizada pelo seletor nativo do Android.
- BRUM Core integrado para GB, GBC e GBA; RetroArch permanece como fallback para os demais sistemas.
- Três slots de estado rápido locais por jogo, separados do save normal e protegidos por identidade de ROM e núcleo.
- Consulta oficial do RetroAchievements, com usuário e Web API Key protegidos pelo Android Keystore.
- Sincronização idempotente de horas e conquistas vinculadas quando o computador volta à mesma rede.
- **Gaming Mode** horizontal e direto, aberto pelo botão central JOGAR, sem manter a barra inferior sobre o jogo.
- Duas listas objetivas: ROMs encontradas na pasta autorizada do celular e jogos com instalação confirmada no computador.
- Roteamento automático entre BRUM Core, RetroArch e início seguro no computador pelo B-CARD.
- Navegação inferior com Início, Biblioteca, JOGAR, Estatísticas e Companion; Perfil fica dentro da Início.

ROMs, BIOS, saves e credenciais não fazem parte deste repositório nem do APK. O APK inclui somente o núcleo mGBA aprovado e seu aviso de licença.

## Compilar

Use JDK 17 e Android SDK 36:

```bash
git clone --filter=blob:none https://github.com/libretro/mgba.git app/src/main/cpp/vendor/mgba
git -C app/src/main/cpp/vendor/mgba checkout --detach 7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6
./gradlew :app:assembleDebug
```

No Windows:

```powershell
.\fetch-mgba-core.ps1
.\gradlew.bat :app:assembleDebug
```

O APK publicado em Releases é assinado separadamente com a identidade usada nas versões anteriores. Uma compilação local não substitui essa assinatura.

## Testes

O workflow `Android CI` compila o aplicativo e executa os testes de contrato sem depender de um aparelho. A abertura do RetroArch, o provedor de documentos e a leitura dos logs `.lrtl` também devem ser confirmados em um Android físico.

GB, GBC e GBA agora rodam diretamente no **BRUM Core**, com mGBA integrado, tela horizontal, controles virtuais e Bluetooth, save local e avanço rápido 5×. Os demais sistemas continuam usando o RetroArch como fallback.

Veja o [guia de uso](../docs/MOVEL.md), as [notas da versão](../releases/android-v0.22.1/RELEASE-NOTES.md) e a [validação](../releases/android-v0.22.1/VALIDACAO.md).

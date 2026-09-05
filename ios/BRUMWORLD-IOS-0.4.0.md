# BRUMWORLD · CLASSICS Everywhere

> Atualização iOS 0.7.4: escolha RetroArch somente na primeira vez. Nos próximos toques, o jogo abre diretamente, aparece imediatamente como o mais recente e a sessão é concluída quando você retorna ao BRUMCLASSICS. Logs autorizados fornecem o tempo preciso; sem eles, o app mantém um cronômetro persistente de contingência.

## 1. Instalar

Atualize o BRUMCLASSICS MÓVEL para iOS 0.4.0 pelo Sideloadly sobre o app existente, usando a mesma conta. Não desinstale. No computador, use o launcher 1.55.2 para a nova sincronização.

Instale o [RetroArch oficial pela App Store](https://apps.apple.com/app/retroarch/id6499539433), ou assine o IPA 1.22.2 obtido no [site oficial](https://www.retroarch.com/platforms.php). O emulador é separado do BRUMCLASSICS: não está embutido no IPA móvel. A versão App Store evita ocupar outra assinatura pessoal de sideload.

## 2. Adicionar e jogar no iPhone

**Início → CLASSICS Everywhere**.

Selecione sua ROM pelo app Arquivos. O BRUMCLASSICS guarda uma cópia privada e não altera o original. ROMs, BIOS e núcleos não são fornecidos. Formatos aceitos não garantem que todos os núcleos, aparelhos ou conjuntos de conquistas os suportem.

Abra o item → **Enviar arquivo ao RetroArch**. Escolha RetroArch no compartilhamento ou **Salvar em Arquivos → No Meu iPhone → RetroArch → downloads**. No RetroArch, use Load Content, selecione o arquivo e o núcleo compatível. Depois, marque **Já importei e executei** no BRUMCLASSICS; o botão **Jogar no RetroArch** usa o atalho oficial `retroarch://game/<filename>`.

O iOS confirma que abriu o emulador, não que ele iniciou a ROM. Se o atalho abrir só o menu, confira a importação e execute a ROM primeiro no RetroArch. Para ZIPs, prefira importar o arquivo descompactado individual quando possível. Jogos de vários discos/arquivos precisam do conjunto completo dentro do emulador; não basta um CUE sem seus BINs.

## 3. Configurar sem perder preferências

**Perfil → Configurações do app → CLASSICS no iPhone → RetroArch e RetroAchievements** abre o guia.

No RetroArch: **Settings → Video → Scaling → Aspect Ratio: Core provided** preserva a proporção; Integer Scale é opcional. Em **Audio**, ajuste Volume Gain; em **Input → On-Screen Overlay**, configure o controle virtual. Faça uma cópia de `retroarch.cfg` no app Arquivos antes de alterar uma configuração existente. O BRUMCLASSICS não escreve dentro do sandbox de outro app.

## 4. Conquistas no celular e no PC

No RetroArch: **Settings → Achievements → Enabled**, usuário e senha da sua conta RetroAchievements. A Web API Key NÃO substitui esse login. É preciso ROM reconhecida, núcleo compatível e internet para registrar os desbloqueios. Hardcore restringe save states.

No BRUMCLASSICS: salve usuário e Web API Key nas configurações de CLASSICS; ficam no Keychain. Dentro do jogo importado, informe o ID oficial (número do endereço `retroachievements.org/game/…`). Selecione **Mesmo jogo no launcher** e salve. O PC precisa ter esse jogo já reconhecido pelo mesmo ID e usar a mesma conta RA. Não fazemos correspondência apenas pelo título.

Ao retornar ao app (com intervalo mínimo automático de 60 segundos) ou puxar para atualizar, o iPhone consulta o progresso oficial. **Conquistas → CLASSICS no iPhone** mostra desbloqueios e bloqueadas, com data da consulta e conta. Offline, mantém a última resposta. O aplicativo não fica executando em segundo plano enquanto você joga: não promete notificações instantâneas com o iOS suspenso.

Com PC pareado, atualizado e na rede local, ele reconsulta a API por conta própria para atualizar o jogo vinculado. Uma falha deixa os dados anteriores intactos e é informada na tela; a próxima sincronização tenta novamente. O celular não envia chaves RA, arquivos de ROM ou supostos desbloqueios ao computador. Títulos existentes somente no telefone não são adicionados silenciosamente como jogos instalados/possuídos no PC: associe primeiro um jogo CLASSICS reconhecido no launcher.

## 5. B-CARD

Arraste a capa para cima além do limiar: ela sai uma única vez e desaparece. Mesmo se houver falha de comunicação, não reaparece no centro. O aviso de erro permite voltar à biblioteca. Um movimento curto, abaixo do limiar de envio, ainda cancela o gesto.

## Fontes verificadas

- [RetroArch iOS 1.22.2: implementação dos atalhos](https://github.com/libretro/RetroArch/blob/v1.22.2/ui/drivers/ui_cocoatouch.m).
- [Configurar RetroAchievements no RetroArch](https://docs.libretro.com/guides/retroachievements/).
- [API oficial: progresso do usuário por jogo](https://api-docs.retroachievements.org/v1/get-game-info-and-user-progress.html).

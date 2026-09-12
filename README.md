<p align="center">
  <img src="docs/images/brand-mark.svg" width="72" alt="BRUMCLASSICS" />
</p>

<h1 align="center">BRUMCLASSICS</h1>

<p align="center">
  Biblioteca unificada para jogos modernos e clássicos no Windows, com aplicativos móveis complementares.
</p>

<p align="center">
  <a href="https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v1.60.0"><strong>Windows 1.60.0</strong></a> ·
  <a href="https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/android-v0.17.0"><strong>Android 0.17.0</strong></a> ·
  <a href="https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v0.8.1"><strong>iOS 0.8.1</strong></a> ·
  <a href="SUPPORT.md">Ajuda</a> ·
  <a href="PRIVACY.md">Privacidade</a> ·
  <a href="SECURITY.md">Segurança</a>
</p>

![BRUMWORLD dentro do BRUMCLASSICS](docs/images/brumworld-banca.png)

## O que é

O BRUMCLASSICS reúne bibliotecas de jogos, CLASSICS, conquistas, sessões, coleções, saves, capturas e uma experiência para televisão chamada Living Room Mode. O BRUMCLASSICS MOVEL funciona como extensão do launcher e mantém uma cópia offline dos dados sincronizados pelo próprio usuário.

Esta página distribui o **BRUMCLASSICS OFICIAL**, preparado para uma instalação limpa em outros computadores. O pacote não contém contas, tokens, biblioteca, capas pessoais, favoritos, saves ou ROMs do computador usado no desenvolvimento.

## Principais recursos

- Biblioteca unificada de jogos modernos e clássicos.
- Integração com Steam, Epic Games, GOG, EA App e Ubisoft Connect, conforme a disponibilidade de cada serviço.
- Explorador único de conexões para lojas, RetroAchievements e RetroArch, com busca, permissões, diagnóstico e monitoramento visível.
- Família Steam opcional: jogos compartilhados atualmente acessíveis entram identificados separadamente, sem serem tratados como compras da conta.
- Busca, filtros, coleções, favoritos e prioridade de loja.
- Jogos não oficiais podem ser cadastrados com executável local e SteamID opcional. **BUSCAR DADOS** usa o ID exato ou uma correspondência segura pelo nome para mostrar título oficial e recuperar capa e imagens, sem criar uma falsa licença de loja.
- Remover da biblioteca sem desinstalar o jogo; correção de seção pelo Perfil → Editar jogo.
- Conquistas modernas e RetroAchievements.
- Registro pessoal de **História completada** para jogos modernos e CLASSICS, separado do percentual de conquistas.
- CLASSICS com RetroArch, save states e Quick Resume.
- Living Room Mode com controle e mídia física 3D.
- Perfis por dispositivo para controles genéricos, com layout PlayStation, Xbox ou Nintendo e aprendizado de botões.
- Calibração de drift e ajustes de analógicos por controle.
- Central de Sessões com evidências do processo e correção auditável.
- Saúde da Biblioteca e backup portátil do perfil com verificação SHA-256.
- BRUMWORLD: revista interativa com guias visuais do launcher e do aplicativo.
- Aplicativo Android com biblioteca offline, capas, estatísticas e BRUMCOMPANION.
- Aplicativo iOS pessoal em SwiftUI, com o mesmo cache offline, B-CARD e BRUMCOMPANION, preparado para sideload.
- Central BRUM sincronizada com iPhone e Android, limitada ao perfil ativo e sem enviar credenciais ou caminhos locais.
- B-CARD lista jogos instalados no celular e permite iniciar no computador com um gesto autenticado para cima.
- BRUMCOMPANION identifica o jogo ativo e permite consultar ou editar Onde parei, Objetivos, Dicas e Comandos no celular.
- O jogo ativo só aparece no BRUMCOMPANION quando possui alguma anotação; sessões sem conteúdo não criam cartões vazios.
- Durante a sessão, o BRUMCOMPANION acompanha CPU, GPU AMD/Intel/NVIDIA, RAM, VRAM, consumo do processo, duração, temperatura da CPU quando há sensor confiável e FPS real via PresentMon opcional. A coleta isolada pode ser desligada e não salva histórico por padrão.
- BRUMMOMENTS registra capturas do jogo ativo com localização, notas, categorias e favoritos em uma galeria privada disponível offline.
- Anotações e **Quero jogar** podem ser alterados fora da rede; a fila sincroniza ao reencontrar o launcher e conflitos exigem escolha explícita.
- Temas de destaque preservam o layout, incluindo o novo **Vermelho Arcade**.

## Download

Cada plataforma possui uma release identificada, evitando que o botão “mais recente” misture os pacotes:

| Plataforma | Versão | Download e instruções |
| --- | ---: | --- |
| Windows | 1.60.0 | [Release do launcher](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v1.60.0) |
| Android | 0.17.0 | [APK assinado](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/android-v0.17.0) · [Guia](docs/MOVEL.md) |
| iOS pessoal | 0.8.1 | [IPA sem assinatura](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/ios-v0.8.1) · [Guia](ios/README-IOS.md) |

Os hashes SHA-256 acompanham os arquivos publicados. O GitHub hospeda executáveis, APKs e IPAs somente em Releases; esses binários não entram no histórico do repositório.

A versão pessoal para iPhone é compilada separadamente em **Actions → Build iOS pessoal**. O artefato contém um IPA sem assinatura para instalação com AltStore ou Sideloadly. No iOS 0.8.1, Conquistas permite pesquisar jogos e abrir o progresso completo; a Central BRUM acompanha os avisos do launcher 1.59.0 ou posterior. `CLASSICS Everywhere`, horas, capas e sessões continuam disponíveis. Consulte [as instruções do iOS](ios/README-IOS.md) e o [guia do RetroArch compatível](ios/RETROARCH-COMPATIVEL.md).

## Versões atuais

- **Launcher 1.60.0:** lojas, RetroAchievements e RetroArch reunidos em um explorador com conexão acompanhada e monitoramento refinado.
- **Launcher 1.59.0:** sincronização autenticada da Central BRUM com iPhone e Android.
- **Launcher 1.58.0:** Central de Notificações, backup completo e seletivo de perfil, saves e mídias, além de recuperação de encerramentos inesperados.
- **Launcher 1.57.0:** diagnósticos de sessões e RetroAchievements, calibração de controles e Saúde da Biblioteca.
- **Android 0.17.0:** Central BRUM, além de CLASSICS Everywhere, RetroAchievements, capas e horas locais.
- **iOS 0.8.1:** busca de jogos em Conquistas, Central BRUM, abertura pelo RetroArch, sessões móveis e vínculo seguro com o launcher.

Veja o [histórico completo](CHANGELOG.md) e as [notas do Android 0.17.0](releases/android-v0.17.0/RELEASE-NOTES.md).

## Organização do repositório

| Pasta | Conteúdo |
| --- | --- |
| `android/` | Aplicativo Android nativo, testes e Gradle Wrapper |
| `ios/` | Aplicativo iOS em SwiftUI, testes e empacotamento pessoal |
| `docs/` | Guias das experiências móvel, Companion e BRUMWORLD |
| `releases/` | Notas, validações e hashes de cada versão |
| `scripts/` | Auditoria pública e verificação de releases |
| `.github/workflows/` | CI Android, build iOS pessoal e auditoria de segurança |

## Instalação rápida

1. Baixe o executável portátil da [release Windows 1.60.0](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v1.60.0).
2. Execute `BRUMCLASSICS OFICIAL.exe`.
3. Abra **Configurações → Conexões → Explorar conexões** e vincule somente suas próprias contas.
4. Para CLASSICS, coloque somente suas próprias ROMs na pasta `RETROGAMES`.
5. Para o celular, instale o APK e faça o pareamento em **Configurações → MOVEL** na mesma rede local.

## BRUMWORLD

![Sumário da BRUMWORLD](docs/images/brumworld-sumario.png)

Na aba BRUMNEWS, clique na capa da BRUMWORLD. Use `A` e `D` ou as setas laterais para folhear. O guia de biblioteca também ensina a cadastrar um jogo não oficial sem confundi-lo com uma licença Steam.

## Privacidade

- O pacote público é gerado com um perfil local limpo e isolado, sem dados do computador de desenvolvimento.
- Nenhuma credencial é incluída nos arquivos publicados.
- O pareamento móvel acontece na rede local e exige autorização do usuário.
- ROMs, BIOS e jogos comerciais não são fornecidos.

Leia a política completa em [PRIVACY.md](PRIVACY.md).

## Situação do projeto

O BRUMCLASSICS está em desenvolvimento ativo. Integrações de lojas dependem dos clientes e serviços oficiais e podem exigir ajustes quando os provedores alteram seus fluxos.

### Versão 1.44.3 — Um executável permanente

O launcher agora mantém o nome **`BRUMCLASSICS OFICIAL.exe`** em todas as versões. Depois da primeira abertura, use **Configurações → Sistema → Atualizações → ABRIR LOCAL** e fixe esse arquivo uma única vez na barra de tarefas. O launcher também consulta silenciosamente novas versões em toda abertura, sem baixar ou instalar nada sem sua confirmação.

Quem ainda está na 1.44.2 pode atualizar normalmente pelo launcher: a Release inclui um arquivo de transição reconhecido pelo mecanismo antigo. Contas, biblioteca, coleções, saves e configurações permanecem no perfil atual. [Veja todos os detalhes](releases/v1.44.3/RELEASE-NOTES.md).

Se o atualizador da 1.43.1/1.43.2 fechou sem voltar, consulte a [recuperação segura nas notas da 1.43.3](releases/v1.43.3/RELEASE-NOTES.md). O novo mecanismo só passa a ser utilizado após instalar a correção.

![Tema Violeta Nebulosa](docs/images/nebula-theme-1.43.4.png)

Também veja [Ciano Polar](docs/images/polar-theme-1.43.4.png) e [Rosa Synthwave](docs/images/synthwave-theme-1.43.4.png).

## Aviso

BRUMCLASSICS é um projeto independente e não é afiliado, endossado ou patrocinado por Valve, Epic Games, GOG, Electronic Arts, Ubisoft, Sony, Nintendo, Microsoft, Libretro ou RetroAchievements. Marcas pertencem aos seus respectivos proprietários.

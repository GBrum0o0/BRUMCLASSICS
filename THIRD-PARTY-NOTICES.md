# Componentes de terceiros

O BRUMCLASSICS utiliza ou interoperabiliza com componentes e serviços de terceiros. Cada componente permanece sujeito à sua própria licença.

## RetroArch e Libretro

O pacote completo inclui a distribuição oficial RetroArch 1.22.2 para Windows 64-bit e cores Libretro. RetroArch é software livre sob a GNU GPL v3 ou posterior. Os cores podem possuir licenças distintas, inclusive restrições não comerciais.

- Pacote oficial utilizado: https://buildbot.libretro.com/stable/1.22.2/windows/x86_64/RetroArch.7z
- Código-fonte do RetroArch: https://github.com/libretro/RetroArch
- Licença do RetroArch: https://github.com/libretro/RetroArch/blob/master/COPYING
- Resumo de licenças dos cores: https://github.com/libretro/docs/blob/master/docs/development/licenses.md

Os arquivos de licença e avisos que acompanham a distribuição original são preservados dentro da pasta `RetroArch-Win64`.

## mGBA integrado no iOS e Android

Os aplicativos iOS e Android compilam e empacotam o core Libretro mGBA para executar jogos Game Boy, Game Boy Color e Game Boy Advance diretamente no Gaming Mode. mGBA é distribuído sob a Mozilla Public License 2.0. Os builds reproduzíveis usam o commit `7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6` do repositório oficial.

- Código-fonte: https://github.com/libretro/mgba/tree/7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6
- Projeto principal: https://github.com/mgba-emu/mgba
- Licença MPL 2.0: https://github.com/mgba-emu/mgba/blob/master/LICENSE
- API Libretro: https://github.com/libretro/libretro-common/blob/master/include/libretro.h

## Núcleos adicionais do BRUM Core móvel

O aplicativo móvel, licenciado sob GPL-3.0-or-later, também empacota os seguintes núcleos em revisões fixadas. As licenças integrais acompanham o APK/IPA e os scripts públicos reproduzem os builds.

- SkyEmu (Nintendo DS), MIT, revisão `36771a16bfde7eb5c1c0315877b5e465e6f38858`: https://github.com/skylersaleh/SkyEmu
- Geolith (Neo Geo AES/MVS), BSD-3-Clause, revisão `194024931935eff2092e36fc4f8e53e62ed11097`: https://github.com/libretro/geolith-libretro
- Play! (PlayStation 2 experimental, somente Android), BSD-2-Clause, revisão `83700b2c31e593bc94e845b4b31b797be84dda59`: https://github.com/jpd002/Play-
- Gearsystem (Master System/Game Gear), GPL-3.0-or-later, revisão `2d9106f2063d1a6e0661cc8938bb7f8eb737bcae`: https://github.com/drhelius/Gearsystem
- Nestopia UE (NES/Famicom), GPL-2.0-or-later, revisão `8f00f500912a847062de432e38765c7285483e62`: https://github.com/libretro/nestopia
- Beetle PCE Fast (PC Engine/TurboGrafx-16 em cartucho), GPL-2.0-or-later, revisão `3f946f277aef3aa99a95551618bbcd1dd2bda0d9`: https://github.com/libretro/beetle-pce-fast-libretro
- bsnes-mercury Performance (SNES/Super Famicom), GPL-3.0, revisão `79d7f9de218b6ffa65a80bbdc5828532bc239232`: https://github.com/libretro/bsnes-mercury

## Electron, Node.js, Three.js e bibliotecas JavaScript

O executável contém runtimes e dependências de terceiros com licenças próprias. Avisos e licenças empacotados com essas dependências permanecem aplicáveis.

## Marcas e serviços

Steam, Epic Games, GOG, EA App, Ubisoft Connect, Xbox, PlayStation, Nintendo e RetroAchievements pertencem aos seus respectivos proprietários. O BRUMCLASSICS não transfere nem concede direitos sobre essas marcas.

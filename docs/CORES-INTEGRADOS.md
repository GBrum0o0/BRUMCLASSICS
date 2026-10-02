# Política de núcleos integrados

O BRUM Core executa somente núcleos que atendem simultaneamente aos requisitos técnicos, jurídicos e de manutenção abaixo. Um sistema sem núcleo aprovado continua no RetroArch; ele não é apresentado como integrado antes de estar realmente pronto.

O código próprio do aplicativo móvel e do BRUM Core é GPL-3.0-or-later. O launcher de PC continua proprietário e não incorpora nem vincula estes núcleos. Consulte `MOBILE-LICENSING.md` para os limites de escopo e de marca.

## Requisitos obrigatórios

- licença compatível com a licença de distribuição do BRUMCLASSICS;
- texto integral da licença presente no repositório de origem e no aplicativo;
- origem pública, revisão fixada por commit e build reproduzível;
- binários arm64 válidos no Android e no iOS, sem JIT ou download de código executável;
- API Libretro estável, vídeo, áudio, controles, save de bateria e serialização de estados;
- três slots rápidos separados do save normal;
- identidade pelo conteúdo da ROM e metadados com sistema, núcleo e versão;
- teste de abertura, encerramento, persistência, tela cheia, avanço rápido e controle físico;
- nenhuma ROM, BIOS ou conteúdo comercial no código, build ou testes públicos.

## Núcleos aprovados

### mGBA

- Sistemas: Game Boy, Game Boy Color e Game Boy Advance.
- Licença: MPL-2.0.
- Revisão: `7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6`.
- Android: `libmgba_libretro.so`.
- iOS: `mgba_libretro_ios.dylib`.

### SkyEmu

- Sistema: Nintendo DS.
- Licença: MIT.
- Revisão: `36771a16bfde7eb5c1c0315877b5e465e6f38858`.
- Android: `libskyemu_libretro.so`.
- iOS: `skyemu_libretro_ios.dylib`.

### Geolith

- Sistema: Neo Geo AES/MVS em cartuchos `.neo`.
- Licença: BSD-3-Clause.
- Revisão: `194024931935eff2092e36fc4f8e53e62ed11097`.
- Android: `libgeolith_libretro.so`.
- iOS: `geolith_libretro_ios.dylib`.
- Requer `aes.zip` ou `neogeo.zip` fornecido pelo usuário. O arquivo é localizado na pasta autorizada, copiado para o armazenamento privado do BRUM Core e nunca distribuído pelo projeto.

### Play!

- Sistema: PlayStation 2, em caráter experimental.
- Licença: BSD de duas cláusulas.
- Revisão: `83700b2c31e593bc94e845b4b31b797be84dda59`.
- Android arm64: `play_libretro_android.so`.
- iOS: não empacotado, pois a execução prática requer JIT não disponível no fluxo comum de sideload sem permissões especiais.

### Gearsystem

- Sistemas: Master System e Game Gear.
- Licença: GPL-3.0-or-later.
- Revisão: `2d9106f2063d1a6e0661cc8938bb7f8eb737bcae`.
- Android: `libgearsystem_libretro.so`.
- iOS: `gearsystem_libretro_ios.dylib`.

### Nestopia UE

- Sistema: NES/Famicom.
- Licença: GPL-2.0-or-later, distribuído no aplicativo móvel sob GPLv3 ou posterior.
- Revisão: `8f00f500912a847062de432e38765c7285483e62`.
- Android: `libnestopia_libretro.so`.
- iOS: `nestopia_libretro_ios.dylib`.

### Beetle PCE Fast

- Sistema: PC Engine/TurboGrafx-16 em cartuchos `.pce`.
- Licença: GPL-2.0-or-later, distribuído no aplicativo móvel sob GPLv3 ou posterior.
- Revisão: `3f946f277aef3aa99a95551618bbcd1dd2bda0d9`.
- Android: `libmednafen_pce_fast_libretro.so`.
- iOS: `mednafen_pce_fast_libretro_ios.dylib`.
- PC Engine CD permanece no fallback: imagens `.cue` dependem de arquivos associados e BIOS fornecida pelo usuário, fluxo que ainda não foi validado no armazenamento coordenado móvel.

### bsnes-mercury Performance

- Sistema: SNES/Super Famicom em cartuchos `.sfc` e `.smc`.
- Licença: GPL-3.0.
- Revisão: `79d7f9de218b6ffa65a80bbdc5828532bc239232`.
- Perfil: `performance`, sem incorporar código do Snes9x.
- Android: `libbsnes_mercury_performance_libretro.so`.
- iOS: `bsnes_mercury_performance_libretro_ios.dylib`.

## Matriz dos 20 grupos solicitados

| # | Sistema | Android | iOS | Situação atual |
|---:|---|---|---|---|
| 1 | NES/Famicom | **BRUM Core · Nestopia UE** | **BRUM Core · Nestopia UE** | Integrado sob GPL-2.0-or-later/GPLv3+. |
| 2 | SNES/Super Famicom | **BRUM Core · bsnes-mercury Performance** | **BRUM Core · bsnes-mercury Performance** | Integrado sob GPL-3.0; Snes9x não foi incorporado. |
| 3 | Nintendo 64 | RetroArch | RetroArch | Mupen64Plus-Next ainda precisa de auditoria da revisão e testes; no iOS o desempenho é limitado sem JIT comum. |
| 4 | Nintendo DS | **BRUM Core · SkyEmu** | **BRUM Core · SkyEmu** | Integrado, permissivo e fixado por commit. |
| 5 | Master System | **BRUM Core · Gearsystem** | **BRUM Core · Gearsystem** | Integrado sob GPL-3.0-or-later. |
| 6 | Game Gear | **BRUM Core · Gearsystem** | **BRUM Core · Gearsystem** | Integrado sob GPL-3.0-or-later. |
| 7 | Mega Drive/Genesis | RetroArch | RetroArch | Genesis Plus GX foi rejeitado pela restrição não comercial; alternativa GPL ainda precisa de build/testes móveis. |
| 8 | PC Engine/TurboGrafx-16 | **BRUM Core · Beetle PCE Fast** | **BRUM Core · Beetle PCE Fast** | Cartuchos `.pce` integrados sob GPL-2.0-or-later/GPLv3+; PC Engine CD permanece no fallback. |
| 9 | PlayStation 1 | RetroArch | RetroArch | Núcleo GPL compatível ainda precisa de revisão fixada, build e testes móveis. |
| 10 | PSP | RetroArch | RetroArch | PPSSPP exige integração de recursos e renderização; iOS também depende de condições especiais para melhor desempenho. |
| 11 | Dreamcast | RetroArch | RetroArch | Flycast depende de aceleração gráfica/JIT e ainda precisa de auditoria de licença/revisão por plataforma. |
| 12 | Sega Saturn | RetroArch | RetroArch | Núcleo compatível ainda precisa de revisão fixada, build e testes móveis. |
| 13 | Sega CD e 32X | RetroArch | RetroArch | Genesis Plus GX e PicoDrive foram rejeitados por restrições não comerciais; alternativa GPL ainda não foi validada. |
| 14 | Neo Geo | **BRUM Core · Geolith** | **BRUM Core · Geolith** | AES/MVS `.neo` integrado; BIOS é responsabilidade do usuário. CD ainda permanece no fallback. |
| 15 | Arcade (FBNeo/MAME) | RetroArch | RetroArch | FBNeo foi rejeitado pela restrição não comercial; MAME exige auditoria arquivo a arquivo e testes móveis antes de distribuição. |
| 16 | Atari 2600/5200/7800/Lynx | RetroArch | RetroArch | O grupo exige vários núcleos, revisões compatíveis e uma validação conjunta ainda não concluída. |
| 17 | WonderSwan/Color | RetroArch | RetroArch | Núcleo GPL ainda precisa de confirmação de variante de licença, build e testes móveis. |
| 18 | PlayStation 2 | **BRUM Core · Play! experimental** | Indisponível no BRUM Core | Android usa o núcleo permissivo Play!; no iOS ele exige JIT. |
| 19 | Nintendo 3DS | RetroArch | RetroArch/indisponível | Família Citra/Lime3DS exige recursos elevados e auditoria da revisão; iOS é especialmente limitado sem JIT comum. |
| 20 | GameCube | RetroArch | RetroArch/indisponível | Dolphin exige integração gráfica/JIT; iOS depende de permissões especiais para desempenho prático. |

O fallback apenas encaminha o jogo a uma instalação separada do RetroArch. Ele não é anunciado como suporte nativo do BRUM Core e nenhum núcleo de terceiros é baixado silenciosamente.

O licenciamento GPL foi aplicado somente ao aplicativo móvel e ao BRUM Core. A expansão dos demais grupos continua condicionada a build reproduzível, desempenho real, saves/estados e ausência de cláusulas não comerciais. Fallback do RetroArch nunca conta como suporte nativo.

Referências oficiais:

- <https://docs.libretro.com/library/nestopia/>
- <https://docs.libretro.com/library/quicknes/>
- <https://github.com/libretro/libretro-core-info/blob/master/nes_libretro.info>
- <https://github.com/TSnake41/ludus-libretro>
- <https://docs.libretro.com/development/licenses/>
- <https://github.com/skylersaleh/SkyEmu>
- <https://github.com/libretro/geolith-libretro>
- <https://github.com/drhelius/Gearsystem>
- <https://github.com/libretro/nestopia>
- <https://github.com/libretro/beetle-pce-fast-libretro>
- <https://github.com/libretro/bsnes-mercury>
- <https://github.com/jpd002/Play->
- <https://docs.libretro.com/library/play/>
- <https://docs.libretro.com/guides/install-ios/>

## Arquitetura multicore

Cada plataforma mantém um registro com:

- identificador e nome exibido;
- versão fixada;
- licença;
- sistemas suportados;
- nome real da biblioteca nativa.

O launcher da sessão recebe esse descritor e nunca presume que o núcleo seja mGBA. Saves e estados rápidos registram a versão exata. Dessa forma, um novo núcleo aprovado pode entrar sem alterar o host Libretro, a Activity, o controlador iOS ou o formato básico dos slots.

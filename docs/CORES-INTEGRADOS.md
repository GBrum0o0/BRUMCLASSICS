# Política de núcleos integrados

O BRUM Core executa somente núcleos que atendem simultaneamente aos requisitos técnicos, jurídicos e de manutenção abaixo. Um sistema sem núcleo aprovado continua no RetroArch; ele não é apresentado como integrado antes de estar realmente pronto.

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

## Núcleo aprovado

### mGBA

- Sistemas: Game Boy, Game Boy Color e Game Boy Advance.
- Licença: MPL-2.0.
- Revisão: `7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6`.
- Android: `libmgba_libretro.so`.
- iOS: `mgba_libretro_ios.dylib`.

## NES — avaliação atual

NES permanece no fallback do RetroArch até existir um núcleo que cumpra todos os requisitos.

- FCEUmm, Nestopia e QuickNES são distribuídos sob GPL nas fontes oficiais consultadas. Eles não serão empacotados enquanto o projeto mantiver a licença binária atual.
- O port de aiju possui metadado externo indicando ISC, mas o repositório-fonte avaliado não contém um arquivo de licença. Além disso, o catálogo declara ausência de save Libretro. Não foi aprovado.
- Ludus Libretro possui licença MIT, porém a versão disponível é um protótipo inicial e não implementa serialização de estados nem save de bateria. Não foi aprovado.

Referências oficiais:

- <https://docs.libretro.com/library/nestopia/>
- <https://docs.libretro.com/library/quicknes/>
- <https://github.com/libretro/libretro-core-info/blob/master/nes_libretro.info>
- <https://github.com/TSnake41/ludus-libretro>

## Arquitetura multicore

Cada plataforma mantém um registro com:

- identificador e nome exibido;
- versão fixada;
- licença;
- sistemas suportados;
- nome real da biblioteca nativa.

O launcher da sessão recebe esse descritor e nunca presume que o núcleo seja mGBA. Saves e estados rápidos registram a versão exata. Dessa forma, um novo núcleo aprovado pode entrar sem alterar o host Libretro, a Activity, o controlador iOS ou o formato básico dos slots.

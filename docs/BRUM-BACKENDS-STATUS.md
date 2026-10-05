# BRUM Core: integração incremental de backends

Estado em 04/10/2026, branch `codex/brum-backends`. Este documento distingue
infraestrutura implementada, compilação e validação real de jogos. Compilar um
núcleo não o promove automaticamente a suporte do BRUM Core.

## Pontos de conexão preservados

1. `CoreRegistry.core(for:)` continua sendo a lista de núcleos do app atual.
   `candidate(for:)` é uma lista separada de integrações em desenvolvimento.
2. `EmulationLaunchBuilder` mantém identidade SHA-256, seleção do núcleo e
   diretórios de saves; o chamador existente não foi reescrito.
3. `BrumLibretroViewController` implementa `BrumBackendSession`: iniciar,
   executar, pausar, retomar, encerrar, input por origem, SRAM e save states.
   O adapter continua no controlador existente nesta primeira etapa.
4. Capacidades são consultadas após carregar o jogo. Save state exige tamanho
   válido e serialização; touch e múltiplas telas dependem do perfil de vídeo.
   Achievements, rewind, streaming e remote input **não são anunciados**.
5. `shared/brum-core/ScreenManager.hpp` calcula posição, proporção, escala,
   rotação e transformação inversa de toque, sem dependências de DS ou UIKit.
6. `BrumScreenProfiles.hpp` é a parte específica dos adapters: separa o atlas
   nativo do SkyEmu (256×384) e prepara o do Citra (400×480). Uma saída de
   tamanho inesperado permanece única e sem touch, sem adivinhar coordenadas.
7. `InputState.hpp` combina botões por origem. Soltar o controle virtual não
   solta um botão ainda pressionado no controle físico. Teclado e rede possuem
   origens reservadas, mas seus transportes ainda não estão conectados.

## Telas e Split Screen

DS usa seis layouts no menu TELAS: vertical, vertical invertido, horizontal,
horizontal invertido, primária e secundária. Há rotação em passos de 90° e
escala de 75%/100%. O toque é convertido da tela apresentada para o atlas do
adapter. O teste cobre também o tamanho diferente das telas do 3DS.

`screenDisplays` mapeia IDs estáveis de tela para destinos; `displayID` seleciona
as telas a posicionar em um destino. O padrão é `local`. `surfaceID` identifica
a superfície de origem. Isso é um contrato de roteamento, **não streaming**.
O adapter UIKit atual consome um atlas local; texturas independentes e transporte
PC/celular são passos futuros, sem necessidade de mudar os cálculos de layout.

## Saves e estabilidade

- Preservados SRAM, identidade por conteúdo, manifesto com hash/geração e três
  slots com metadados de núcleo/versão. Não há nova migração destrutiva de saves.
- Menus pausam emulação/áudio. Pausa explícita é independente de background e
  interrupção de áudio, evitando retomada automática atrás de um menu.
- Fontes de input e toque são liberadas ao pausar/encerrar.
- Falha na inicialização encerra os recursos parcialmente abertos e mantém o
  erro na tela. Falhas de áudio são reportadas; os relatos em aparelho ainda
  precisam de reprodução com jogo, dispositivo e versão do iOS.
- Descritores CUE/M3U/GDI copiam as faixas locais referenciadas com leitura
  coordenada. Caminhos externos são rejeitados. Falha remove somente a cópia
  temporária daquela tentativa; arquivos originais permanecem intactos.
- O adapter GLES experimental limita alocações e recusa APIs incompatíveis.
  Ele não torna um núcleo desktop automaticamente compatível com iOS.
- Os builds são isolados por núcleo. Uma falha nativa dentro de um núcleo
  carregado ainda pode encerrar o processo iOS: não há isolamento por processo.

## Controle do N64 no build experimental

O padrão do N64 usa agora um stick virtual circular: arrastar envia eixos
analógicos graduais para o Mupen64Plus-Next; soltar recentraliza. O botão
`D-PAD` alterna para as setas digitais quando um jogo precisa delas, e
`STICK` retorna ao analógico. Os botões visíveis são A/B, Z, L/R, Start e
quatro C. A/B e o eixo X dos botões C são mapeados especificamente para a
revisão fixada do núcleo; controle físico mantém analógico esquerdo e direito.
Alternar pad, pausar ou encerrar libera os eixos para evitar movimento preso.
Ainda é necessário validar sensibilidade e ergonomia em aparelho.

## Situação por sistema

| Sistema | Backend | Situação nesta etapa |
|---|---|---|
| GB/GBC/GBA, NES e demais núcleos anteriores | mGBA, Nestopia, Geolith, Gearsystem, PCE Fast, bsnes, WonderSwan | Mantidos na lista ativa e no empacotamento anterior; regressão em aparelho pendente |
| DS | SkyEmu | Conectado ao Screen Manager; testes de geometria/toque passaram; teste de jogo no iPhone pendente |
| N64 | Mupen64Plus-Next | Empacotado apenas no IPA experimental build 38 com GLES/HLE sem dynarec e controle analógico; teste em aparelho pendente |
| PS1 | Beetle PSX | Empacotado apenas no IPA experimental com BIOS do usuário; teste em aparelho pendente |
| Saturn | Beetle Saturn | Empacotado apenas no IPA experimental build 37; desempenho, BIOS do usuário e teste em aparelho pendentes |
| Atari 2600 | Stella2014 | Empacotado apenas no IPA experimental; teste em aparelho pendente |
| PSP / Dreamcast | PPSSPP / Flycast | Empacotados em IPA experimental arm64 com analógico e botões próprios; ainda sem comprovação de execução/áudio em aparelho |
| 3DS | Citra | Compilou arm64 e tem perfil de telas; host ainda não oferece a API gráfica exigida, portanto não está no IPA |
| GameCube | Dolphin | Compilou arm64 genérico sem JIT; não empacotado, renderer e desempenho não validados |
| PS2 | Play! | Descriptor preparado reaproveitando revisão Android; adapter/renderização e execução sem JIT iOS não validados |
| Mega Drive, Sega CD/32X | BlastEm | Revisão GPL-3.0+ e mapeamento de BIOS/botões empacotados no IPA experimental build 40; jogos em aparelho pendentes |
| Arcade genérico | Em avaliação | Sem backend aprovado nesta etapa; não entra como suporte integrado |

## Registro de problemas e alternativas

### N64 / PS1: checkout de dependências

- **Problema:** primeira tentativa falha antes de compilar.
- **Causa:** gitlinks de `gnulib` sem entrada `.gitmodules` nas revisões fixadas.
- **Impacto:** apenas os respectivos jobs; app e Stella passaram.
- **Alternativas:** reconstruir dependências do JIT ou usar dependências vendorizadas.
- **Solução:** usar fontes vendorizadas. N64 usa GLideN64/HLE sem paraLLEl/Vulkan
  e sem dynarec; PS1 já desliga Lightrec no alvo iOS upstream.
- **Status:** checkout corrigido; N64 exigiu corrigir teste de headers Classic
  Mac (`fp.h`) em libpng/zlib. A compilação arm64 de N64 e PS1 passou no
  [workflow 37191135796](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37191135796).
  PS1 está no IPA experimental; N64 ainda não. Sem teste de jogos.

### Dreamcast: header gráfico de desktop

- **Problema:** Flycast inclui `OpenGL/gl3.h`, inexistente no SDK iOS.
- **Causa:** CMake seleciona GLES, mas o header Libretro depende também da
  macro C/C++ `IOS`, que não foi definida no alvo.
- **Impacto:** apenas Flycast.
- **Alternativas:** corrigir definição de plataforma ou atualizar libretro-common.
- **Solução:** fornecer `IOS=1` ao compilador, mantendo o ramo de link OpenGLES.
- **Status:** compilação arm64 passou no workflow 37191135796; negociação
  gráfica e execução ainda pendentes.

### Receita de build: Bash do macOS

- **Problema:** jobs simples abortaram na segunda rodada com `EXTRA[@]: unbound variable`.
- **Causa:** Bash 3.2 trata array vazio como indefinido com `set -u`.
- **Impacto:** Stella/Saturn/PS1, sem alterar seus fontes.
- **Alternativas:** evitar array vazio ou exigir Bash moderno.
- **Solução:** inicializar a lista com `DEBUG=0` antes dos argumentos específicos.
- **Status:** receita corrigida; sucesso anterior de Stella continua sendo apenas
  evidência de compilação, não de integração jogável.

### PSP: ferramenta de build

- **Problema:** CMake interrompe a configuração de armips.
- **Causa:** dependência antiga solicita compatibilidade removida pelo CMake 4.
- **Impacto:** somente PPSSPP.
- **Alternativas:** atualizar dependência, adaptar política ou fixar CMake antigo.
- **Solução:** testar política mínima 3.5; patch também retira `-Bsymbolic` do
  linker Apple, onde essa opção ELF não é válida.
- **Status:** a configuração/compilação chegou ao linker, que revelou
  símbolos `Native*` do aplicativo iOS e funções NEON ausentes. O patch de
  teste exclui o frontend iOS do alvo Libretro e reconhece `arm64` como
  ARM64. A etapa seguinte chegou ao linker e encontrou apenas a chamada de
  framebuffer do app iOS (`bindDefaultFBO`) e o filtro NEON do libpng. O
  primeiro não pertence ao Libretro (que já define seu framebuffer), e o
  segundo foi desativado para este build. O workflow 37231008525 compilou
  o núcleo arm64; build experimental com assets e input está em validação.
  JIT, renderização e jogos em aparelho pendentes.

### 3DS: MoltenVK e API de renderização

- **Problema:** Citra não encontra MoltenVK; o adapter Libretro solicita OpenGL
  desktop 3.3, ou GLES 3.2 se recompilado com `USING_GLES`.
- **Causa:** downloader upstream procura diretório dylib antigo; host atual
  oferece apenas GLES 2/3.0, não OpenGL desktop nem GLES 3.2.
- **Impacto:** 3DS não está disponível para jogar, mesmo com perfil de duas telas.
- **Alternativas:** corrigir dependência, adapter Vulkan/Metal, camada de
  compatibilidade ou outro backend com renderer iOS adequado.
- **Solução:** primeiro fixar MoltenVK 1.2.8, SHA-256 e slice estático ios-arm64;
  depois adaptar a negociação gráfica. Não reduzir artificialmente a versão
  solicitada nem anunciar que o host oferece uma API que não implementa.
- **Status:** a segunda tentativa encontrou o slice MoltenVK e avançou até
  glslang, cujo otimizador exigia SPIRV-Tools ausente. A receita desliga apenas
  esse otimizador (`ENABLE_OPT=OFF`), preservando a compilação de shaders.
  A etapa seguinte revelou que CMake upstream sobrescreve o deployment
  target 16.3 para 14.0, deixando `std::to_chars` indisponível. O patch
  experimental preserva 16.3. O build avançou ao linker, onde MoltenVK
  revelou os frameworks Foundation, UIKit e CoreGraphics ausentes. Eles foram
  adicionados à receita experimental, e o workflow 37231008525 compilou
  o núcleo arm64. O app de
  produção suporta iOS 16.0; promover Citra exigiria resolver essa diferença,
  além do renderer. Renderer ainda em desenvolvimento.

### GameCube: arquitetura não detectada

- **Problema:** Dolphin aborta a configuração com arquitetura vazia.
- **Causa:** cross-build iOS não definiu `CMAKE_SYSTEM_PROCESSOR`.
- **Impacto:** somente Dolphin.
- **Alternativas:** toolchain iOS completo ou parâmetros explícitos.
- **Solução:** informar arm64 e testar `ENABLE_GENERIC=ON` sem JIT.
- **Status:** compilação arm64 genérica passou no workflow 37191135796;
  desempenho de jogos ainda desconhecido.

### Mega Drive / CD / 32X / arcade: licenciamento

- **Problema:** a política do repositório exclui componentes não comerciais.
- **Causa:** os candidatos Genesis Plus GX/PicoDrive/FBNeo avaliados contêm
  restrições incompatíveis com essa política; não basta renomeá-los de backend.
- **Impacto:** permanecem fora do pacote e da lista ativa.
- **Alternativas:** BlastEm GPL-3.0+ para Mega Drive, Sega CD e 32X; MAME
  moderno para arcade, com auditoria por componente.
- **Solução:** BlastEm foi fixado na revisão
  `1e0de94dc7e669c0925a22c0fccf6cdc837af0a0`, cujo alvo `ios-arm64` não
  exige JIT. A receita inclui COPYING e avisos de zlib/libchdr/LZMA. O núcleo
  pede BIOS do usuário com nomes exatos para Sega CD e 32X.
- **Status:** compilou e foi empacotado no IPA experimental 40; ainda sem
  teste de jogo. Arcade permanece sem backend aprovado.

## Evidência e aceitação

O [IPA experimental 0.15.1 build 36](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37191135993)
foi gerado sem assinatura para Sideloadly, com PS1 e Atari 2600 além dos oito
núcleos previamente integrados. A validação estrutural local passou: arm64, bibliotecas,
licenças e hash SHA-256 `f8b261d54a87797af9c7e8659a2ee18b8f616942162bc2c159ae0d10603fc4fa`.
O [IPA experimental build 37](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37209353162)
acrescenta N64 e Saturn. Passou nos testes do simulador e na validação local
dos 12 núcleos, suas licenças e integridade ZIP/Mach-O. Seu SHA-256 é
`79913b3ea35fd4ab3560509ba8dd3b0aae6149eab55e14097eb17133aeca71db`.
O host compilou e passou testes de modelos/UI no simulador; o contrato
portátil passou 19.191 verificações em MSVC/Windows. Os 18 testes Python
do validador passaram. Esses testes não executam ROMs comerciais nem
comprovam áudio em aparelho.

O [IPA experimental build 38](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37231008787)
passou novamente com controle analógico N64 e 12 núcleos. SHA-256:
`687b2a09bd9d1d5d4d20ddcb10dc7b356bb9f6a23078f4c2469f4835c651823c`.
O [IPA experimental build 40](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37250085938)
passou no simulador e empacotou 15 núcleos arm64, incluindo PPSSPP, Flycast e
BlastEm, além dos recursos do PSP e avisos de licença. SHA-256:
`851e9d159ff05ee23f0e6435a39226b0a448d2d1922bb6106d5f5fa28821bba0`.
Isto valida integridade e compilação, não compatibilidade real de jogos nem
ausência de falhas de áudio ou encerramento no iPhone.

Antes de ativar cada candidato: iniciar ROM legal de teste, verificar vídeo e
áudio contínuos, pad virtual/físico, pausa/menu/background/interrupção, retorno
ao Gaming Mode, save/reabertura e save states quando anunciados. Para DS/3DS,
testar touch nos seis layouts e quatro rotações. Registrar dispositivo, iOS,
revisão, BIOS fornecida pelo usuário, resultado e limitações. Achievements
exige runtime e mapa de memória validados, não apenas identificação do console.

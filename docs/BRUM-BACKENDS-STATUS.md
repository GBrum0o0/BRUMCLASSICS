# BRUM Core: integração incremental de backends

Estado em 03/10/2026, branch `codex/brum-backends`. Este documento distingue
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

## Situação por sistema

| Sistema | Backend | Situação nesta etapa |
|---|---|---|
| GB/GBC/GBA, NES e demais núcleos anteriores | mGBA, Nestopia, Geolith, Gearsystem, PCE Fast, bsnes, WonderSwan | Mantidos na lista ativa e no empacotamento anterior; regressão em aparelho pendente |
| DS | SkyEmu | Conectado ao Screen Manager; testes de geometria/toque passaram; teste de jogo no iPhone pendente |
| N64 | Mupen64Plus-Next | Candidato; build GLES/HLE sem dynarec em validação |
| PS1 | Beetle PSX | Candidato; build sem Lightrec em validação; exige BIOS do usuário |
| Saturn | Beetle Saturn | Candidato; build independente; desempenho e BIOS pendentes |
| Atari 2600 | Stella2014 | Compilação arm64 passou; ainda não empacotado nem validado jogando |
| PSP / Dreamcast | PPSSPP / Flycast | Candidatos; toolchains iOS em validação |
| 3DS | Citra | Perfil de telas preparado; dependências e API gráfica ainda bloqueiam integração jogável |
| GameCube | Dolphin | Candidato; configurando build genérico sem JIT, desempenho não validado |
| PS2 | Play! | Descriptor preparado reaproveitando revisão Android; adapter/renderização e execução sem JIT iOS não validados |
| Mega Drive, Sega CD/32X, arcade genérico | Em avaliação | Sem backend aprovado nesta etapa; não entram como suporte integrado |

## Registro de problemas e alternativas

### N64 / PS1: checkout de dependências

- **Problema:** primeira tentativa falha antes de compilar.
- **Causa:** gitlinks de `gnulib` sem entrada `.gitmodules` nas revisões fixadas.
- **Impacto:** apenas os respectivos jobs; app e Stella passaram.
- **Alternativas:** reconstruir dependências do JIT ou usar dependências vendorizadas.
- **Solução:** usar fontes vendorizadas. N64 usa GLideN64/HLE sem paraLLEl/Vulkan
  e sem dynarec; PS1 já desliga Lightrec no alvo iOS upstream.
- **Status:** checkout corrigido; a segunda tentativa de N64 chegou ao
  compilador e encontrou headers clássicos de Mac (`fp.h`) em libpng. Patch
  remove o teste inadequado de `TARGET_OS_MAC` em libpng/zlib, preservando
  suporte Classic Mac. Ainda sem teste de jogos.

### Dreamcast: header gráfico de desktop

- **Problema:** Flycast inclui `OpenGL/gl3.h`, inexistente no SDK iOS.
- **Causa:** CMake seleciona GLES, mas o header Libretro depende também da
  macro C/C++ `IOS`, que não foi definida no alvo.
- **Impacto:** apenas Flycast.
- **Alternativas:** corrigir definição de plataforma ou atualizar libretro-common.
- **Solução:** fornecer `IOS=1` ao compilador, mantendo o ramo de link OpenGLES.
- **Status:** correção na receita; negociação gráfica e execução ainda pendentes.

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
- **Status:** nova configuração em validação; JIT/renderização/input pendentes.

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
- **Status:** dependência corrigida na receita; renderer ainda em desenvolvimento.

### GameCube: arquitetura não detectada

- **Problema:** Dolphin aborta a configuração com arquitetura vazia.
- **Causa:** cross-build iOS não definiu `CMAKE_SYSTEM_PROCESSOR`.
- **Impacto:** somente Dolphin.
- **Alternativas:** toolchain iOS completo ou parâmetros explícitos.
- **Solução:** informar arm64 e testar `ENABLE_GENERIC=ON` sem JIT.
- **Status:** nova compilação em validação; desempenho de jogos ainda desconhecido.

### Mega Drive / CD / 32X / arcade: licenciamento

- **Problema:** a política do repositório exclui componentes não comerciais.
- **Causa:** os candidatos Genesis Plus GX/PicoDrive/FBNeo avaliados contêm
  restrições incompatíveis com essa política; não basta renomeá-los de backend.
- **Impacto:** permanecem fora do pacote e da lista ativa.
- **Alternativas:** avaliar BlastEm/outros engines para MD, MAME moderno para
  arcade e dependências substituíveis de 32X/CD, com auditoria por componente.
- **Solução:** selecionar implementação compatível antes de incorporar binários.
- **Status:** investigação necessária; nenhuma dessas alternativas está declarada pronta.

## Evidência e aceitação

Primeiro build: [GitHub Actions 37137257052](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/37137257052).
O host compilou e passou 41 testes de modelos + 2 testes de UI no simulador.
O contrato portátil passou 19.185 verificações em MSVC/Windows e Clang/macOS.
O validador de projeto e os 16 testes Python do empacotador passaram.
Esses testes não executam ROMs comerciais nem comprovam áudio em aparelho.

Antes de ativar cada candidato: iniciar ROM legal de teste, verificar vídeo e
áudio contínuos, pad virtual/físico, pausa/menu/background/interrupção, retorno
ao Gaming Mode, save/reabertura e save states quando anunciados. Para DS/3DS,
testar touch nos seis layouts e quatro rotações. Registrar dispositivo, iOS,
revisão, BIOS fornecida pelo usuário, resultado e limitações. Achievements
exige runtime e mapa de memória validados, não apenas identificação do console.

# PSP no BRUMCLASSICS+

O Gaming Mode executa PSP dentro do aplicativo, por meio do núcleo PPSSPP Libretro. Não abre um aplicativo externo. O código do PPSSPP é de terceiros e mantém sua autoria e licença.

## Arquivos e controles

- Importe jogos `.iso`, `.cso` ou `.pbp` que você tenha direito de utilizar. Para imagens ISO/PBP, selecione a categoria PSP para evitar confusão com outros consoles.
- O aplicativo inclui os recursos de apoio do núcleo; não inclui jogos ou firmware comercial. PPSSPP usa implementação HLE e não exige BIOS de PSP.
- O controle utiliza direcional, analógico esquerdo, quatro botões de ação, L/R, Start e Select. Controles físicos seguem o mesmo encaminhamento de entrada da sessão integrada.
- Saves nativos de PSP são arquivos na pasta privada de saves da sessão, incluindo a árvore `PSP/SAVEDATA`. Não equivalem a um bloco de SRAM de cartucho. Save Sync e save states não devem ser anunciados como equivalentes ao save feito no menu do jogo.

## iPhone

A IPA destinada ao Sideloadly usa o interpretador do PPSSPP, sem depender de ativação de JIT ou permissões especiais. Na revisão `0.24.0` (build `57`), foram corrigidas causas reais de fechamento na abertura de `.iso` no iPhone:

- inspeção e hash por streaming POSIX (`open`/`read` com buffer fixo de 1 MB) em `EmulationFoundation.swift`, eliminando o acúmulo de objetos autorelease/OOM (Jetsam) em imagens grandes;
- guardas pré-1º frame para `retro_serialize_size`/`retro_serialize` antes de `!PSP_IsInited() || !gpu`, inicialização incondicional de resolução ao relançar o jogo no mesmo processo e proteção de `decJitCache_` nulo e contexto GL em `ContextDestroy` (`ios/patches/ppsspp-ios-libretro.patch`);
- remoção estrita de `PROT_EXEC`/`mprotect` executável em `Common/MemoryUtil.cpp` no iOS sem JIT, pilha `pthread` de 2 MB na `EmuThread` e sondagem ASLR ampliada em `Core/System.cpp`.

Isso pode reduzir bastante o desempenho dependendo do jogo e do aparelho. A inclusão do núcleo não garante 60 FPS nem compatibilidade com toda a biblioteca de PSP.

## Validação

O build e os testes de contratos (incluindo patches `--unidiff-zero`, `BrumTestCore` com simulação pré-1º frame e inspector streaming em `.iso` multi-chunk) verificam integração, arquivos de apoio e empacotamento. São distintos da validação física de imagem, áudio, comandos e persistência em aparelho real, que continua marcada como **aguarda validação no aparelho** até confirmação em gameplay no iPhone e no Android.

Para confirmar um jogo, registre título/hash, versão do aplicativo, aparelho, passos e pelo menos cinco minutos de gameplay ativo. Verifique movimento, menus, áudio, encerramento e recuperação por **Continue** quando o jogo oferecer save. Sem essa execução, o resultado permanece **aguarda validação no aparelho**.

## Fonte correspondente e licenças

Referência fixada: [libretro/ppsspp, revisão 7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8](https://github.com/libretro/ppsspp/tree/7b4ddb426bbe9e287bb7f19b0cfaebb4ea0d41d8). Scripts de build e patches de cada plataforma estão em `android/` e `ios/` desta mesma revisão do Brum Classics. As licenças integrais acompanham os binários; consulte também `THIRD-PARTY-NOTICES.md` e `MOBILE-LICENSING.md`.

Referência de funcionamento: [documentação oficial Libretro do PPSSPP](https://docs.libretro.com/library/ppsspp/).

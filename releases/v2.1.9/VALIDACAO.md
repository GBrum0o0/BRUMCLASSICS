# Validação — Launcher PC 2.1.9 experimental

## Escopo e fontes

Publicação de teste autorizada pelo usuário, sem certificação dos 32 sistemas. Base do Launcher: 2.1.8, commit interno d1f8fc1. Snapshot do Antigravity: `8b9dda1ac8ac394508517ead6c5108ff47331b67`, ainda atual na conferência. Importados quatro arquivos GBA/GBC do diff desde 69c02e0 e somente a descoberta de compilador dos scripts, mantendo /W4 /WX e os defines autorais obrigatórios. Não importado o main.cpp antigo da raiz, relatórios de conclusão total, fallback, libretro ou ferramentas internas.

Fonte interna: `0ea716443f6fca8bb7c3e4518b59979d3d22946f`. Árvore Git: `e2259c83bd4953f4b95bb2a4e40eff53d4c94114`. A raiz do Antigravity e scratch/ foram preservados; integração e compilação em cópia isolada.

## Revisão e correções de segurança

Revisão independente encontrou cinco regressões bloqueantes, reproduzidas antes da correção em processos isolados:

- Acesso largo na última posição de RAM: corrompia região adjacente; agora o fastpath verifica a largura e usa despacho seguro nas bordas.
- DMA escrevendo no próprio controle: stack overflow, exit -1073741571; adicionado bloqueio de reentrada com liberação por RAII.
- Divisão INT_MIN/-1: encerramento do processo, exit -1073741675; cálculo ampliado para 64 bits e resultado convertido aos registradores.
- IRQs aninhadas sem limite: crescimento do vetor; teto defensivo de 256 níveis encerra o caso patológico com erro controlado, sem limitar FPS ou hardware.
- Save GBA alterado de 64 para 128 KiB sem mudança de contrato: rejeitava o save existente; mantido `gba-sram-v1` de 64 KiB. Não se anuncia Flash/EEPROM completos.

Os cinco casos passaram após recompilação. Foram adicionadas quatro regressões à suíte nativa; a regressão de save usa o teste de ciclo de vida existente. Não houve segunda revisão independente depois das correções; a confirmação posterior foi feita por compilação, testes e regressões pelo coordenador.

Pendências menores aceitas para esta build experimental: reset GBA após Halt e fase residual do divisor PPU GBC. Não certificadas fidelidade CPU/PPU/APU, sessões longas, progressão ou compatibilidade comercial dos 32 módulos.

## Testes executados

- Build completa nativa, diagnósticos e observador de sessão: exit 0; **241 testes nativos aprovados**, gameplayReady=false.
- Suíte completa do Launcher: **837 testes, 836 aprovados, zero falhas, um ignorado** por dependência opcional de DLL libretro real. Não foi dispensada falha para publicar.
- Verificação de sintaxe: npm run check, exit 0.
- Integração e vídeo: **10/10**, incluindo persistência/reabertura isolada GB/GBC, descrição dos módulos, NES sintético/Start, captura BMP sem sobrescrita e janela GDI oculta.
- GBC com LCD desligado agora conclui frame por ciclos. O teste antigo dependia do defeito anterior; substituído por fixture isolada do watchdog real, extraído sem alteração para header compartilhado, que encerra trabalho bloqueado com código 3 antes do timeout externo. Acrescentado teste separado de LCD desligado do GBC. A fixture não é distribuída.
- Smoke Electron: assertions DOM aprovadas para 32 módulos, ação autoral exclusiva e nenhuma consulta a estado externo. Capturas offscreen apresentaram atraso de pintura e **não são certificação visual**.

## Saída inicial de ROMs pessoais

Cada teste executou 600 frames headless, com saves/capturas temporários exclusivos. Todos os nove processos terminaram com código 0 e as ROMs mantiveram SHA-256 idêntico. Nenhum save original, perfil ou Vault foi modificado.

| Sistema / jogo | Cores no frame final | Amostras PCM não zeradas |
|---|---:|---:|
| GB / Pokémon Red | 4 | 152892 |
| NES / Super Mario Bros. 3 | 3 | 721972 |
| GBA / Pokémon FireRed | 7 | 57924 |
| SNES / Super Mario World | 1, preto | 0 |
| N64 / Super Mario 64 | 1, preto | 0 |
| DS / Super Mario 64 DS | 1, preto | 0 |
| GBC / Pokémon Crystal | 3 | 232926 |
| GBC / Pokémon Yellow | 2 | 430318 |
| GBA / Yoshi's Island | 14 | 0 |

Contagem de cores e PCM não provam imagem correta, áudio audível/fiel, gameplay ou save correto do jogo inteiro. FireRed apresentou avanço de inicialização em comparação à tela branca da 2.1.8. Yoshi's Island ficou sem áudio, e os defeitos conhecidos do áudio NES permanecem. SNES/N64/DS continuam sem funcionamento comprovado nesses jogos.

Saves autorais permanecem isolados por perfil/sistema/SHA256 em murb-test-saves. A integridade do container não garante a fidelidade da implementação de persistência do core. Sem aplicação automática do Vault, save states ou desbloqueios online no runtime experimental. Sem ROMs ou BIOS no pacote.

## Pacote final

- Build Windows x64 de distribuição concluída com exit 0, fonte interna limpa, versão 2.1.9 e estágio experimental.
- ASAR: 188 fontes conferidas contra a árvore interna; QR SVG/PNG, ZIP, Three.js e WebSocket executados em cópia isolada sem acesso aos node_modules de desenvolvimento.
- Serviço e host empacotados abriram sessão autoral com save sintético confirmado em pasta temporária. Nenhum dado pessoal foi tocado; gameplayCertified=false.
- Entrada principal chegou a app-ready em perfil temporário, com página do jogo e Steam preservadas, 32 módulos registrados e runtime autoral exclusivo.
- Wrapper de boot registrou o aviso BigInt já observado anteriormente. O teste separado com identidade de executável regular passou em primeiro acesso, reabertura sem repetição, novo download no mesmo caminho, BRUMWORLD e preservação do perfil. Não representa instalação pessoal validada.
- ASAR e host extraídos diretamente do portátil têm SHA-256 idêntico aos outputs empacotados verificados. A extração reconheceu os dados extras normais do executável autoextraível e terminou com exit 0.
- Portátil: **394348219 bytes**, ProductVersion 2.1.9; SHA-256 `cfbc9d848251e5e5285fbf05951f3ca3f8d19524821b796d76325f89a1c88cf5`.
- ASAR: SHA-256 `c9b3da44d63ca0ad420641d94c1f972246460bf02f0db27c271cbcf33d677859`.
- Host: SHA-256 `105df5cd39624c176843f4c96a4b0c31338a5293f430999101c0233c7c20de58`.

## Publicação e download real pelo atualizador

Release `v2.1.9` publicada como Latest oficial, não rascunho e não prerelease, no commit público `726a401a7304b6858676765b5072c9437aecde40`. O estágio experimental permanece explícito no Launcher e nas notas. Os três assets (executável, notas e SHA256SUMS) tiveram tamanho e digest confirmados pela API do GitHub antes da publicação.

O serviço real de atualização, simulando uma instalação 2.1.8 em perfil temporário, encontrou a 2.1.9 e baixou integralmente **394348219 bytes**, chegando a **ready /100%** com SHA-256 `cfbc9d848251e5e5285fbf05951f3ca3f8d19524821b796d76325f89a1c88cf5`. A seleção da ponte 2.1.0-beta.3 também encontrou a versão nova.

O arquivo de controle do perfil temporário permaneceu intacto. Não foi executada instalação nem reinicialização sobre o Launcher pessoal. A aplicação real da atualização continua dependendo da confirmação do usuário no aplicativo.

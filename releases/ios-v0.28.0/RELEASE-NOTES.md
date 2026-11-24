# BRUMCLASSICS MÓVEL iOS 0.28.0 — PSP iOS, Pesquisa/Filtros no Gaming Mode e MYbrumCONTROL

- **PSP no iOS (`PPSSPP`):** corrige mapeamento de memória mascarada (`MASKED_PSP_MEMORY`), alinhamento de página de 16 KB no Darwin (`arm64`), tamanho inicial da superfície OpenGL ES (`1024`), detecção de arquivos `.cso`/extensões multi-console e inicialização assíncrona de identidade em imagens de disco.
- **Pesquisa e Filtro por Console no Gaming Mode:** barra de pesquisa instantânea (ignorando maiúsculas/acentos) com botão de limpar, chips dinâmicos com **Todos os consoles** e categoria explícita **Não identificado**, preservando variantes (`GB`/`GBC`/`GBA`, `DS`/`3DS`, `PS1`/`PS2`/`PSP`) e ocultando títulos exclusivos de PC/Steam.
- **MYbrumCONTROL (Rede Local Only):** nova aba dedicada no Gaming Mode para conectar o iPhone como controle virtual a **outro PC** rodando Brum Classics via QR Code (`murb://`), código `MBC-...` ou entrada manual na LAN, isolado do PC principal, saves, biblioteca e credenciais.
- **Cache de identidade de ROMs:** cache `(size, mtimeMs)` para inicialização mais rápida de jogos repetidos sem alterar saves ou configurações existentes.

SideStore e atualização pelo fluxo existente preservados. Atualize mantendo os dados; não é necessário desinstalar.

# Licenciamento do aplicativo móvel e BRUM Core

Copyright (c) 2026 BRUMCLASSICS.

O código-fonte próprio contido em `android/` e `ios/`, incluindo o host Libretro BRUM Core, é software livre sob a **GNU General Public License, versão 3 ou, a seu critério, qualquer versão posterior (GPL-3.0-or-later)**. O texto integral está em `LICENSES/GPL-3.0.txt` e é empacotado nos builds móveis distribuídos pelo projeto.

## Limites do escopo

- O launcher de PC e seu código em `src/` continuam proprietários sob a licença da raiz (`LICENSE`). Nenhuma parte dessa licença móvel relicencia o launcher de PC.
- Nome, logotipos, ícones, ilustrações, capturas, materiais de loja e demais elementos de marca BRUMCLASSICS não são licenciados pela GPL. Builds modificados devem substituir esses elementos, salvo autorização separada.
- Núcleos e bibliotecas de terceiros mantêm suas próprias licenças. Os avisos, fontes exatas e revisões fixadas estão em `THIRD-PARTY-NOTICES.md` e `docs/CORES-INTEGRADOS.md`.
- ROMs, BIOS, chaves, firmware e conteúdo comercial não fazem parte do código-fonte nem dos builds. Quando um núcleo exige firmware, somente arquivos fornecidos pelo usuário podem ser usados.

## Código-fonte correspondente

Cada build público deve apontar para a revisão exata deste repositório e conservar os scripts de obtenção e build dos núcleos. O pacote distribuído deve conter a GPL, as licenças completas dos núcleos e os avisos de terceiros. Núcleos com cláusula de uso não comercial não são aceitos no BRUM Core.

Modificações locais em componentes sob MPL-2.0 continuam disponíveis nos respectivos arquivos, conforme a MPL. Ao combinar núcleos GPL-2.0-or-later com o aplicativo móvel, a distribuição resultante usa GPLv3 ou posterior; componentes GPL-2.0-only não serão combinados com componentes GPLv3-only.

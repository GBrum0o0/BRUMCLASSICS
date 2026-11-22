# BRUMCLASSICS OFICIAL 2.1.34

Corrige a ausência de núcleos em computadores novos ou instalações sem RetroArch externo: o pacote oficial passa a incluir `resources/brum-runtime` com **26 núcleos Libretro x64**, **Cemu 2.6**, assets livres de apoio para **PPSSPP** e **Dolphin**, utilitário **7-Zip Extra (`7za.exe`)**, redistribuíveis **Visual C++ (VC143 x64)** e os respectivos avisos de licença, cobrindo os **33 sistemas clássicos** exibidos pelo gerenciador.

## O que mudou

- **Descoberta autocontida de núcleos (`src/brum-core-pc-service.js` e `native/brum-core-pc/main.cpp`):** o gerenciador e o host nativo localizam automaticamente `resources/brum-runtime/cores` e `resources/brum-runtime/cemu/Cemu.exe` em perfis limpos, removendo fallbacks presos a diretórios da máquina de desenvolvimento. Pastas configuradas explicitamente pelo usuário e instalações locais preexistentes mantêm prioridade.
- **Preparação segura de assets e continuidade de saves do Cemu:** assets de sistema (`PPSSPP` e `dolphin-emu/Sys`) são copiados com verificação SHA-256 para a pasta privada `brum-core-pc/system` sem sobrescrever BIOS ou configurações existentes do usuário. O Cemu empacotado é preparado na pasta privada estável `brum-core-pc/runtime/cemu` com controle de arquivos gerenciados (`.brum-managed-files.json`), backup por hash e substituição atômica, preservando `portable/settings.xml` e `portable/mlc01` entre atualizações.
- **Verificação estrita antes do empacotamento (`scripts/stage-brum-runtime.cjs`, `scripts/verify-brum-runtime.cjs`, `scripts/verify-runtime-before-pack.cjs`):** o build oficial valida manifesto, cobertura dos 33 sistemas, tamanhos, hashes SHA-256, cabeçalhos PE x64, tabelas de importação/exportação Libretro e licenças, recusando symlinks, arquivos não declarados e mídias/dados privados (`.sav`, `.srm`, ROMs, BIOS, chaves, `mlc01`, `portable`).
- **Licenciamento e fontes correspondentes do host (`native/BRUM-HOST-LICENSE.md`, `resources/brum-core-pc-source`, `SOURCE-REFERENCES.json`):** o código autoral necessário para compilar o host nativo (`native/brum-core-pc/` e `native/on-brum/`) acompanha o pacote sob **GPL-3.0-or-later** com permissão adicional explícita (seção 7) para combinação com os núcleos independentes Genesis Plus GX, PicoDrive, Snes9x, FBNeo e Opera. A interface Electron do Launcher permanece em processo separado sob sua licença própria, e a distribuição mantém caráter gratuito e não comercial.

## Limites e responsabilidades

- **Presença de núcleo não certifica jogabilidade universal:** encontrar o binário (`33/33` sistemas no gerenciador) comprova empacotamento, integridade e resolução de caminhos, mas não substitui validação individual de gameplay comercial em cada console.
- **Firmware e BIOS não incluídos:** nenhum arquivo de BIOS, firmware, chave criptográfica, NAND ou ROM acompanha o pacote. Sistemas que exigem firmware próprio continuam dependendo dos arquivos fornecidos pelo usuário em sua pasta privada `system`.
- **RetroAchievements e Wii U:** permanecem os limites documentados na `2.1.33` quanto ao avaliador nativo online e à janela separada Wii U GamePad/DRC.

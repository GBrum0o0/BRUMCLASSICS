# BRUMCLASSICS OFICIAL 2.1.22 (Windows)

Atualização incremental sobre a [2.1.21](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v2.1.21) focada em corrigir a descoberta automática de ROMs novas e permitir adicionar múltiplos diretórios de jogos diretamente nas configurações do Launcher. A execução de **CLASSICS** segue exclusivamente via **M.U.R.B ENGINE** experimental integrada (sem RetroArch/fallback; quem precisar dos emuladores anteriores deve manter a [2.1.5](https://github.com/GBrum0o0/BRUMCLASSICS/releases/tag/v2.1.5)).

> **Aviso de escopo:** o porte dos 30 grupos continua em andamento. Permanece o status de **Jogável Verificado** para **Atari 2600**, **NES**, **SNES** e **GBA**, com regressões preservadas de **GB/GBC**; os outros **26 grupos** seguem em diagnóstico ou experimentais.

## Novidades e correções desta entrega (`2.1.22`)

- **Múltiplos diretórios em Configurações → CLASSICS:** nova seção **Pastas de jogos** (em **Configurações → Mais configurações → CLASSICS**) permitindo visualizar todas as pastas monitoradas (`PASTA PRINCIPAL`, `ADICIONADA` e `LOCAL DETECTADA`), **Adicionar diretório** de qualquer local do Windows, **Alterar pasta principal**, **Remover** diretórios adicionados sem apagar ROMs nem saves e acionar **Puxar jogos agora**.
- **Detecção automática da pasta local `games` / `RETROGAMES`:** se existir uma pasta `RETROGAMES` ou `games` ao lado do `BRUMCLASSICS OFICIAL.exe`, ela é varrida automaticamente mesmo que uma instalação antiga tenha salvo outra pasta principal nas configurações.
- **Correção da varredura automática na abertura:** corrigido o fallback do cache rápido (`quick-state`) quando a checagem inicial passa de `350 ms`, garantindo que o scanner `retro` continue executando em segundo plano e registre ROMs recém-copiadas.
- **Identificação ampliada de mídias/discos:** adicionada leitura das assinaturas binárias de **Wii** e **GameCube** em arquivos `.iso` (inclusive `.nkit.iso`) e suporte de catálogo para `.gdi`, `.cdi`, `.rvz`, `.gcz`, `.gcm`, `.wbfs`, `.3dsx` e `.neo` (mantendo a exigência de formato suportado ao abrir pela M.U.R.B ENGINE).

## Base M.U.R.B ENGINE herdada e revalidada da `2.1.21`

- **JOGÁVEL VERIFICADO (`10 min` / `36.000` quadros na `2.1.21`):** Atari 2600 (*Pac-Man*), NES (*Excitebike*, *SMB3*), SNES (*A Link to the Past*, *Super Mario World* com SRAM `64 KiB`) e GBA (*Super Mario Advance 4* com Flash128 `128 KiB`).
- **Regressão preservada:** GB/GBC e Cofre de Saves (`56/56`) intactos.
- **Pendentes / Experimentais:** DS (correções nativas de timers/WRAM/RTC/áudio preservadas, porém títulos comerciais testados seguem com tela branca), 3DS (sem suporte a `.code` comprimido), SMS/GG/PCE (apenas diagnóstico sintético, sem mídia comercial local), Genesis/N64/Xbox e demais 18 sistemas do porte permanecem experimentais.

## Arquivo desta release

- **Arquivo:** `BRUMCLASSICS-OFICIAL.exe`
- **Canal:** `Official`
- **Tamanho:** `410.589.290` bytes
- **SHA-256:** `FCBC4AD2A8062D7F31CE582EB27B45E99E5FE176D6DACC115CAD810AF5425FF8`

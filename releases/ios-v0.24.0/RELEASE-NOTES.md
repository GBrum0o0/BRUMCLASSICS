# BRUMCLASSICS MÓVEL iOS 0.24.0 — Correção de Crash no PSP e RetroAchievements Real (`rcheevos`)

- **PSP (`.iso`):** corrige falhas reais de abertura no iPhone com inspeção e hashing em streaming POSIX (`open`/`read` de 1 MB) sem OOM/Jetsam, guardas pré-1º frame para `serialize*`, inicialização de resolução ao relançar no mesmo processo, proteção estrita contra `PROT_EXEC` sem JIT, pilha de 2 MB na `EmuThread` e sondagem ASLR ampliada.
- **RetroAchievements Real (`rcheevos` v12.5.0, MIT):** integra o avaliador oficial em modo **Softcore**, autenticação por token protegida no Keychain (sem salvar senha), leitura de memória quadro a quadro e exibição exclusiva após confirmação oficial HTTP `200` `"Success": true` em `r=awardachievement`.
- **Popup BRUM CLASSICS:** aplica o molde horizontal oficial (`#090d0e`, borda `#35413f`, barra lateral `#9dff3b`, ícone vetorial de cartucho e pílula `+N PTS`) na sessão integrada e no Gamepad remoto, com deduplicação por `eventId`.
- **Nintendo 3DS (`Azahar`):** preservado no build experimental por software sem JIT e explicitamente marcado como sem suporte RetroAchievements (`console_id = 0`) até suporte oficial certificado.

**Validação:** contratos compartilhados C++ (`tests.cpp` e `ra_tests.cpp`), validação de pacote/licenças (`validate_ipa.py` + `rcheevos-LICENSE.txt`) e estrutura do projeto iOS passam localmente e no workflow; gameplay físico de 5+ min em iPhone real e desbloqueio oficial em conta de usuário aguardam validação em aparelho.

# BRUMCLASSICS MÓVEL Android 0.33.0 — Correções do Gaming Mode e PSP

- Corrige a detecção automática de jogos PSP em `.iso` e `.pbp` (inclusive `PSP GAME` no PVD ISO-9660, cabeçalhos `~PSP`/ELF e pastas raiz `PSP`/`PlayStation Portable`/`Sony PSP`) durante a varredura e verificação do Gaming Mode.
- Verifica a acessibilidade real dos arquivos locais no aparelho antes de exibir `Disponível`, evitando falsos positivos para entradas apenas catalogadas ou inacessíveis.
- Remove nomes técnicos de núcleos e emuladores da interface do Gaming Mode, exibindo apenas `Disponível` (verde) e `No computador` (cinza).
- Filtra o Gaming Mode para mostrar somente jogos Classics, ocultando títulos comuns de PC, Steam, Windows e executáveis sem excluir nada da biblioteca original.

**Validação:** compilação, testes de contrato e verificação do APK são executados no build antes da assinatura de upgrade. Teste físico em aparelho Android com gameplay de PSP, áudio, controles e save local ainda exige validação em dispositivo real.

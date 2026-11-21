# BRUMCLASSICS MÓVEL iOS 0.23.0 — Correções do Gaming Mode e PSP

- Corrige a detecção de jogos PSP em `.iso` e `.pbp` (inclusive fora de subpasta `PSP` ou em pasta raiz `PSP`/`PlayStation Portable`) para não aparecerem como indisponíveis quando presentes e acessíveis no iPhone.
- Remove nomes técnicos de núcleos e emuladores da interface do Gaming Mode.
- Exibe indicadores diretos abaixo dos jogos: `Disponível` (verde) para arquivos acessíveis no aparelho e `No computador` (cinza) para jogos Classics sincronizados do PC.
- Filtra o Gaming Mode para exibir exclusivamente jogos Classics, ocultando títulos de PC, Steam, Windows e executáveis sem alterar a biblioteca original.

**Validação:** compilação, testes automatizados no simulador e verificação do IPA são executados no build. Teste físico em iPhone com jogos PSP, áudio, controles e saves locais em `PSP/SAVEDATA` ainda exige validação no aparelho; desempenho de PSP permanece limitado pelo modo interpretador sem JIT.

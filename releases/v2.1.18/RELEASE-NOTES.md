# BRUMCLASSICS OFICIAL 2.1.18 — revisão da M.U.R.B ENGINE

Atualização oficial do Launcher Windows, disponível pelo verificador de atualizações do aplicativo. A execução autoral permanece experimental.

## Melhorias integradas

- **Master System e Game Gear:** expansão de instruções Z80, operações aritméticas de 16 bits, pilha dos registradores de índice e ajustes do timing do VDP e da interrupção horizontal.
- **PC Engine:** instruções adicionais HuC6280, acesso direto às portas de vídeo ST0/ST1/ST2 e gravação de palavras na VRAM pelo VDC ao receber o byte alto.
- Seis testes de regressão foram acrescentados aos testes nativos existentes. O host de execução, o sistema de saves e as proteções publicadas de GB/GBA/NES foram preservados.

## Resultado da revisão do trabalho do Antigravity

Os snapshots 8ed9b04 e 637e20a foram examinados antes da integração. A importação foi limitada às melhorias verificadas de SMS/Game Gear e PC Engine. **Os commits não foram incorporados integralmente.**

Ficaram fora desta versão: novo host com risco de gravação de save sem proteção de sessão; alterações que regrediam EEPROM/timers do GBA e SRAM/carregamento/PPU do NES; menus de Save State, troca de disco e remapeamento ainda incompletos; integração demonstrativa de conquistas; JIT, GPU e coprocessadores sem uso funcional comprovado no runtime; geração artificial de imagem ou áudio para aparentar inicialização de outros sistemas.

O resultado de 347 testes do snapshot original foi reproduzido, mas não comprova uso pleno de 32 consoles. O diagnóstico daquele snapshot usa indicadores insuficientes de prontidão. [Detalhes da revisão](REVIEW.md).

## Preservação e limites

Saves, Save Vault, biblioteca, perfis, anotações, atualizações e Brum iOS Bridge permanecem no fluxo existente. O pacote não contém ROMs, BIOS, saves, credenciais ou ferramentas pessoais de agentes.

Esta release não certifica partidas completas, fidelidade audiovisual de jogos comerciais ou suporte concluído dos 32 sistemas. Os demais núcleos continuam com as limitações anteriores. O Brum iOS Bridge mantém os [limites de detecção, assinatura e instalação](../v2.1.17/RELEASE-NOTES.md) já documentados. Não há nova build de IPA ou APK nesta publicação.

[Relatório de validação](VALIDACAO.md).

# BRUMCLASSICS OFICIAL 2.1.11 — correções GBA experimentais

Atualização para testar os ajustes de Pokémon Emerald e FireRed na M.U.R.B ENGINE. Canal oficial do Launcher, com estágio experimental explícito.

## Alterações

- Memória Flash de 128 KiB: identificação do chip, bancos, programação, apagamento e persistência própria. Isso permite ao Emerald sair da tela branca e executar a introdução, sem modificar a ROM.
- CPU ARM: instrução MSR por registrador e preservação dos registradores no tratamento de interrupções.
- Vídeo GBA: prioridades entre fundos e sprites, transformações afins, área duplicada de sprites e forced blank.
- Áudio GBA: clock e roteamento estéreo dos canais square existentes, amostragem racional de 48 kHz, resets e último byte de FIFO B.
- Sincronização entre timers, consumo dos FIFOs e áudio; encadeamento de timers.

## Limites importantes

**Não é GBA 100% concluído.** Permanecem defeitos visuais, janelas/blending/fades incompletos e limitações sonoras, incluindo wave/noise, envelopes e detalhes do mixer. Introdução, PCM e testes aprovados não certificam gameplay completo, fidelidade ou sessão de jogo com salvamento/reabertura. Os demais sistemas continuam com as limitações documentadas nas versões anteriores.

## Atenção aos saves experimentais antigos

Flash128 usa um novo container `gba-flash128-v1`, de 131.072 bytes. SRAM continua usando `gba-sram-v1`, de 65.536 bytes. **Não há conversão automática entre eles.** Se um Pokémon já tiver gerado um snapshot experimental SRAM antigo, o core poderá recusar a restauração por incompatibilidade. O arquivo é preservado, não truncado nem substituído. Guarde uma cópia desse snapshot antes de iniciar um teste com armazenamento novo; esta versão não oferece migração automática.

ROMs, saves originais, Save Vault, biblioteca e perfis não são apagados. Saves experimentais seguem separados por perfil/sistema/SHA256 em `brum-core-pc/murb-test-saves`; não se aplicam automaticamente ao Vault.

Somente Launcher Windows PC. Sem ROMs, BIOS, credenciais, ferramentas REA ou emulador externo incluídos. Não certifica os 32 consoles nem representa auditoria independente final concluída.

## Atualizar

No Launcher: **Configurações → Sistema → Atualizações → Verificar atualizações**. Baixe e confirme a instalação pelo fluxo existente. Também disponível o executável portátil nesta release.

Veja os testes e limites em [VALIDACAO.md](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.11/VALIDACAO.md).

# BRUMCLASSICS OFICIAL 2.1.10 — áudio e vídeo experimentais

Atualização de teste da M.U.R.B ENGINE sobre o Launcher 2.1.9. Integra alterações GBC/GBA de `078903f` e a revisão gráfica GB recebida até `7241a8f`, com correções adicionais de segurança e regressão feitas na integração.

## Alterações

- GBC: clock do sequenciador de áudio, divisor em double-speed e limpeza de fase no reset.
- GBA: transferências FIFO/DMA de áudio, leitura/escrita dos registradores, sprites e modos bitmap 4/5. Não é renderização ou áudio completos do hardware.
- GB: tratamento da coluna inicial com janela desligada. A alteração original removia todos os comparadores e quebrou um teste existente; foi restringida ao início da linha para preservar os demais casos.
- Revisão corrigiu FIFOs sem limite de memória, canais tocando com roteamento desabilitado, master-off ignorado, soma de áudio com overflow e DMA ligado ao FIFO errado ou consumindo amostra ao habilitar.
- Preservadas as correções de limites de RAM, reentrada DMA, divisão, IRQ e contrato de save GBA de 64 KiB da 2.1.9.

## Limites importantes

**Continua experimental. Não representa os 32 consoles prontos, nem Game Boy/GBC/GBA “100%”.** Contagem de cores, PCM ou alguns frames de inicialização não comprovam gameplay, fidelidade, controles ou persistência do jogo inteiro. Os resultados e testes efetivamente executados estão em [VALIDACAO.md](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.10/VALIDACAO.md).

Os novos relatórios/matriz/harness do Antigravity não foram adotados como certificação: marcam input/save/timing sem testes suficientes e usam caminhos pessoais fixos. Não são distribuídos com o Launcher.

Permanecem limitações de sprites/afinidade/prioridades e áudio GBA, EEPROM/Flash incompletos, reset GBA após Halt, defeitos conhecidos do NES, ausência de áudio SNES e possíveis telas pretas em SNES/N64/DS e outros cores. A revisão independente retornou problemas concretos, mas foi interrompida antes do parecer final; não é anunciada como auditoria independente concluída.

Pendência pontual de áudio: escrita byte a byte no último endereço do FIFO B (`0x040000A7`) ainda não é encaminhada pelo barramento; transferências DMA de 32 bits seguem o caminho validado. No teste de Pokémon Red de 600 frames, a contagem de pixels brancos na primeira coluna ficou igual antes/depois; a regressão sintética comprova o caso corrigido, não a eliminação de toda faixa branca em qualquer jogo.

## Preservação e atualização

- ROMs, saves originais, Save Vault, biblioteca e perfis não são apagados ou migrados automaticamente.
- Saves autorais de teste continuam separados por perfil, sistema e SHA256 em `brum-core-pc/murb-test-saves`. Integridade do container não garante correção do protocolo de save do core.
- Sem aplicação automática do Vault, save states, desbloqueios online ou emulador externo no runtime autoral. O watchdog pode interromper um core bloqueado e perder progresso não confirmado, sem alterar os originais.
- Página do jogo, intro, Steam e Save Sync manual preservados. Somente PC Windows; sem ROMs, BIOS ou ferramentas internas.
- Canal oficial Latest mantido para compatibilidade com o atualizador, com estágio experimental explícito.

No Launcher: **Configurações → Sistema → Atualizações → Verificar atualizações**. A instalação só ocorre quando você confirmar.

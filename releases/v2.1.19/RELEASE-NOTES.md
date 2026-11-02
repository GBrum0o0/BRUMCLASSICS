# BRUMCLASSICS OFICIAL 2.1.19

Atualização oficial do Launcher PC com integração seletiva das alterações mais recentes do Antigravity. A M.U.R.B ENGINE continua experimental.

## Alterações incluídas

- PSP: instruções EXT e INS do processador Allegrex, com testes de todas as 1.056 combinações válidas de posição e tamanho do campo e de uso do mesmo registrador como origem e destino.
- Neo Geo Pocket: leitura do registro de controle passa a ter prioridade sobre a memória que ocupa o mesmo endereço. Os 256 estados foram conferidos em uma prova isolada.
- Catálogo de perfis de controle para os 32 sistemas registrados, mantendo os perfis personalizados e sem aprovar sistemas automaticamente. Esse catálogo não comprova que todos os controles chegam aos respectivos runtimes.
- Descoberta de cartuchos adicionais e identificação para RetroAchievements por hash em Master System, Game Gear, SG-1000, PC Engine, Atari 2600/7800/Lynx, Neo Geo Pocket, WonderSwan, MSX, 32X e Jaguar. Identificadores oficiais e regras dos cabeçalhos foram conferidos; arquivos compactados e imagens ópticas não recebem um MD5 genérico como substituto de seus leitores específicos.

## Preservação e limites

Host protegido, saves, Cofre, GB/GBC/GBA/NES, Launcher e Brum iOS Bridge preservados. Nenhuma migração automática de save. Somente o pacote Windows foi atualizado.

As novas alterações de host, rede, conquistas durante a partida e outros núcleos ainda apresentam falhas e ficaram fora da distribuição. A revisão e os motivos estão em [REVIEW.md](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.19/REVIEW.md); os testes e seus limites estão em [VALIDACAO.md](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.19/VALIDACAO.md).

Esta versão não certifica partidas completas, fidelidade audiovisual ou suporte concluído dos 32 sistemas. Identificar uma ROM para consultar conquistas não implementa desbloqueios online no runtime autoral. Assinatura e instalação do iOS Bridge continuam dependendo da validação no aparelho.

## Atualizar

No Launcher, abra Configurações e use Verificar atualizações. O download oficial é `BRUMCLASSICS-OFICIAL.exe`; a integridade acompanha `SHA256SUMS.txt`.

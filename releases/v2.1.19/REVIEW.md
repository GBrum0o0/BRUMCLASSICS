# Revisão das alterações do Antigravity — 2.1.19

Base oficial: 2.1.18. A revisão inicial do snapshot 2d9c0d8 foi ampliada para o commit d7c2f0a e os arquivos locais capturados em 2 de novembro de 2026. Foram preservados o checkout original, suas alterações em andamento e as demais worktrees. Os revisores trabalharam sobre uma cópia imutável de 149 arquivos, com hashes conferidos.

## Decisões

Somente duas pequenas alterações de execução nativa foram integradas: EXT/INS do PSP e prioridade do registro de entrada do Neo Geo Pocket. O restante do host, armazenamento e núcleos publicados permanece na base anterior. Também foram integrados o catálogo de perfis e o subconjunto de identificação de cartuchos conferido com as referências oficiais.

O novo host não foi aprovado: há caminhos de erro que permitem continuar sem o armazenamento protegido, escritas diretas sem as garantias atuais, remoção de watchdog/validações de áudio e identidade de conteúdo incompleta para discos grandes. A nova ponte de controle remoto apresenta problemas de autenticação e encerramento. Essas mudanças não estão no executável distribuído.

Provas sintéticas independentes também reproduziram problemas de reset/ROM/flash no 3DS, instruções de ponto flutuante do GameCube e travamento de DMA cíclico no PS1. Os novos áudios de SNES/Genesis usam tons sintéticos que não demonstram emulação correta. A mudança de FIFO/DMA do GBA altera a semântica de interrupção e não foi incorporada.

O cliente de conquistas ainda escolhe regras demonstrativas por console e pode emitir um desbloqueio com memória zerada, sem identificar e avaliar definições reais do jogo. Não foi incluído.

## Diagnósticos e prontidão

A matriz atual já diferencia estados parciais: contém 14 PLAYABLE, um VALIDATED e 17 VIDEO_PARTIAL; 17 entradas usam programas sintéticos. Esses rótulos continuam sem constituir certificação de jogos comerciais. Testes de CPU, imagem estática ou presença de amostras de áudio não comprovam movimentação, combate, salvar/Continue e fidelidade sonora.

A suíte candidata foi compilada fora do projeto, e o caso diagnóstico que procura uma ROM local foi removido somente dessa cópia externa. Passar nessa suíte sintética não elimina os defeitos encontrados. O harness original não foi executado sobre o projeto ou dados do usuário.

## Identificação de cartuchos

Os IDs foram comparados com a [enumeração oficial do RetroAchievements](https://github.com/RetroAchievements/rcheevos/blob/master/include/rc_consoles.h). Cabeçalhos de PC Engine, Atari 7800 e Lynx seguem as regras verificadas em [hash_rom.c](https://github.com/RetroAchievements/rcheevos/blob/master/src/rhash/hash_rom.c); cartuchos raw adicionais seguem o [despacho de hashes oficial](https://github.com/RetroAchievements/rcheevos/blob/master/src/rhash/hash.c).

Não foi importada a regra genérica de MD5 para discos/arquivos compactados nem a escolha automática do primeiro arquivo de uma pasta/CUE. IDs incorretos do snapshot foram excluídos/corrigidos no subconjunto integrado. Os formatos adicionais são limitados explicitamente e não habilitam compatibilidade de emulação ou desbloqueios online.

Ferramentas pessoais, definições de agentes, relatórios internos, mídias, ROMs, BIOS, saves e credenciais não fazem parte desta publicação.

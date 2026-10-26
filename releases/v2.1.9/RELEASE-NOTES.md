# BRUMCLASSICS OFICIAL 2.1.9 — GBA e GBC experimentais

Build de testes com alterações autorais da família Game Boy do snapshot `8b9dda1ac8ac394508517ead6c5108ff47331b67`, integrada sobre o Launcher 2.1.8. Mantida a autorização para testar a engine incompleta e continuar corrigindo depois.

## Alterações integradas

- GBA: expansão de ARM/Thumb, barrel shifter, modos/registradores de IRQ, transferências de memória, serviços HLE de inicialização e outras partes do core.
- GBC: alterações de DMA/HDMA e barramento/VRAM.
- Descoberta de compilador: seleção de instalação existente quando o registro mais recente aponta para um caminho inexistente; sem instalação de ferramentas ou alteração global.
- Preservados o host seguro, os controles, o contrato de vídeo, orçamento de memória e persistência isolada da versão anterior.
- Revisão corrigiu acessos largos fora da RAM, recursão de DMA e divisão assinada que encerravam o processo, além de limitar aninhamento patológico de IRQ. Cinco regressões reproduzidas antes e aprovadas depois da correção.
- Mantido o contrato de save GBA de 64 KiB (`gba-sram-v1`), evitando rejeitar as cópias de teste já produzidas. Não é implementação completa de Flash/EEPROM.

Não foi substituído o host integrado pelo main.cpp antigo da raiz. O host distribuído já limpa o backbuffer inteiro e utiliza BLACK_BRUSH; as alterações específicas de janela e CLI da raiz não fazem parte desta importação. Não foram importados cores externos, fallback libretro ou ferramentas internas.

## O que foi e o que não foi comprovado

O binário de desenvolvimento apresentou avanço na inicialização de FireRed: após 600 frames, deixou a tela branca e produziu imagem com 7 cores e PCM não zerado. Os resultados da integração e do pacote estão em VALIDACAO.md.

**Não é uma certificação de Game Boy/GBC/GBA “100%”, nem conclusão dos 32 sistemas.** Imagem ou áudio após 600 frames não comprovam gameplay completo, fidelidade de som, controles, saves do jogo inteiro ou compatibilidade com outros títulos. As alegações de conclusão total do relatório original não foram adotadas nesta publicação.

Os demais sistemas continuam experimentais: SNES/N64/DS podem permanecer pretos e sem áudio, e os defeitos de volume/habilitação do NES registrados na 2.1.8 continuam presentes. O SNES ainda não possui áudio funcional. Cores podem travar, desenhar incorretamente ou falhar na execução.

Pendências menores da revisão: reset da CPU GBA após Halt e fase residual do divisor de clock GBC ainda precisam de tratamento dedicado. Reiniciar o processo não é certificação de reset interno correto.

## Dados e recursos preservados

- Saves antigos, ROMs, perfis, biblioteca e Save Vault não são apagados.
- Sessões autorais continuam em `brum-core-pc/murb-test-saves/<perfil>/<sistema>/<SHA256>.onbrum`, sem migração ou ativação automática de saves antigos.
- Mantidas verificações de integridade, gravação durável e cópia anterior. Integridade do container não equivale à fidelidade da emulação/persistência implementada pelo core.
- Sem aplicação de saves do Vault ao runtime experimental, save states ou desbloqueios online durante a execução autoral.
- O watchdog pode encerrar um core bloqueado e perder progresso posterior ao último save confirmado, sem modificar os originais.
- Sem fallback externo, Arcade genérico ou leitores novos para arquivos compactados e descritores. Mantidas as restrições de formatos da 2.1.8.
- Página do jogo, intro, contas Steam e Save Sync manual são mantidos. Somente Windows; nenhuma alteração em Android/iOS.
- Não inclui ROMs ou BIOS.

Publicada no canal oficial para compatibilidade com o atualizador, com estágio experimental explícito. Use **Configurações → Sistema → Atualizações → Verificar atualizações** e confirme a instalação quando desejar. Quem depende dos emuladores externos anteriores deve manter a 2.1.5.

# BRUMCLASSICS OFICIAL 2.1.8 — M.U.R.B experimental para testes

## Leia antes de atualizar

Publicada para testes a pedido explícito do usuário, que aceita continuar corrigindo a engine posteriormente. **Esta versão não conclui o suporte dos 32 sistemas.**

Jogos podem continuar com tela preta, branca, gráficos incorretos, controles incompletos, áudio ausente ou falhas de execução. Não atualizar esperando compatibilidade equivalente à dos emuladores externos anteriores.

## Conteúdo

- Snapshot dos cores autorais `69c02e0126947ee6ea26392da1ca77ca4d5f7ff7`, integrado sobre o Launcher 2.1.7.
- NES: alterações parciais de MMC3, bancos, IRQ, CPU e APU. Há defeito conhecido de habilitação/volume: o core pode emitir som quando o jogo pede silêncio; áudio presente não significa áudio correto.
- GBA: alterações parciais de inicialização, ARM/Thumb, SWIs e áudio; removido o preenchimento com tom arbitrário.
- SNES: alterações parciais de CPU, registradores e renderização BG1; removido o preenchimento com tom arbitrário. **A APU ainda não emula áudio funcional e continua produzindo silêncio.**
- N64: alteração de inicialização e metadados de persistência.
- Ajustes de metadados/CRC e resposta de flush em outros módulos.

O host antigo da raiz do projeto não foi copiado sobre a integração publicada: mantidos o host seguro, o orçamento de memória, os controles, o contrato de vídeo e a proteção de captura da 2.1.7. Não foram importados roteamento libretro, cores externos ou fallback automático.

## Estado dos jogos

Na revisão do binário de desenvolvimento do snapshot, após 600 frames: Pokémon Red/GB produziu imagem e áudio; Mario Bros. 3/NES produziu imagem, sem certificação de gameplay; FireRed/GBA permaneceu branco e silencioso; Mario World/SNES, Mario 64/N64 e Mario 64 DS/DS permaneceram pretos e silenciosos. A validação do host integrado está registrada em VALIDACAO.md.

O registro de 32 módulos indica disponibilidade de protótipos, não 32 emuladores completos. Não há matriz comercial validada para declarar conclusão. Corrigir cores e aceitar arquivos maiores não equivale a executar corretamente o jogo.

## Seus dados e recursos

- ROMs, saves anteriores, perfis, biblioteca e Vault não são apagados.
- Sessões experimentais usam `brum-core-pc/murb-test-saves/<perfil>/<sistema>/<SHA256>.onbrum`.
- Sem importação, migração ou ativação automática de saves antigos; sem aplicação de saves do Vault a esse runtime.
- Mantidas verificações de integridade, gravação durável, backup anterior e exclusão do namespace de testes do scan do Vault.
- Saves de teste ainda dependem de implementações incompletas dos cores: não confundir integridade do container com fidelidade do hardware/save emulado.
- O watchdog pode encerrar um core bloqueado; progresso posterior ao último save confirmado pode ser perdido, sem alterar os originais.
- Save states e desbloqueios online durante a execução autoral continuam indisponíveis.
- Sem leitores integrados para ZIP/7z/RAR, CHD/RVZ/GCZ/CSO e descritores CUE/GDI/M3U; Arcade genérico permanece indisponível.
- Mantidas página do jogo, intro, Save Sync manual e contas Steam. Somente Windows; Android/iOS não foram alterados.

O pacote não inclui ROMs, BIOS ou ferramentas internas de análise. Quem precisar dos emuladores externos anteriores deve manter a 2.1.5.

## Atualização

Publicação no canal oficial para continuar compatível com o botão do Launcher; **experimental é o estágio da engine, não uma certificação de prontidão**.

Use Configurações → Sistema → Atualizações → Verificar atualizações e confirme a instalação quando desejar. O teste de entrega não instala nem reinicia o Launcher pessoal.

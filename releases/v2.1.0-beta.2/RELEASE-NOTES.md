# BRUMCLASSICS PC 2.1.0-beta.2 — Save Vault manual

Esta é uma **Beta para Windows x64**, publicada no mesmo repositório e no fluxo normal de releases do BRUMCLASSICS. Não substitui a release Latest Stable.

## Novidades desta etapa

- **Configurações → Save Sync → Save Vault / Cofre de Saves**, com jogos apresentados por capas.
- Descoberta manual de saves nas pastas conhecidas do PC e seleção de outra unidade, partição, cartão ou pasta, com nome livre para a origem.
- Scan somente de leitura, prévia visual, associação ao jogo (manual quando ambígua) e confirmação dos arquivos selecionados antes da cópia.
- Origem, data e integridade SHA-256 de cada revisão; últimos registros de PC e Celular representados por jogo.
- Versões diferentes preservadas. Importação não ativa; **Definir como save ativo** é uma ação separada, exclusivamente manual, que não sobrescreve o emulador nem o armazenamento original.
- Exclusão somente da cópia do Cofre, com confirmação nativa e cancelar como padrão. Excluir um save ativo não seleciona um substituto. Recuperação local da cópia removida disponível no diretório de dados do Cofre.
- Backups/restauração existentes mantidos, usando o mesmo armazenamento de Cofre. A restauração antiga não pode sobrescrever a origem de uma nova importação manual.
- Host **BRUM Core PC** incluído no executável do Launcher, com inicialização, comunicação e saves por perfil/ROM. A rota nativa depende de um núcleo libretro compatível instalado; não inclui ROMs, BIOS nem DLLs de emulação. O RetroArch permanece funcional.
- O atualizador existente reconhece tags Beta numericamente, oferece download, verifica tamanho/SHA-256 e usa o procedimento de atualização/backup/recuperação já existente. Atualiza somente o próprio executável Beta; perfil e Stable preservados.

## Instalação e próximos updates

Baixe `BRUMCLASSICS-BETA.exe` nos assets desta release e abra no Windows x64. A primeira atualização a partir da Beta anterior precisa ser manual, pois aquele binário ignorava prereleases. A partir desta versão, as próximas Betas podem ser consultadas e instaladas por **Configurações → Sistema → Atualizações**.

O perfil Beta permanece separado do Stable. Configure as pastas de seus jogos e o RetroArch existente em CLASSICS, conforme necessário. Nenhum jogo ou dado pessoal é distribuído. As capas de validação não substituem as capas da biblioteca real.

## Escopo e limites

Save Sync permanece manual. Não foi criado transporte automático PC/celular, LAN automática, Gamepad, segunda tela, streaming, conta online, ranking, conquistas online ou servidor externo nesta etapa.

O scanner tem limites de segurança e avisa quando o resultado é parcial; nesse caso selecione uma subpasta menor. Saves desconhecidos exigem associação manual. Importar não converte formatos nem certifica compatibilidade entre consoles, regiões ou emuladores.

Base nativa PC: GB/GBC/GBA com mGBA, NES com Nestopia e SNES com Snes9x, mediante núcleo instalado. O teste real desta etapa usou mGBA com ROM sintética própria; não representa certificação de todos os jogos/sistemas. Outros recursos existentes continuam no RetroArch.

Veja também o guia `SAVE-VAULT-BETA.md` anexado e [a validação desta release](VALIDACAO.md).

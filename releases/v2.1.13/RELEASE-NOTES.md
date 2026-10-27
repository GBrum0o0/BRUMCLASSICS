# BRUMCLASSICS OFICIAL 2.1.13 — correções experimentais de GBA

Atualização do Launcher PC com correções na M.U.R.B ENGINE para os problemas de
imagem e áudio relatados em Pokémon Emerald e FireRed.

## Correções

- Janelas, transparências, brilho e composição das camadas gráficas.
- Interrupções LCD e transferências DMA por linha, com repetição e endereços
  internos separados dos registradores que o jogo pode reescrever.
- Escala/rotação de fundos e sprites: rotinas autorais BgAffineSet/ObjAffineSet,
  origem afim por linha, recarga durante HBlank e transformação dos modos bitmap.
- Quatro canais PSG, incluindo wave e ruído, duração, envelope, sweep,
  roteamento, proporção PSG/FIFO e controle de bias.
- Clock de ruído e cadência do host coerente com o período real do GBA,
  sem impor 60 Hz fixos.

No teste integrado, o logo completo de Pokémon voltou no título do Emerald,
que avançou até o menu New Game/Option. FireRed avançou até as instruções.
As ROMs do usuário permaneceram idênticas. O dispositivo de áudio do Windows
foi aberto e recebeu PCM em uma execução separada com janela oculta.

## Limites importantes

**O GBA continua experimental.** Não houve certificação de partida completa,
batalha, fidelidade sonora humana ou salvar/reabrir o progresso dentro desses
dois jogos. Há aproximações e limitações visuais remanescentes, incluindo
mosaic, precisão de timing/raster, arredondamentos HLE e PWM/filtragem de áudio.
Não é anúncio de 32 consoles concluídos.

A recuperação segura de snapshots GBA da 2.1.12 permanece: original preservado,
backup verificado e novo Flash128 separado somente mediante confirmação.
Não há conversão automática de progresso nem alteração dos saves originais,
Save Vault, perfis ou biblioteca. A implementação usa código autoral, sem BIOS
Nintendo, ROMs ou ferramentas internas no pacote. Não reintroduz RetroArch.

Somente Windows PC x64. Atualize no Launcher em **Configurações → Sistema →
Atualizações → Verificar atualizações**. O download utiliza o GitHub e a
instalação continua dependendo da sua confirmação.

[Testes, evidências e limites](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.13/VALIDACAO.md).

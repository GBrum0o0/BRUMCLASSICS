# BRUMCLASSICS OFICIAL 2.1.14 — atualização experimental de GBA e NES

Atualização do Launcher PC com alterações na M.U.R.B ENGINE para GBA e NES.

- GBA: ajustes no processamento de EEPROM e DMA, com formato de save separado de SRAM e rejeição de comandos incompletos.
- NES: ajustes em cartucho, PPU e mapeadores; ROMs CHR truncadas, NES 2.0 e mapeadores não implementados são recusados.
- Mantida a proteção do host para saves incompatíveis e arquivos originais.

## Limitações

O suporte permanece experimental. A EEPROM usa armazenamento interno de 8 KiB; importação de arquivos EEPROM de 512 bytes não foi implementada. Snapshots antigos ambíguos identificados como SRAM são recusados e preservados, sem conversão automática; jogos que dependam deles poderão não abrir até que uma recuperação segura seja implementada.

Os testes não certificam partidas completas, fidelidade de imagem ou áudio, nem compatibilidade de todos os jogos e mapeadores. As ROMs e os saves do usuário não são incluídos no pacote.

## Verificação

Foram aprovados 349 testes nativos e 846 testes do Launcher, com um teste opcional ignorado. Pokémon Emerald e Super Mario Bros. 3 executaram 240 quadros sem janela, usando saves temporários isolados, e as ROMs permaneceram inalteradas. Esse teste limitado não comprova jogabilidade nem qualidade audiovisual.

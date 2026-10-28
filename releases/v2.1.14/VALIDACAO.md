# Validação da versão 2.1.14

- Compilação nativa e host Windows: executadas com MSVC.
- Suíte nativa: 349 testes aprovados; resultado ainda indica gameplayReady=false.
- Suíte do launcher: 846 aprovados, zero falhas e um teste opcional ignorado.
- Testes do host com arquivos sintéticos: proteção contra save corrompido, conteúdo ou formato divergente e destino externo.
- Teste limitado em modo sem janela: Pokémon Emerald e Super Mario Bros. 3 executaram 240 quadros em sessões separadas com saves temporários e ROMs verificadas antes e depois.
- Não foram validadas partidas completas, imagem ou áudio por observação humana. EEPROM de 512 bytes e snapshots antigos ambíguos continuam com limitações descritas nas notas.

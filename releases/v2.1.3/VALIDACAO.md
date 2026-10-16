# Validação PC 2.1.3 — 2026-10-16

- Fonte privada local PC: commit `b293d1db0556bd6f0f98625a4f3d64765aa7eb83`; nenhum código privado do Launcher foi enviado ao repositório móvel/público.
- Executável `BRUMCLASSICS-OFICIAL.exe`: 393.460.389 bytes, SHA-256 `91aa371519028c2d9813702afa63e1df984b5d50d245ed903ebc1967e2cfca5b`.
- ASAR: 181 arquivos de fonte conferidos byte a byte. Host empacotado idêntico ao compilado, hostAPI 2/saveRestoreAPI 1, `onBrumDevelopmentEnabled:false` e `onBrumProductionReady:false`; tentativa experimental recusada com exit 2, sem READY ou save criado. Worker de monitoramento executado a partir do ASAR em perfil temporário.
- Binário de distribuição: 14 testes de host/armazenamento/serviço aprovados; três testes dependentes de gameplay/instrumentação de desenvolvimento explicitamente ignorados nesta compilação. Foram executados e aprovados na rodada de desenvolvimento abaixo, não contados como aprovação da distribuição.

- Suíte completa de desenvolvimento: **776 testes aprovados, zero falhas/ignorados**, incluindo backend libretro real e programa sintético próprio.
- Núcleo autoral: **35 grupos C++ Windows** aprovados, compilação com warnings tratados como erro. Fetcher/FIFOs com regressões de latches e raster; margem PCM derivada do limite matemático do filtro, não de modelo de aparelho.
- Mooneye independente, revisão fixada `31510e12eea6286d36eea060a6adde755e1067aa`: **93/94 DMG**, uma falha de hand-off LY; 12/12 casos PPU aprovados, zero timeout/unsupported/erro de harness. Nove testes de outros modelos preservados no relatório bruto. Não foi aplicado valor arbitrário para esconder a falha.
- SameSuite, revisão `f15645fb049a47ea235f6d2c9a033e72d8087901`: **2/2 DMG**; 68 casos CGB/PCM não executados. Apenas fontes diagnósticos independentes, não implementações de emulação externas, foram utilizados.
- Sessões locais autorizadas: Red 12.240 frames, SAVE pelo menu e restauração em novo processo de 3.300 frames; Yellow 10.000 frames. Imagens finais esperadas e SRAM preservadas. Zero saturações em 19.673.348 amostras Red e 16.072.998 Yellow; não é certificação acústica ou campanha completa.
- Restauração Cofre→host→sessão seguinte com ROM própria, sem modificar saves pessoais. Testes de cancelamento, ativação separada, perfil, ROM/mapper divergente, origem adulterada, hash do destino alterado, jogo aberto, lease concorrente, junction e caminho Unicode >260 caracteres.
- Interrupção do processo após flush do temporário e depois da substituição atômica: principal íntegro e anterior/origem/Cofre preservados. Não certifica falha física de energia/armazenamento.
- QA Electron: oito capturas, 1440×900 e 1024×768, serviço real em perfil temporário, conferência de aplicação/cancelamento e inspeção visual. Fixture FireRed permanece presente no catálogo e associação.

A distribuição mantém ON BRUM desabilitada para gameplay, sem preferência pública que contorne o gate. A API de armazenamento opera sem iniciar a engine. Os backends externos existentes permanecem disponíveis.

O pacote é conferido contra a fonte e o host compilado, exclui dados pessoais/ROMs/BIOS/DLL de teste e usa o atualizador existente. Assets são enviados em rascunho, validados por tamanho/digest do GitHub e só então publicados como Latest oficial. Nenhuma atualização é instalada no computador do usuário pelos testes.

Não houve nova validação móvel nesta rodada PC nem publicação de APK/IPA. A ON BRUM **não está 100% concluída**; esta é uma entrega oficial incremental do Launcher, com limites explícitos.

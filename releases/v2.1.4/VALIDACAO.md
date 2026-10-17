# Validação PC 2.1.4 — 2026-10-17

## Artefato oficial

- Fonte privada local: commit `20c2900fbf00c396d17e16ad9f62631891c1942f`. Somente documentação de publicação é enviada a este repositório público; o código privado do Launcher não é copiado para cá.
- `BRUMCLASSICS-OFICIAL.exe`: **393.463.813 bytes**.
- SHA-256: `a4f844a40d235a45a205e9751ef43bb05a449260622ebed49ffaa3f41ebb4a51`.
- Build portátil oficial Windows x64/Electron 43.4.0 concluída com exit 0, host recompilado com warnings tratados como erro e **sem** o define de desenvolvimento.
- Os 181 arquivos de `src` foram conferidos byte a byte contra o ASAR, que contém 1.212 arquivos incluindo dependências. Sem diretórios de build/testes/fontes nativas/scripts diagnósticos ou arquivos de ROM/save/IPA/APK na aplicação empacotada.
- O ASAR e o host foram extraídos do próprio portátil e coincidem com os artefatos conferidos. SHA-256 ASAR `df6e96174383a740aed37bfe0324770a0a7a13e2a2aa2d36e68afda1a27e365c`; host `1d8920a8ee32bfe19f000b1ed79ff094a528ff5096d820d6935ca6ba7475add2`. O extrator 7-Zip informa dados após o arquivo interno por se tratar do contêiner executável/SFX; a extração terminou íntegra e ambos os hashes foram comparados.
- Host empacotado: hostAPI 2, saveRestoreAPI 1, ExternalEngineAdapter disponível, `onBrumDevelopmentEnabled:false` e `onBrumProductionReady:false`. Uma tentativa explícita de gameplay experimental foi recusada com exit 2, sem READY e sem save criado, usando ROM sintética própria.
- Worker de monitoramento executado pelo ASAR em perfil temporário: amostra de memória/CPU/GPU/processo recebida. FPS foi corretamente declarado indisponível sem PresentMon, não inventado.

## Testes desta preparação

- **783/783 testes Node**, zero falhas/ignorados, com backend libretro real local e host de desenvolvimento. Cobrem o Cofre, integração nativa, atualização, preservação de perfis e troca/reabertura de executável em ambiente temporário.
- Regressões específicas de BRUMNEWS/atualizador: **27/27**. A primeira rodada encontrou o destaque editorial ainda marcado 2.1.3; foi corrigido e a suíte completa repetida com sucesso.
- Cofre: oito capturas/assertions em 1440×900 e 1024×768; galeria FireRed inspecionada. Prévia, associação com categoria antiga, importação seletiva, conflito preservado, escolha manual de ativo, exclusão cancelada e aplicação autoral confirmada separadamente. Fixtures sintéticas e perfil temporário; dados pessoais não usados.
- Host de distribuição/storage-only: **9 aprovações, zero falhas, 12 skips explícitos** por exigirem gameplay/instrumentação de desenvolvimento; esses casos foram executados na suíte completa. Não se contam skips como aprovação.
- Revisão independente do código e notas: nenhum bloqueador Critical/Important. A revisão não certifica a precisão do hardware emulado, hardware físico ou compatibilidade geral.

## Evidência da engine e limites preservados

A lógica do hardware não foi modificada nesta preparação de versão; entram as correções anteriormente medidas em 37 grupos C++ e nas suítes independentes fixadas. Resultado local gráfico: **12/25 pass, 13 fail**, sem recorte ou tolerância. Mooneye **93/94 DMG**, com uma falha LY pós-boot; 12/12 PPU. SameSuite **2/2 DMG**, 68 casos CGB/PCM não executados. DMG sound **12/12**, apenas testes locais do mirror sem licença explícita, não distribuídos ou incorporados ao núcleo.

Quatro casos gráficos autossuficientes ainda falham; nove também exigem dados de VRAM deixados pelo firmware que o boot simulado não restaura. Não foi baixada/embutida BIOS ou fabricada referência para aprovar. O caso OBJ sem SCX regrediu de 55 para 81 pixels divergentes e continua reprovado, enquanto a variante com SCX passou. Replays locais autorizados Red/Yellow/restauração preservaram SRAM e imagem final; PCM mudou com CH3 e não atingiu rails nas sessões medidas. Não é campanha completa, avaliação acústica ou certificação de todos os jogos.

**A ON BRUM não está 100% concluída e não foi habilitada para gameplay público.** Permanecem precisão gráfica/pós-boot, STOP/RTC/bus e validação mais ampla. Os backends externos existentes são preservados. Nenhuma nova validação/publicação móvel, APK/IPA, ROM, BIOS, save pessoal ou DLL de core foi adicionada.

## Publicação e atualização

O fluxo de publicação envia os assets a uma release em rascunho, confere tamanho e digest SHA-256 pela API do GitHub e só depois promove para Latest oficial não prerelease. A validação posterior consulta a release e baixa o executável pelo serviço real do Launcher para um perfil temporário; não instala no perfil pessoal. Atualização pelo aplicativo: [instruções e limites](RELEASE-NOTES.md).

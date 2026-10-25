# BRUMCLASSICS OFICIAL 2.1.6 — M.U.R.B ENGINE experimental

## Atenção antes de atualizar

Esta é uma distribuição **experimental para testar os módulos autorais**, publicada no canal oficial a pedido do responsável pelo projeto. **Não é uma declaração de suporte completo aos consoles.**

O Launcher PC passa a iniciar CLASSICS **exclusivamente pela M.U.R.B ENGINE**, sem RetroArch, núcleos libretro ou fallback automático. Jogos que funcionavam nos emuladores anteriores podem não iniciar, travar ou apresentar problemas gráficos, de áudio e de controles. Se você depende dessa compatibilidade anterior, mantenha a versão 2.1.5 até a validação dos módulos necessários.

## O que mudou

- Registro dos 32 módulos autorais acessível pelo host nativo. Cada um é apresentado como experimental, não como compatibilidade certificada.
- Abertura pela ação **TESTAR NA M.U.R.B ENGINE**, com aviso de limitações.
- Caminho de lançamento CLASSICS não usa opções antigas para chamar emuladores externos.
- Adaptação das máscaras de controles às APIs dos módulos, sem truncar os botões adicionais em oito bits. Periféricos ausentes no próprio core continuam indisponíveis.
- Tratamento de formatos de vídeo/áudio e saídas múltiplas no host.
- Falha antes do primeiro frame encerra a tentativa; um frame bloqueado é limitado a 15 segundos no processo isolado de teste. Isso não é um limitador de FPS. Progresso posterior ao último save confirmado pode ser perdido se esse processo for interrompido.

## Seus dados

- Saves, configurações, ROMs e Cofre anteriores não são apagados.
- Não há importação, migração ou ativação automática de saves antigos.
- Testes usam `brum-core-pc/murb-test-saves/<perfil>/<sistema>/<SHA256>.onbrum` dentro da pasta de dados do perfil.
- Esse armazenamento é excluído do scan automático do Save Vault, inclusive quando o scan começa em uma pasta ancestral.
- Aplicar saves do Vault ao runtime experimental está explicitamente indisponível. O gerenciamento das cópias no Vault continua separado.
- O host confirma identidade, tamanho, formato, CRC/SHA e gravação durável, mantendo a cópia `.previous`.
- Os arquivos de emuladores externos já existentes no computador são preservados, mas não são iniciados pelo Launcher nesta versão.

## Limitações conhecidas

- Não há save states nem desbloqueios RetroAchievements durante a execução autoral. A consulta de progresso é mantida separadamente.
- ZIP, 7z, RAR, CHD, RVZ, GCZ, CSO e descritores CUE/GDI/M3U não têm leitores integrados nesta etapa e são recusados. Extensões desconhecidas também são recusadas.
- Arcade genérico não possui módulo autoral registrado e permanece indisponível, sem fallback.
- No piloto DMG, Mooneye aplicável e Acid2 passaram, mas nove comparações gráficas seguem abertas por precondições de boot. Isso não foi transformado em aprovação.
- Os demais módulos têm cobertura sintética; não existe uma matriz de jogos comerciais validando a conclusão dos sistemas.
- Analógicos e outros periféricos ainda não implementados pelos próprios cores não se tornam funcionais apenas porque o host transmite os dados.
- Não foi realizada validação física de controles ou certificação de gameplay prolongado nesta entrega.

Página do jogo, intro, Save Sync manual, perfis e múltiplas contas Steam da 2.1.5 são mantidos. Esta publicação é somente para Windows; Android e iOS não foram alterados. Não inclui ROMs, BIOS ou ferramentas internas de análise.

## Teclado do host

Setas: direcional; X/Z: A/B; A/S: X/Y; Shift direito/Enter: Select/Start; Q/W: L/R; 1/2: L2/R2; 3/4: L3/R3; C/V: C/Z adicionais. A disponibilidade efetiva depende da implementação do módulo.

Atualização: use **Verificar atualizações** no Launcher. A instalação/reinicialização continua sendo uma ação explícita do usuário.

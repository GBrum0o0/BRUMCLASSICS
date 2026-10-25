# BRUMCLASSICS OFICIAL 2.1.7 — revisão de vídeo da M.U.R.B ENGINE

Atualização PC experimental, no canal oficial do Launcher. Integra o snapshot Antigravity `64cbc2d7f2f4f8a3ce61a2ccd81771504ccf7ae6`, preservando a integração e as proteções publicadas na 2.1.6.

## Novidades revisadas

- Contrato VideoFrame comum, com tamanho de linha em bytes, formato e metadados de apresentação.
- Correções de tamanho de linha nos módulos, inclusive NES e GBC.
- Padronização das cores para o valor numérico RGBA8888, corrigindo interpretação inconsistente de canais e do preto em vários módulos.
- Conversor do host testado com RGBA8888, BGRA8888, XRGB8888, RGB565 e RGB555; respeita preenchimento entre linhas e rejeita frames inválidos.
- Apresentação GDI com buffer intermediário e cópia final única, para reduzir cintilação ao desenhar/redimensionar a janela. Recursos GDI são liberados e falhas de alocação são tratadas.
- Ajuste de foco ao abrir a janela visível.
- Captura diagnóstica de frame por `--capture-frame <novo-arquivo.bmp>`. A captura não sobrescreve arquivos existentes e só anuncia sucesso após gravação confirmada.

O runner alternativo antigo com CLI compatível com RetroArch e saves brutos não substituiu o host integrado: foram mantidos os controles corrigidos, as validações de persistência e o isolamento de dados da 2.1.6.

## Limites e segurança

**Não é conclusão do suporte dos consoles.** Os 32 módulos continuam experimentais, sem matriz de jogos comerciais validada. Uma correção de vídeo não completa CPUs, GPUs ou periféricos ausentes nos cores. Jogos podem continuar sem iniciar ou apresentar falhas de gráficos, áudio e controles.

CLASSICS continua usando exclusivamente a M.U.R.B, sem RetroArch/libretro ou fallback automático. Arcade genérico permanece indisponível. ZIP/7z/RAR, CHD/RVZ/GCZ/CSO e descritores CUE/GDI/M3U continuam sem leitores integrados.

Saves anteriores, ROMs, perfis e Save Vault são preservados. Sessões experimentais continuam em `brum-core-pc/murb-test-saves/<perfil>/<sistema>/<SHA256>.onbrum`, sem importação ou ativação automática de saves antigos. Aplicação de saves do Vault ao runtime experimental, save states e desbloqueios online de conquistas continuam indisponíveis.

Mantidas página do jogo, intro, Save Sync manual e contas Steam. Não inclui ROMs, BIOS ou ferramentas de análise internas. Android/iOS não foram alterados. Não houve certificação de gameplay prolongado ou validação física de controles.

Para atualizar, use **Configurações → Sistema → Atualizações → Verificar atualizações** e confirme a instalação quando desejar. Quem precisar dos emuladores externos anteriores deve manter a 2.1.5.

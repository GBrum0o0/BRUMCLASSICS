# BRUMCOMPANION — anotações e desempenho durante o jogo

Requisitos recomendados: BRUMCLASSICS OFICIAL 1.52.0 e BRUMCLASSICS MOVEL 0.15.0. Consulte também o [guia móvel completo](MOVEL.md).

## Preparação

1. Atualize o launcher em **Configurações → Sistema → Atualizações**.
2. Instale o APK 0.15.0 sobre a versão móvel existente, sem apagar os dados do aplicativo. Use **Perfil → Atualizações**; ao migrar de HTTP, refaça o pareamento pelo QR completo HTTPS.
3. Conecte computador e celular à mesma rede local.
4. Se ainda não estiver pareado, abra **Configurações → MOVEL** no launcher e **Perfil** no aplicativo para concluir o pareamento.
5. Abra a aba **COMPANION** no celular.

## Durante a sessão

Inicie um jogo moderno ou CLASSICS pelo launcher. Quando a sessão real for detectada, a aba mostra o jogo se ele já possuir alguma anotação. Os campos são **Onde parei**, **Objetivos**, **Dicas** e **Comandos**. Crie a primeira nota no Perfil do Jogo do desktop. Edite os textos e toque em **SALVAR NO BRUMCOMPANION**. Cada campo aceita até 6.000 caracteres.

Com a conexão ativa, o texto é sincronizado com o Perfil do Jogo no computador. O Companion acompanha a sessão registrada pelo launcher; não promete identificar jogos abertos por fora dele.

## Desempenho ao vivo

Durante a sessão, o painel mostra CPU, GPU, RAM, VRAM, consumo do processo, duração e, quando configurado, FPS e temperatura da CPU. Use **VER DETALHES** para alternar entre a leitura rápida e a completa. GPUs NVIDIA usam `nvidia-smi` quando disponível; AMD e Intel usam os contadores nativos de GPU do Windows.

Para ativar FPS, abra **Configurações → MOVEL → ATIVAR FPS**. O launcher pede confirmação, baixa o PresentMon portátil somente do projeto oficial GameTechDev/PresentMon e valida o SHA-256 publicado pelo GitHub. Não instala driver ou serviço e não injeta DLL no jogo.

A temperatura da CPU aparece quando o firmware identifica explicitamente o sensor ou quando LibreHardwareMonitor/OpenHardwareMonitor já está ativo e publica um sensor de CPU. O BRUMCLASSICS não instala esses programas nem seus drivers. Sensores ausentes ou ambíguos aparecem como **INDISP.**, sem transformar temperatura da placa-mãe em temperatura da CPU.

A coleta roda a cada três segundos em worker isolado e somente enquanto existe uma sessão. Em **Configurações → MOVEL**, desligue integralmente o monitor ou apenas o alerta térmico. Nenhum histórico é salvo por padrão, PID não é transmitido e nenhuma DLL é injetada no jogo.

## Sem conexão e conflitos

Anotações já sincronizadas continuam disponíveis na Biblioteca offline. Rascunhos salvos no Companion enquanto a rede está indisponível permanecem no celular e são enviados quando a conexão retorna.

Se ambos os dispositivos alterarem o mesmo campo, o aplicativo preserva o rascunho e oferece **MANTER CELULAR**, **USAR LAUNCHER** ou **CANCELAR**. Alterações em campos independentes podem ser mescladas automaticamente.

## O jogo não aparece?

- Confira se o executável aberto é realmente o 1.52.0, não apenas um arquivo novo na pasta enquanto o anterior continua rodando.
- Confira se o APK instalado é o 0.15.0. As próximas versões aparecerão em **Perfil → Atualizações**.
- Veja se o celular está conectado ao launcher correto na mesma rede.
- Abra o jogo pelo launcher e aguarde a detecção do processo.
- Se necessário, reabra o aplicativo para renovar a conexão. Só refaça o pareamento se ele tiver sido revogado ou perdido.

A janela de preparação do jogo e suas anotações continuam funcionando no computador. BRUMWORLD também contém o guia visual do aplicativo móvel.

# BRUMCLASSICS OFICIAL 2.1.40 — Toque DS/3DS, Gamepad Wii/PSP e Controle Wii U (Cemu)

- **Toque no DS e 3DS (celular e computador):** retencao temporizada de toques rapidos no servidor WebSocket para que nenhuma batida curta seja perdida entre quadros, fallback funcional do mouse no PC mesmo em modos multi-jogador, `citra2018_analog_function = C-Stick` e preservacao da proporcao do Nintendo DS em tela cheia.
- **Wii e PSP no modo Gamepad e abertura normal:** verificacao do RetroAchievements movida para segundo plano apos `BRUM_CORE_READY`, eliminando o bloqueio antes do primeiro quadro; prioridade dos nucleos empacotados do pacote sobre caminhos antigos; serializacao de chamadas remotas no launcher; tolerancia ampliada de abertura e garantia de visibilidade da janela mesmo sob `windowsHide`.
- **Wii U (`Cemu`) pelo celular (`MYbrumCONTROL` / Gamepad):** perfil `controller0.xml` exclusivo para o slot virtual ViGEm em modo 1 jogador sem sobrescrever o mapeamento com outros controles XInput, fallback automatico para teclado quando ViGEm estiver indisponivel e polling estendido do slot PnP ViGEmBus.

Atualize pelo botao **Verificar atualizacao** no Launcher ou baixe diretamente `BRUMCLASSICS-OFICIAL.exe`. Seus saves e configuracoes sao preservados.

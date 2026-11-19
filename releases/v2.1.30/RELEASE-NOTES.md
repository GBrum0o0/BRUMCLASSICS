# BRUM CLASSICS v2.1.30 (Windows)

## Novidades e Correções
- **Gamepad M.U.R.B para jogos de PC e Wii U (Cemu) com ViGEmBus nativo:** quando o driver Nefarius ViGEmBus está instalado no Windows, o `brum-core-pc.exe` emula um controle Xbox 360 (`XUSB`) nativo reconhecido automaticamente por jogos de PC e pelo Cemu (com fallback automático para teclado caso o ViGEmBus não esteja presente).
- **Correções críticas do modo Gamepad e 1 Jogador:** corrigido o bug no roteamento 1P que forçava `--hybrid-mode`, anexado `--desktop-gamepad` também quando um jogo de PC já estiver em execução, e encerrado qualquer bridge anterior antes de iniciar um título clássico para evitar conflito na porta `8089`.
- **Segunda tela Nintendo DS / 3DS / Wii U no WebSocket M.U.R.B:** envio atômico de frames (sem corrupção de pacote parcial), handshake de cabeçalhos case-insensitive, throttling otimizado para manter responsividade do joystick, e mapeamento correto de toque DS (`0..255` x `0..191`).

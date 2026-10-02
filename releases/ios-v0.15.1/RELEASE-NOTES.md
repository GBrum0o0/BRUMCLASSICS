# BRUMCLASSICS MÓVEL iOS 0.15.1

## Áudio, diagnóstico e WonderSwan

- WonderSwan e WonderSwan Color `.ws`/`.wsc` passam a abrir diretamente no BRUM Core com Beetle WonderSwan.
- O iOS ativa a sessão de áudio antes de iniciar a fila PCM e trata interrupções/retomada do sistema.
- Taxas de áudio inválidas passam a usar um valor seguro e falhas da saída sonora são exibidas ao usuário.
- Um pedido de encerramento enviado pelo núcleo não fecha mais o jogo silenciosamente; o app preserva a tela e explica a falha.
- O ID oficial e o console RetroAchievements chegam ao host nativo como primeira etapa da integração com `rcheevos`. Esta versão ainda não anuncia desbloqueios ativos.
- Beetle WonderSwan usa revisão fixada, licença GPL-2.0-or-later empacotada, saves e slots rápidos do host multicore.

O IPA é arm64, sem assinatura, e deve ser assinado pelo Sideloadly ou AltStore. O build real depende do workflow macOS.

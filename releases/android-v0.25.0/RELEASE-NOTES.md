# BRUMCLASSICS MÓVEL Android 0.25.0

- WonderSwan e WonderSwan Color `.ws`/`.wsc` passam a abrir diretamente com Beetle WonderSwan.
- A fila PCM nativa agora é sincronizada e limpa ao pausar, retomar, carregar estado ou usar avanço rápido.
- Erros durante `retro_run` e pedidos de encerramento do núcleo aparecem em um diálogo, em vez de derrubar a tela sem explicação.
- Taxas de áudio inválidas usam fallback seguro e erros de escrita do `AudioTrack` são diagnosticados.
- O ID e o console RetroAchievements acompanham a sessão integrada como base para `rcheevos`; desbloqueios ainda não estão ativos.

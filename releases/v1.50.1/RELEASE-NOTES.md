# BRUMCLASSICS OFICIAL 1.50.1 — Desempenho ao vivo confiável

Inclui o monitor lançado na 1.50.0 e corrige a exibição quando o Companion já estava aberto antes da primeira medição.

- MOVEL 0.14.1 mostra o painel automaticamente, sem reconstruir a tela de notas a cada leitura.
- O painel some quando a sessão termina, a rede cai ou a amostra expira após 15 segundos.
- Leituras atrasadas do jogo anterior são descartadas.
- Uma mudança do PID detectado é repassada ao monitor.
- CPU do processo usa o total de processadores lógicos como referência, como o Gerenciador de Tarefas.
- CPU/RAM total, CPU/RAM do processo e GPU NVIDIA (uso, temperatura e VRAM via nvidia-smi) continuam disponíveis conforme o hardware.

## Limites importantes

FPS, frame time e temperatura da CPU **ainda não têm provedor integrado**. Instalar PresentMon isoladamente não habilita esses campos nesta versão. Eles ficam indisponíveis, sem números inventados. AMD/Intel GPU e histórico de desempenho também não estão implementados nesta etapa.

Nenhum driver foi instalado, nenhuma DLL é injetada no jogo e o monitor pode ser desligado em **Configurações → MOVEL**. O telefone precisa estar pareado na rede local. O APK 0.14.1 (versionCode 22) deve ser instalado sobre o anterior, preservando cache, anotações e pareamento.

BRUMNEWS, BRUMWORLD e linha do tempo atualizadas. Contas, coleções, saves e ROMs não são alterados.

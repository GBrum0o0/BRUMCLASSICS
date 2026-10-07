# BRUM Core Mobile: execução, controle virtual e viewport

Estado desta revisão: implementação parcial, com validação estática e testes locais. Uma build bem-sucedida não comprova compatibilidade de um jogo nem desempenho em hardware real.

## Contrato de execução

- A cadência normal deve seguir o FPS declarado pelo core Libretro, não um valor de 60 Hz imposto pelo aplicativo. Fast-forward é uma escolha explícita do usuário.
- O modo padrão da imagem é **FIT**: todo o quadro permanece visível. **CORTAR** é uma escolha explícita. A transformação inversa do toque deve usar a mesma geometria da imagem.
- Um perfil de controle virtual deve ser escolhido pelo ID do sistema; sistemas novos precisam de mapeamento explícito. Isso ainda não equivale a mapeamento correto para cada máquina de arcade ou a validação de todos os cores.
- Pausar/sair deve soltar entradas para evitar botões ou toque presos no próximo jogo.
- Desempenho deve ser medido por etapa e em dispositivos reais antes de mudar resolução, threading, filas ou qualidade gráfica. Não há tabela por modelo de aparelho.

## O que esta revisão já mudou

| Área | iOS | Android |
| --- | --- | --- |
| Imagem padrão | FIT e transformação de toque compartilhada; layout DS/3DS vertical/horizontal/foco/swap | FIT, com opção explícita CORTAR |
| Entrada | D-pad contínuo com diagonais, perfis por sistema, feedback visual e háptico, limpeza ao pausar/sair | Limpeza de estado ao pausar; ponteiro compartilhado com o core sem corrida de dados |
| Cadência | Ainda depende do `CADisplayLink`/thread principal | Usa FPS declarado pelo core, inclusive 75 Hz ou valores futuros |
| Diagnóstico | HUD local opt-in com FPS, tempo de core+host, tempo do callback de vídeo e estado térmico | Teste da política de cadência; telemetria por etapa ainda pendente |

## Gargalos e limites ainda abertos

1. **iOS, thread principal:** `retro_run()` e a apresentação passam pela thread principal. O callback de vídeo faz alocação/conversão/cópia por frame. Uma migração para fila de emulação separada exige antes isolar callbacks, estado de entrada, áudio, OpenGL/Metal e ciclo de vida; mudar apenas a thread seria inseguro.
2. **Android, cópia de vídeo:** o caminho atual faz callback nativo → framebuffer → array Java → Bitmap → Canvas. Reduzir cópias requer um contrato de pixel buffer/texture por backend, medição de latência e validação de contexto gráfico. Não há promessa de zero-copy nesta revisão.
3. **Áudio:** o Android ainda usa `AudioTrack` com escrita bloqueante e buffer fixo derivado do mínimo do dispositivo; iOS usa `AudioQueue`. Precisam de medição de underrun/overflow, latência e sincronização A/V. A falta de áudio relatada em jogos específicos ainda não foi reproduzida nesta revisão.
4. **3DS/GameCube/Arcade:** capacidade depende também de core compilado, formato da ROM, BIOS/arquivos de sistema, API gráfica e compatibilidade do jogo. O layout de duas telas e o mapeamento geral não transformam um core incompatível em suporte completo. O Android ainda não oferece paridade de 3DS/GC nem viewport multitelas equivalente ao iOS.
5. **Controle virtual:** perfis existentes precisam de testes em dispositivo por core, incluindo seis botões de Saturn/Mega Drive, controles específicos de arcade, analógicos, gatilhos e multitouch simultâneo. Ainda falta um roteador de ponteiros por identidade e um adaptador de mapeamento lógico por máquina/core.
6. **Escalonamento:** nenhum limite por modelo de celular foi introduzido. Ajustes automáticos de resolução, cache, paralelismo e shader só devem ser feitos com recursos declarados pelo core e medições de CPU/GPU/memória/termal por sessão. Um FPS do jogo também pode ser limite do próprio jogo ou core, não necessariamente do host.

## Critérios de validação antes de chamar o suporte de pronto

- Testar abertura, encerramento e retorno à biblioteca com ROMs legais de cada sistema em iOS e Android compatíveis; registrar core, jogo, formato, logs e resultado.
- Testar áudio por minutos, pausa/retorno, troca de rota, fast-forward, pressão térmica e saída inesperada.
- Testar toque e controles virtuais com duas ou mais entradas simultâneas, rotação, safe areas, DS/3DS em cada layout e controle físico.
- Registrar frametime do core, conversão/render, áudio e UI em aparelhos fracos/intermediários/fortes; verificar se o gargalo vem do aplicativo antes de otimizar.
- Executar compilação iOS no macOS, build/testes Android e testes C++ compartilhados após cada alteração relevante.

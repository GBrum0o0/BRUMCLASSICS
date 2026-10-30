# Revisão dos snapshots do Antigravity — 2.1.18

Escopo: commits 8ed9b04 e 637e20a, comparados também ao código efetivamente lançado na 2.1.17. Três revisões independentes examinaram CPU/memória, host/vídeo/input e testes. O checkout original foi preservado.

## Alterações excluídas

- **Host e saves:** no snapshot 637e20a, uma falha de construção do armazenamento protegido podia ser capturada, deixando um fallback gravar bytes brutos em um caminho de save. O novo Save State usava dados de bateria, sem capturar CPU/PPU/estado completo da execução. Também faltavam proteções já lançadas de watchdog, PCM e falha do primeiro frame. O host publicado foi mantido.
- **GBA e NES:** a cópia integral reverteria correções posteriores já presentes no Launcher. Foram reproduzidas incompatibilidades de formato EEPROM, comandos EEPROM incompletos que alteram dados, perda de bytes de timer/DMA, limpeza indevida de SRAM no reset e regressões de cabeçalhos/mapeadores e buffer da PPU. Os arquivos lançados foram mantidos.
- **Recursos demonstrativos:** o renderizador GPU novo somente registra configuração/contadores; o JIT copia código x86 fornecido por testes, sem tradução de instruções dos consoles no runtime. Coprocessadores e mapeadores especiais têm referências limitadas aos testes. Troca de disco/remapeamento do novo menu apenas atualizam mensagens/flags. As regras de conquistas são demonstrativas e não constituem integração real com RetroAchievements.
- **Saídas artificiais:** determinados núcleos novos preenchem vídeo a partir de bytes arbitrários ou cores inventadas e forçam áudio. Essas alterações não foram usadas como evidência de jogos funcionando e ficaram fora da integração.

## Limites do diagnóstico original

A suíte original compilou com MSVC C++17, /W4 /WX e passou 347 testes. O harness original não foi executado sobre o projeto: contém destino de matriz fixo, que poderia sobrescrever dados do próprio checkout.

Uma cópia temporária, limitada a fixtures e com saída isolada, foi executada. Vinte e sete dos 32 sistemas não demonstraram progressão visual; resultados de falha ainda retornaram código zero. Há indicadores de boot, entrada e precisão definidos a partir de carga ou constantes, além de falhas de save que não determinam corretamente o resultado. Por isso esses relatórios e a matriz não foram distribuídos como certificação de compatibilidade.

## Subconjunto aprovado

Apenas `sms.hpp`, `sms_engine.cpp` e `pce_engine.cpp` foram integrados do snapshot, com seis regressões novas e preservação dos testes existentes. A integração nativa passou **355 testes**, com `gameplayReady=false` mantido. Vinte e nove arquivos protegidos de host e GB/GBA/NES foram comparados com a base lançada: nenhuma alteração.

As demais alterações permanecem no trabalho original para correção e validação posterior. Nenhuma ferramenta pessoal de agente foi incorporada à distribuição.

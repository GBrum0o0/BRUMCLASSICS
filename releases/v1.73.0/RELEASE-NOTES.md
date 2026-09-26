# BRUMCLASSICS OFICIAL 1.73.0

Esta versão reorganiza o trabalho interno do launcher para impedir que sincronizações, varreduras, capas e renderizações disputem recursos sem controle.

## Principais mudanças

- Linha do tempo interna para abertura, biblioteca, capas, sincronizações, workers e cartões reconstruídos.
- Fila global de tarefas de fundo com limite de concorrência e prioridades.
- Sincronização manual com prioridade sobre atualizações automáticas que ainda aguardam.
- Snapshot local exibido primeiro; validações continuam em segundo plano.
- Biblioteca virtualizada acima de 120 jogos.
- Decodificação limitada a três capas simultâneas.
- Pausa de trabalho visual e geração de miniaturas quando o launcher fica minimizado.
- Seções pesadas carregadas sob demanda e Atividade inicial reduzida a um resumo.
- Diagnóstico legível mostra filas e o maior gargalo observado.

O armazenamento continua em JSON nesta versão. SQLite só será considerado depois que as medições apontarem um gargalo real de leitura ou indexação.

Android 0.20.0 e iOS 0.11.0 continuam compatíveis e não foram alterados.

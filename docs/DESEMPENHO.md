# Desempenho e diagnóstico

O BRUMCLASSICS abre usando o último snapshot local válido. Steam, conquistas, monitoramento e outras fontes são atualizados depois, sem substituir a biblioteca visível por uma tela vazia.

## O que é medido

- abertura da janela e exibição da biblioteca;
- leitura do snapshot local;
- renderização e quantidade de cartões reconstruídos;
- carregamento de capas;
- duração de cada sincronização;
- duração e espera de workers.

O painel **Atividade → Saúde do sistema → Verificar** apresenta médias, picos, filas e o maior gargalo observado.

## Controle de concorrência

Workers usam uma fila limitada a duas tarefas. Sincronizações continuam seriais, mas ações manuais têm prioridade sobre atualizações automáticas ainda aguardando. Capas são decodificadas em no máximo três operações simultâneas.

Bibliotecas com mais de 120 jogos usam renderização por janela: somente cartões próximos da área visível ficam montados. Ao minimizar o launcher, trabalhos visuais e a geração antecipada de miniaturas são pausados.

## SQLite

A versão 1.73.0 não migra dados para SQLite. A decisão é intencional: primeiro o launcher mede. Uma migração só deve acontecer se a linha do tempo comprovar que leitura, escrita ou indexação dos arquivos atuais é o gargalo dominante.

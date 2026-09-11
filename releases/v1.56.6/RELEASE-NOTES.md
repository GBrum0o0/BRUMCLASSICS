# BRUMCLASSICS 1.56.6

## Sessões mais confiáveis

- Jogos abertos pela Steam, Ubisoft Connect e outros launchers continuam aparecendo como ativos durante a troca entre processos.
- O executável do jogo é reconhecido pelo nome quando o Windows oculta seu caminho por ele estar executando como administrador.
- Reinicializações rápidas e executáveis seguros dentro da pasta do jogo podem continuar a sessão.
- Launchers, instaladores, atualizadores e crash reporters são ignorados para não criar falsos jogos ativos.
- O PID é atualizado corretamente quando o processo principal muda.

## Encerramento confirmado

O launcher agora exige 12 verificações consecutivas sem encontrar o processo antes de concluir a sessão. Esse intervalo evita que uma transição temporária seja registrada como fechamento, sem acrescentar o tempo de espera às estatísticas finais.

## Validação

- 499 testes automatizados aprovados.
- Testes direcionados reproduzem a transição para um executável elevado sem caminho visível.
- Verificação completa de sintaxe aprovada.
- Pacote confirmado como edição `official`, versão `1.56.6` e descrição Windows `BRUMCLASSICS`.
- Correção e notas da versão conferidas diretamente no conteúdo empacotado.

## Preservação

Contas, biblioteca, coleções, saves, capas, anotações, controles, Android e iOS permanecem preservados. Registros históricos de sessões anteriores não são reescritos.

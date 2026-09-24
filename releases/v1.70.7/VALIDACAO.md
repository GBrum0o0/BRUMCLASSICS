# Validação — BRUMCLASSICS 1.70.7

- Verificação sintática completa: aprovada.
- Suíte automatizada: **623 testes aprovados, zero falhas**, nenhum teste ignorado.
- Teste visual: último jogo inicialmente selecionado, prévia temporária de outra capa e retorno automático ao destaque foram confirmados.
- Fallback sem histórico validado com favorito e primeiro jogo visível.
- Separação do último jogo por perfil coberta pela precedência explícita de `profileLastPlayedAt`.
- Auditoria das dependências de produção: **zero vulnerabilidades conhecidas**.
- Pacote ASAR: versão 1.70.7 confirmada; **128 arquivos de `src` comparados por SHA-256**, sem ausências, divergências ou arquivos extras.
- Android 0.19.0 e iOS 0.10.0: código e protocolo inalterados; nenhum pacote móvel novo.
- Executáveis: `BRUMCLASSICS-OFICIAL-1.70.7-portable.exe` e `BRUMCLASSICS-OFICIAL.exe`.
- Tamanho de cada executável: `385917103` bytes.
- SHA-256: `1f4e63cc4d5238dbbd47e722d0217500f59e07219d8108178a1a0eed6e632df2`.

Esta validação não equivale a testar todos os serviços remotos em todas as contas. A Vitrine depende das datas de última sessão disponíveis no perfil e na biblioteca local.

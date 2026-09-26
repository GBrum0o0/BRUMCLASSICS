# Validação — BRUMCLASSICS 1.72.1

- Verificação sintática completa: aprovada.
- Suíte automatizada: **637 testes aprovados, zero falhas**, nenhum teste ignorado.
- Manifesto real do Counter-Strike 2 confirmado com `StateFlags = 4`, pasta instalada e `cs2.exe` presente.
- Regressão dedicada confirma que uma instalação válida prevalece sobre contadores históricos e sobre a estimativa de espaço.
- Transferência genuína com pouco espaço permanece monitorada e não vira erro terminal inferido.
- Antes de publicar um erro de instalação, a camada principal tenta confirmar a integridade local.
- Erro antigo é ocultado quando a biblioteca já classifica o jogo como íntegro.
- Auditoria das dependências de produção: **zero vulnerabilidades conhecidas**.
- Pacote ASAR: versão 1.72.1 e edição oficial confirmadas; **131 arquivos de `src` comparados por SHA-256**, sem divergências.
- Android 0.20.0 e iOS 0.11.0: código e protocolo inalterados; nenhum pacote móvel novo.
- Executáveis: `BRUMCLASSICS-OFICIAL-1.72.1-portable.exe` e `BRUMCLASSICS-OFICIAL.exe`.
- Tamanho de cada executável: `385963138` bytes.
- SHA-256: `5ce85bc72eddafb98f32f1a647fb8b8308d7657677ae866719badfd07931076b`.

Esta validação não equivale a testar todos os serviços remotos em todas as contas. A correção usa somente manifesto e evidências locais da instalação oficial da Steam.

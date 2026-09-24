# BRUMCLASSICS 1.70.7 — Vitrine pessoal da biblioteca

A Vitrine da Biblioteca agora funciona como uma retomada visual da sua jornada, destacando automaticamente o jogo mais recente do perfil atual.

## Último jogo em destaque

- Ao abrir a biblioteca, a Vitrine seleciona o último jogo jogado pelo perfil ativo.
- O histórico de cada perfil é respeitado: trocar de jogador também troca o destaque correspondente.
- O cartão informa claramente quando está exibindo o **Último jogo jogado**.

## Navegação e prévia

- Passar o ponteiro ou focar outra capa mostra uma **Prévia da biblioteca** sem alterar o histórico.
- Quando o ponteiro sai da grade, o destaque retorna ao último jogo jogado.
- Durante a navegação pelo teclado, a prévia permanece no item em foco e retorna quando o foco deixa a grade.
- Sem histórico, um favorito assume o destaque; se não houver favoritos, é usado o primeiro jogo visível.

A Vitrine continua opcional em **Configurações → Experiência** e não substitui nem altera o Living Room Mode.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações de código ou protocolo nesta atualização exclusiva do launcher Windows.

Validação: 623 testes automatizados aprovados, zero falhas, teste visual do destaque/prévia/retorno, auditoria de dependências sem vulnerabilidades e comparação integral dos 128 arquivos de `src` no pacote ASAR.

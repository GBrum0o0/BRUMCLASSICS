# BRUMCLASSICS 1.70.6 — jogos não oficiais e horas recuperáveis

Esta atualização impede que um jogo adicionado manualmente perca sua identidade e seu tempo histórico quando desaparece ou precisa ser cadastrado outra vez.

## Identidade durável

- Cada jogo não oficial recebe um registro independente vinculado ao caminho normalizado do executável.
- Se o cartão desaparecer, a próxima abertura pode recuperar o mesmo ID, título, coleção, favorito, imagens e demais informações preservadas.
- Ao adicionar novamente o mesmo executável, o launcher reutiliza o cadastro anterior em vez de separar o jogo de suas atividades antigas.
- Uma remoção explícita continua sendo respeitada e não faz o cartão reaparecer sozinho.

## Recuperação das horas

- O launcher compara biblioteca, perfil principal e sessões concluídas da Atividade.
- A maior evidência válida é aplicada sem somar as três fontes, pois elas representam o mesmo tempo em locais diferentes.
- Tempos oficiais de lojas permanecem intactos e o acompanhamento local continua armazenado separadamente.
- O histórico inteiro é indexado uma única vez na abertura para manter a recuperação eficiente em bibliotecas grandes.

No caso identificado, o cartão tinha apenas 82 segundos, enquanto perfil e Atividade ainda guardavam 160.970 segundos (aproximadamente 44 h 43 min). A versão 1.70.6 restaura automaticamente o valor comprovado.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações de código ou protocolo nesta atualização exclusiva do launcher Windows.

Validação: 621 testes automatizados aprovados, zero falhas, auditoria de dependências sem vulnerabilidades e comparação integral dos 128 arquivos de `src` no pacote ASAR.

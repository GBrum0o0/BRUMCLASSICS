# BRUMCLASSICS 1.70.8 — Vitrine correta em Todos

Esta correção mantém o último jogo jogado na Vitrine ao alternar o filtro de instalação entre **Instalados** e **Todos**.

## O que acontecia

- A grade desenha inicialmente até 24 cartões para manter a biblioteca responsiva.
- A Vitrine também estava procurando o jogo recente somente dentro desse primeiro lote.
- Em **Instalados**, a lista curta continha o jogo correto; em **Todos**, um título além da posição 24 ficava fora da escolha e outro cartão assumia o destaque.

## Correção

- O limite de 24 continua sendo usado apenas para desenhar as capas.
- A Vitrine agora compara as datas de todos os resultados do filtro.
- O último jogo permanece correto em bibliotecas grandes e após alternar o status.
- Prévia temporária, retorno automático e separação por perfil permanecem funcionando.

O teste visual reproduziu uma biblioteca de 31 jogos com o mais recente fora dos 24 cartões iniciais e confirmou a escolha correta.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações de código ou protocolo nesta atualização exclusiva do launcher Windows.

Validação: 624 testes automatizados aprovados, zero falhas, cenário visual paginado aprovado, auditoria de dependências sem vulnerabilidades e comparação integral dos 128 arquivos de `src` no pacote ASAR.

# BRUMCLASSICS 1.70.0 — Perfil refinado e confiabilidade

A central do jogador agora funciona como a apresentação pessoal do perfil, sem retirar nenhuma ferramenta de gerenciamento já existente.

## Novo perfil

- Modal centralizado, cantos arredondados e identidade visual do BRUMCLASSICS.
- Foto e nome do jogador em destaque.
- Cartões para jogo com mais horas, jogo favorito e último jogo jogado.
- Os cartões abrem diretamente o perfil do jogo correspondente.
- Configurações ficam em uma segunda tela com botão de retorno funcional.
- Criação, exclusão, avatar, senha, cache e perfil portátil continuam disponíveis.
- O Jogador principal continua sendo configurado sobre os dados existentes, sem perder coleções ou conquistas manuais.

## Proteção e isolamento

- Perfis com senha voltam bloqueados depois de reiniciar o launcher.
- Enquanto bloqueado, o perfil não expõe nem aceita alterações em coleções, favoritos, conquistas ou preferências.
- Sessões locais e CLASSICS são creditadas ao jogador que iniciou o jogo, mesmo se o perfil ativo mudar antes do encerramento.
- Catálogos de conquistas carregados em segundo plano permanecem no perfil que iniciou a consulta e preservam marcações manuais feitas durante o carregamento.
- Atualizações completas da biblioteca chegam à interface já projetadas para o jogador ativo.

## Confiabilidade

- Desconectar uma loja durante uma sincronização não pode mais ser desfeito por uma resposta antiga.
- Uma entrada inválida da biblioteca é preservada para diagnóstico e isolada sem zerar os jogos válidos.
- Um portátil mais novo renova o executável permanente e o marcador de versão, mantendo o atalho oficial atualizado.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não precisam de novos pacotes para esta atualização exclusiva do launcher Windows.

Validação: 595 testes automatizados aprovados, zero falhas, verificação sintática, auditoria de dependências e inspeção visual em Electron.

# BRUMCLASSICS 1.70.1 — Perfis e sessões protegidos

Esta atualização corrige inconsistências encontradas na auditoria final do launcher Windows.

## Isolamento por jogador

- Quick Resume, Console no PC, sessões locais e recapitulações permanecem ligados ao perfil que iniciou a atividade.
- O status móvel mostra somente a sessão pertencente ao jogador ativo.
- Perfis bloqueados não expõem nem aceitam alterações em dados pessoais.
- Um perfil não pode ser apagado enquanto possuir jogo ou captura em andamento.
- Conquistas, horas locais e destaques pessoais deixam de atravessar perfis durante trocas de jogador.

## Sincronização e recuperação

- O pré-carregamento das conquistas acompanha o perfil selecionado, desbloqueado ou importado.
- Sincronizações descartam respostas antigas quando uma conta é conectada ou removida durante a consulta.
- Desconectar uma loja não pode mais ser desfeito por uma sincronização concorrente.
- O executável permanente recupera corretamente um marcador de versão ausente.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações nesta atualização exclusiva do launcher Windows.

Validação: 603 testes automatizados aprovados, zero falhas, verificação sintática, auditoria de dependências, testes visuais em Electron e inspeção integral do pacote ASAR.

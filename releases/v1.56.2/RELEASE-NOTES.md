# BRUMCLASSICS OFICIAL 1.56.2

## Correções de confiabilidade

- **CLASSICS:** imagens ISO agora são identificadas pelo `SYSTEM.CNF` interno. `BOOT2` confirma PS2 e `BOOT` confirma PS1, evitando classificações incorretas causadas pelo texto genérico “PLAYSTATION”.
- A biblioteca existente é revalidada uma única vez. Shadow of the Colossus, Black e Teenage Mutant Ninja Turtles foram confirmados como discos de PS2 nos testes com as mídias reais.
- **Steam:** servidores públicos de teste deixam de aparecer como jogos, inclusive quando chegam pela Família Steam. A regra é semântica e não usa uma lista manual de AppIDs.
- **Instalações:** uma solicitação restaurada que ficou aguardando a loja por mais de dez minutos, sem manifesto nem pasta criada, é encerrada com segurança. O download da loja não é cancelado nem removido.
- **Tela intermediária:** se o jogo ou a janela de preparação falhar, o estado é limpo e o launcher volta ao primeiro plano em vez de permanecer preso.

## Validação

- 493 testes automatizados aprovados.
- BRUMWORLD, tela intermediária, menu de contexto e fechamento do Perfil validados visualmente.
- Executável público confirmado como edição `distribution`, isolado do perfil pessoal.

## Preservação

Biblioteca, contas, coleções, saves, capas, anotações, configurações e perfis de controle são preservados.

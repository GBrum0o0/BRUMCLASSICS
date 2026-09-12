# BRUMCLASSICS 1.58.0

## Proteção e controle

- A Central de Notificações reúne conquistas, sessões, saves, instalações, atualizações e avisos do sistema.
- O histórico é persistente e separado por jogador, com contador de não lidas, leitura individual, leitura geral e limpeza.
- Os avisos abrem diretamente o jogo, a Atividade ou a área de atualização correspondente.
- Falhas de instalação e novas versões aparecem sem criar notificações duplicadas.

## Backup portátil completo

- O novo formato v2 pode incluir ou restaurar separadamente perfil e biblioteca, saves, artes e capas, estados CLASSICS e capturas.
- Cada arquivo tem caminho, tamanho e SHA-256 validados; arquivos duplicados, externos ou acima dos limites seguros são recusados.
- A restauração cria primeiro uma cópia de recuperação e preserva arquivos adicionais existentes.
- Backups de perfil criados pela versão 1.57.0 continuam compatíveis.
- Senhas, tokens e chaves de lojas ficam sempre excluídos.

## Recuperação do launcher

- Um diário local distingue encerramento normal de falha e leva o incidente anterior ao diagnóstico do sistema.
- Se o processo visual cair, o launcher registra a causa e tenta recarregar a interface uma única vez, evitando ciclos de reinício.

## Validação

- 515 testes automatizados aprovados.
- Verificação completa de sintaxe aprovada.
- Central de Notificações e cartão de backup seletivo verificados em 1280 × 900.
- Pacote confirmado como edição `official`, versão `1.58.0` e descrição Windows `BRUMCLASSICS`.

## Preservação

Contas, biblioteca, coleções, favoritos, anotações, saves, capas, controles e preferências existentes permanecem preservados. Android e iOS não receberam alterações nesta release.

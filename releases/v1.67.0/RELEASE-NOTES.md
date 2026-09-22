# BRUMCLASSICS 1.67.0 — Perfis portáteis

Esta atualização transforma a organização pessoal do launcher em perfis locais independentes, que podem acompanhar o jogador entre computadores sem transportar credenciais das lojas.

## Central de perfis

- Novo botão de perfil ao lado da engrenagem de Configurações.
- Criação de jogador com nome de usuário e senha opcional.
- Troca de perfil protegida por senha quando configurada.
- Coleções, favoritos, conquistas manuais, história completada, Quero jogar, tempo pessoal e preferências visuais ficam separados por jogador.

## Exportar e importar

- O perfil portátil usa a extensão `.brumprofile` e criptografia AES-256-GCM derivada da senha informada na exportação.
- Importar sempre cria um perfil independente; o perfil atual não é substituído.
- As associações usam a identidade oficial de loja e jogo. Depois de refazer as conexões no notebook ou em outro computador, os títulos reaparecem nas coleções previamente escolhidas.
- Jogos locais sem uma identidade oficial usam plataforma e título normalizados como alternativa.
- Tokens, chaves, sessões, senhas de lojas e caminhos específicos do computador não são exportados.

## Cache

- A central mostra o tamanho das miniaturas de capas e dos metadados temporários.
- A limpeza remove somente esses arquivos regeneráveis e preserva perfis, coleções, favoritos, conquistas, saves e configurações pessoais.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e inalterados nesta versão exclusiva do launcher Windows.

# BRUMCLASSICS 1.68.0 — Identidade do jogador

Esta atualização completa a central de perfis com primeiro acesso seguro, foto personalizada e controle explícito para apagar jogadores sem afetar os demais.

## Primeiro acesso sem perder dados

- **Jogador principal** passa a funcionar como perfil provisório até que a central seja acessada.
- Nome e senha são aplicados ao mesmo perfil, preservando coleções, favoritos, conquistas manuais e preferências já existentes.
- A central identifica visualmente o estado provisório e explica a preservação antes da configuração.

## Foto personalizada

- Cada jogador pode escolher PNG, JPEG, WebP ou BMP do próprio computador.
- A imagem é recortada ao centro, convertida para PNG e otimizada em 512 × 512.
- A foto aparece no botão do cabeçalho, no perfil ativo e na lista de jogadores.
- Remover a foto do perfil não apaga o arquivo original.
- A imagem acompanha a exportação criptografada e é restaurada ao importar o `.brumprofile`.

## Exclusão protegida

- Cada linha de jogador recebe uma opção **APAGAR**.
- Perfis com senha exigem confirmação da credencial antes da exclusão.
- Coleções, favoritos, conquistas manuais, preferências, atividade e demais dados pessoais são removidos somente do jogador escolhido.
- Os outros perfis permanecem intactos.
- Ao apagar o perfil principal, um novo **Jogador principal** provisório é criado automaticamente.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e inalterados nesta versão exclusiva do launcher Windows.

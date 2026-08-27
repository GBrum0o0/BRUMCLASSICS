# BRUMCLASSICS 1.40.1

## CLASSICS: capas na distribuição limpa

- Corrigida a dependência de chaves pessoais para buscar capas de CLASSICS.
- Adicionado fallback público Libretro `Named_Boxarts` por plataforma e nome.
- O índice de cada plataforma e as capas baixadas ficam no cache local.
- Adicionado fallback via CDN quando a API pública está limitada ou indisponível.
- Jogos adicionados manualmente e varreduras de CLASSICS disparam a busca de capas faltantes.
- Pedidos simultâneos de busca entram em fila, sem serem descartados.
- Capas personalizadas, coleções, favoritos, contas, saves e ROMs são preservados.
- Atualização registrada na BRUMNEWS e na linha do tempo.

## Como atualizar

Quem já usa o BRUMCLASSICS pode substituir somente o executável pela versão 1.40.1, sem apagar a pasta existente nem os dados locais. Depois, abra **CLASSICS** e use o botão **Atualizar** para procurar capas que ainda estejam ausentes.

Para uma instalação nova, use o pacote completo, que inclui o launcher, RetroArch limpo, a pasta `RETROGAMES` vazia e o APK móvel 0.6.0. O APK não mudou nesta versão.

A primeira busca de uma capa exige conexão com a internet. Catálogos públicos podem não possuir a arte de todos os jogos.

## Validação

- 332 testes automatizados aprovados.
- Busca validada em instalação limpa e sem credenciais pessoais.
- Cache offline validado após a primeira consulta.

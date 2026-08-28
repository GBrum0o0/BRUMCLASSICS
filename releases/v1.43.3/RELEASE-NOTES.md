# BRUMCLASSICS OFICIAL 1.43.3 — Reinício confiável

Esta é uma atualização corretiva do instalador interno.

## Se a atualização anterior fechou sem voltar

As versões 1.43.1 e 1.43.2 ainda executam o atualizador antigo. Publicar esta
correção não muda o código que já está instalado nelas. Se o reinício falhar,
feche o launcher, guarde uma cópia do executável atual e substitua-o pelo novo
portátil **mantendo o mesmo caminho e o mesmo nome de arquivo**. Abra-o novamente.
Isso mantém o vínculo local ao perfil. Não apague o AppData nem extraia por cima
de jogos, saves ou configurações. A partir da 1.43.3, os próximos reinícios usam
o mecanismo corrigido.

## Correções

- O helper de atualização é iniciado pelo serviço WMI do Windows, fora da árvore do Electron.
- Fechar a versão anterior não encerra mais o processo responsável pela substituição.
- O executável atualizado volta a abrir com a janela visível.
- O helper verifica a inicialização do novo processo antes de concluir a transação.

## Preservação

- O vínculo da instalação ao perfil continua obrigatório.
- Contas, biblioteca, coleções, favoritos, capas personalizadas, anotações, configurações e saves não são recriados nem limpos.
- O executável anterior continua guardado no histórico para recuperação.
- Tamanho e SHA-256 do pacote continuam validados antes da troca.

## Também incluído

- Tema Vermelho Arcade da versão 1.43.2.
- BRUMNEWS e linha do tempo atualizadas.
- BRUMCLASSICS MOVEL permanece na versão 0.8.0.

## Arquivos

- `BRUMCLASSICS-OFICIAL-1.43.3-portable.exe`: atualização portátil para Windows.
- `BRUMCLASSICS-OFICIAL-1.43.3-COMPLETO.zip`: pacote público limpo.
- `BRUMCLASSICS-MOVEL-0.8.0-debug.apk`: aplicativo Android de teste.
- `SHA256SUMS.txt`: hashes de verificação.

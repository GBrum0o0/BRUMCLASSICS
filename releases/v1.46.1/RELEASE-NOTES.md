# BRUMCLASSICS OFICIAL 1.46.1 — Menu contextual e MÓVEL 0.11

Esta versão corrige o menu do botão direito na biblioteca e publica as melhorias de sincronização e segurança do BRUMCLASSICS MOVEL 0.11.0.

## Menu contextual corrigido

- O botão direito abre novamente as opções do jogo.
- Consultar opções não seleciona, remove nem substitui jogos selecionados.
- Ações em lote aparecem somente ao abrir o menu sobre um integrante da seleção múltipla.
- Clique esquerdo, botão Menu e `Shift + F10` preservam seus comportamentos próprios.
- Testes automatizados impedem que o evento secundário volte a passar pela seleção normal.

## BRUMCLASSICS MOVEL 0.11.0

- A tela Início destaca o último jogo realmente jogado.
- Novas prateleiras de **Favoritos** e **Quero jogar** acompanham **Minha jornada**.
- Preferências ficam na fila offline e sincronizam ao reencontrar o launcher.
- O modo demonstração é identificado claramente.
- A ponte local usa HTTPS com certificado fixado pelo QR Code.
- O APK mantém uma assinatura estável compatível com a instalação anterior.

Depois de instalar o APK 0.11.0, faça um novo pareamento único para ativar a conexão HTTPS. A biblioteca, as capas, as anotações, os momentos e as preferências armazenadas no celular permanecem preservados.

## Launcher e sincronização

- A biblioteca Steam aparece antes da atualização de conquistas, que ocorre por lotes em segundo plano.
- Falhas na leitura do armazenamento protegido não são convertidas em contas desconectadas.
- Logs de sincronização possuem limite de tamanho e rotação automática.
- BRUMNEWS e a linha do tempo registram as versões 1.46.0 e 1.46.1.

Nenhum cache, conta, biblioteca, coleção, favorito, capa personalizada, anotação, save ou caminho pessoal é apagado ou recriado.

## Arquivos

- `BRUMCLASSICS OFICIAL.exe` — executável de nome fixo usado pelo atualizador e pela barra de tarefas.
- `BRUMCLASSICS-OFICIAL-1.46.1-portable.exe` — cópia versionada compatível.
- `BRUMCLASSICS-OFICIAL-1.46.1-COMPLETO.zip` — pacote público limpo com RetroArch, RETROGAMES vazia e APK.
- `BRUMCLASSICS-MOVEL-0.11.0.apk` — aplicativo Android complementar.
- `SHA256SUMS.txt` — hashes SHA-256 dos arquivos publicados.

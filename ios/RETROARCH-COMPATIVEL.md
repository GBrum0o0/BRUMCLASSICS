# RetroArch compatível com o BRUMCLASSICS

O BRUMCLASSICS MÓVEL 0.7.3 verifica as ROMs da pasta autorizada. No primeiro uso de cada arquivo, **CLASSICS Everywhere** cria uma cópia temporária legível e abre a folha de compartilhamento. Ao concluir a entrega, grava o vínculo local. Nos próximos toques, formatos reconhecidos abrem diretamente a ROM já copiada em `RetroArch/downloads`, sem importar novamente. A ROM original é preservada.

## Versão necessária

A versão estável RetroArch 1.22.2 ainda não contém os comandos de integração. Use o build noturno oficial da Libretro que contenha:

- `retroarch://library?scheme=brumclassics`, para devolver a biblioteca;
- `retroarch://game/<titleId>`, para abrir um jogo da playlist pelo nome de arquivo exato.

Build validado em 4 de setembro de 2026:

- versão interna: `1.20260904.1800`;
- Bundle ID: `com.libretro.RetroArchiOS11`;
- iOS mínimo: 12.0;
- SHA-256: `7DB367256AE08C5F7A13703A2B190D56B265BD9926E71A227CAE5B672D9FA755`;
- fonte e licença GPLv3: <https://github.com/libretro/RetroArch>;
- build oficial noturno: <https://buildbot.libretro.com/nightly/apple/ios-arm64/RetroArch.ipa>.

O binário local foi testado como ZIP/IPA e contém os marcadores de consulta da biblioteca, retorno por callback e abertura por `titleId`. O RetroArch continua sendo um aplicativo separado e deve ser assinado/instalado conforme as regras do iOS.

## Uso

1. Instale o RetroArch no iPhone. A versão da App Store recebe a ROM normalmente; use a edição compatível abaixo se quiser consulta da biblioteca e abertura direta pelo cartão.
2. Em **Perfil → Configurações do app → CLASSICS**, toque **Selecionar pasta de ROMs** e autorize Downloads, iCloud Drive ou outra pasta disponível no app Arquivos.
3. No BRUMCLASSICS, abra **CLASSICS Everywhere** e toque no jogo. Na primeira vez, escolha **RetroArch** na folha de compartilhamento.
4. Aguarde o RetroArch receber e importar o arquivo. Se necessário, associe o núcleo correto dentro do emulador.
5. Volte ao BRUMCLASSICS. O cartão passa a indicar **Jogar · RetroArch** automaticamente.
6. Os próximos toques abrem a cópia existente no RetroArch diretamente, sem nova importação. A confirmação de biblioteca continua opcional e exclusiva da edição compatível.
7. Para trocar a pasta de origem, volte a **Perfil → Configurações do app → CLASSICS**.

## Limites do iOS

Dois aplicativos não compartilham automaticamente permissões de pasta. Enviar somente o caminho da ROM fazia o RetroArch exibir “this file couldn't be opened because you don't have permission to view”. Manter apenas a autorização da pasta aberta também pode falhar com provedores de documentos. Por isso, a 0.7.2 cria primeiro uma cópia temporária dentro do sandbox do BRUMCLASSICS e compartilha essa cópia legível. O RetroArch cria a própria cópia; a origem escolhida pelo usuário permanece intacta.

Para uso fora de casa, a ROM e a cópia importada precisam estar no telefone. Formatos como ISO, CHD, ZIP, CUE, M3U, GDI, RVZ e WAD podem exigir seleção manual do núcleo, BIOS ou organização da playlist dentro do RetroArch.

O aplicativo não escolhe jogos por correspondência aproximada. Primeiro tenta o vínculo já confirmado; sem ele, aceita somente um título normalizado com correspondência única. Arquivos repetidos com o mesmo nome são omitidos para impedir que o jogo errado seja iniciado.

## Capas e títulos

Os nomes sincronizados do PC e suas capas têm prioridade. Sem capa correspondente, o app consulta o índice público de [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails) da plataforma indicada pela extensão. Limpa números de release, tags de região e grupo e busca um título equivalente; a imagem encontrada e o índice ficam no armazenamento persistente do iPhone. Internet é necessária somente para a primeira busca ou atualização. Formatos ambíguos ou nomes sem correspondência podem continuar sem capa. Uma capa encontrada não configura o núcleo, a conta RetroAchievements ou o vínculo de horas.

Validação: os testes cobrem a limpeza do título, correspondência de capas, persistência, biblioteca e empacotamento. A entrega entre aplicativos e a execução do núcleo precisam de teste no iPhone real com o RetroArch compatível e eventuais BIOS necessárias.

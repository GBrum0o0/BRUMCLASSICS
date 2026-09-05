# RetroArch compatível com o BRUMCLASSICS

O BRUMCLASSICS MÓVEL 0.7.0 verifica as ROMs da pasta autorizada. Em **CLASSICS Everywhere**, GBA, GB/GBC, NES, SNES, N64, Nintendo DS, Mega Drive, Master System/Game Gear e PC Engine abrem pelo caminho real e pelo núcleo correspondente. A biblioteca do RetroArch continua sendo usada quando já existe uma identidade de playlist confirmada.

## Versão necessária

A versão estável RetroArch 1.22.2 ainda não contém os comandos de integração. Use o build noturno oficial da Libretro que contenha:

- `retroarch://library?scheme=brumclassics`, para devolver a biblioteca;
- `retroarch://topshelf?path=...&core_path=...`, para abrir o caminho real com o núcleo escolhido;
- `retroarch://game/<titleId>`, para abrir um jogo da playlist pelo nome de arquivo exato.

Build validado em 4 de setembro de 2026:

- versão interna: `1.20260904.1800`;
- Bundle ID: `com.libretro.RetroArchiOS11`;
- iOS mínimo: 12.0;
- SHA-256: `7DB367256AE08C5F7A13703A2B190D56B265BD9926E71A227CAE5B672D9FA755`;
- fonte e licença GPLv3: <https://github.com/libretro/RetroArch>;
- build oficial noturno: <https://buildbot.libretro.com/nightly/apple/ios-arm64/RetroArch.ipa>.

O binário local foi testado como ZIP/IPA e contém os marcadores de consulta da biblioteca, retorno por callback, `titleId` e abertura direta. O RetroArch continua sendo um aplicativo separado e deve ser assinado/instalado conforme as regras do iOS.

## Uso

1. Instale o RetroArch compatível no iPhone.
2. Em **Perfil → Configurações do app → CLASSICS**, toque **Selecionar pasta do RetroArch** e autorize uma pasta de ROMs dentro de **No Meu iPhone → RetroArch**. O iOS não permite conceder essa permissão silenciosamente.
3. O arquivo da ROM precisa existir uma única vez nessa pasta acessível. O BRUMCLASSICS não baixa jogos e uma capa sincronizada não contém a ROM.
4. Para extensões que identificam a plataforma, não é preciso criar uma playlist: o BRUMCLASSICS envia o caminho real e o núcleo. Somente formatos ambíguos precisam ser organizados no RetroArch primeiro.
5. No BRUMCLASSICS, abra **CLASSICS Everywhere**. A lista contém somente os arquivos detectados na pasta autorizada; toque na capa para jogar.
6. Para trocar a origem no futuro, volte a **Perfil → Configurações do app → CLASSICS**. As próximas aberturas verificam automaticamente a pasta lembrada.

## Limites do iOS

Dois aplicativos não podem ler silenciosamente as pastas privadas um do outro. Para a abertura direta sem cópia, escolha preferencialmente a pasta de ROMs exposta pelo próprio RetroArch em **No Meu iPhone → RetroArch**. Pastas de outro provedor podem permitir a leitura pelo BRUMCLASSICS, mas continuar inacessíveis ao processo do RetroArch. Para uso fora de casa, a ROM precisa estar no telefone previamente.

Formatos cuja extensão identifica a plataforma recebem um núcleo conhecido do pacote validado. ISO, CHD, ZIP, CUE, M3U, GDI, RVZ e WAD são ambíguos e não recebem um núcleo por adivinhação; organize-os numa playlist do RetroArch e use **Atualizar vínculo**.

O aplicativo não escolhe jogos por correspondência aproximada. Primeiro tenta o vínculo já confirmado; sem ele, aceita somente um título normalizado com correspondência única. Arquivos repetidos com o mesmo nome são omitidos para impedir que o jogo errado seja iniciado.

## Capas e títulos

Os nomes sincronizados do PC e suas capas têm prioridade. Sem capa correspondente, o app consulta o índice público de [libretro-thumbnails](https://github.com/libretro-thumbnails/libretro-thumbnails) da plataforma indicada pela extensão. Limpa números de release, tags de região e grupo e busca um título equivalente; a imagem encontrada e o índice ficam no armazenamento persistente do iPhone. Internet é necessária somente para a primeira busca ou atualização. Formatos ambíguos ou nomes sem correspondência podem continuar sem capa. Uma capa encontrada não configura o núcleo, a conta RetroAchievements ou o vínculo de horas.

Validação: as rotas foram conferidas no código do RetroArch e os testes do app cobrem seus parâmetros. O iOS não informa ao BRUMCLASSICS se o núcleo conseguiu executar a ROM após aceitar a URL; o lançamento completo exige teste no aparelho com o RetroArch compatível, pasta acessível e eventuais BIOS necessárias.

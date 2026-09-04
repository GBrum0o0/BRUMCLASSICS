# RetroArch compatível com o BRUMCLASSICS

O BRUMCLASSICS MÓVEL 0.6.0 consulta a biblioteca real do RetroArch e abre um jogo pela identidade exata retornada pelo próprio emulador. Isso remove a antiga cópia da ROM dentro do catálogo do BRUMCLASSICS e a confirmação manual “já importei”.

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

O binário local foi testado como ZIP/IPA e contém os marcadores de consulta da biblioteca, retorno por callback, `titleId` e abertura direta. O RetroArch continua sendo um aplicativo separado e deve ser assinado/instalado conforme as regras do iOS.

## Uso

1. Instale o RetroArch compatível no iPhone.
2. O arquivo da ROM precisa existir uma única vez no armazenamento acessível ao RetroArch. O BRUMCLASSICS não baixa jogos e uma capa sincronizada não contém a ROM.
3. No RetroArch, inclua legalmente sua ROM na playlist e confirme um núcleo compatível. Isso é a preparação inicial do arquivo no aparelho, não uma segunda biblioteca no BRUMCLASSICS.
4. No BRUMCLASSICS, abra **CLASSICS in every everywhere**. Na primeira abertura ou em **Atualizar biblioteca do RetroArch**, o app alterna para o emulador; ele devolve a lista automaticamente.
5. Jogos confirmados aparecem como jogáveis. Basta tocar na capa para abrir o título exato no RetroArch.
6. Itens presentes somente na biblioteca sincronizada do PC aparecem abaixo como **ROM não confirmada no iPhone**. Eles não recebem um botão falso de execução.

## Limites do iOS

Dois aplicativos não podem ler silenciosamente as pastas privadas um do outro. Portanto, BRUMCLASSICS pode sincronizar nomes, capas, horas e conquistas, mas não pode transformar esses metadados em um jogo executável. Para uso fora de casa, a ROM precisa estar no telefone previamente.

O aplicativo não escolhe jogos por correspondência aproximada. Primeiro tenta o vínculo já confirmado; sem ele, aceita somente um título normalizado com correspondência única. Arquivos repetidos com o mesmo nome são omitidos para impedir que o jogo errado seja iniciado.

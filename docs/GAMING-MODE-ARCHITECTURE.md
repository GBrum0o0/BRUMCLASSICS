# BRUM CLASSICS Gaming Mode — fundação técnica

Esta arquitetura começa pelo contrato comum entre iOS, Android e, futuramente, o BRUM Launcher. A interface continua simples — escolher um jogo e jogar — enquanto a origem, o core e o transporte ficam ocultos atrás de uma sessão explícita.

## Identidade canônica

Cada ROM recebe um identificador independente de nome, pasta ou provedor de arquivos:

`classic:<systemID>:sha256:<hash do conteúdo>`

O sistema é identificado primeiro pelo cabeçalho do arquivo. A extensão só é usada como contingência para formatos cujo cabeçalho ainda não foi implementado. O hash é calculado sob demanda e persistido; varreduras comuns da biblioteca não releem ROMs inteiras.

## Registro de cores

Um core declara ID estável, versão, licença e sistemas suportados. A primeira implementação integrada é `mgba`, sob MPL-2.0, para GB, GBC e GBA. Android mantém os demais formatos no RetroArch enquanto o runtime integrado é preparado.

## Sessão de emulação

Antes da execução, a camada móvel cria um descritor com:

- ROM autorizada ou cópia temporária protegida;
- ID canônico;
- sistema detectado;
- core escolhido;
- nome antigo do save, usado exclusivamente para migração.

O runtime nunca escolhe save ou core apenas pelo nome da ROM.

## Saves

O save integrado fica em `IntegratedEmulator/Saves/<system>/<sha256>.srm`. Ao lado há um manifesto versionado com jogo, core, geração, hash do payload, tamanho, dispositivo e data. Uma geração só avança quando o conteúdo muda.

Na primeira execução, se existir o save legado baseado em nome, ele é copiado para o novo endereço. O arquivo anterior não é removido. Esse comportamento permite reversão e evita perda silenciosa.

## Próximas etapas

O runtime Libretro integrado já está presente no Android para GB, GBC e GBA. Ele usa o mesmo ID canônico, core mGBA fixado e manifesto de save do iOS.

1. Slots manuais e estados rápidos separados do save de bateria.
2. Sincronização de saves com comparação de geração e resolução explícita de conflitos.
3. Sessão remota do PC com autenticação por dispositivo e transporte criptografado.
4. RetroAchievements ligado ao ID do conteúdo, sem depender do nome do arquivo.

ROMs, BIOS e conteúdo protegido não fazem parte do aplicativo. Cada core só entra no produto depois de revisão técnica e de licença.

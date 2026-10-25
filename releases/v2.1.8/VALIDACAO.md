# Validação — Launcher PC 2.1.8 experimental

## Escopo autorizado

O usuário autorizou expressamente publicar para testar e continuar corrigindo depois. Não se considera o suporte dos 32 concluído. Preservado o Launcher publicado 2.1.7 e importado somente o diff `native/on-brum` de `64cbc2d` até `69c02e0126947ee6ea26392da1ca77ca4d5f7ff7`. O host antigo, serviço RetroArch, restore ampliado e caminhos libretro da raiz não foram copiados.

Fonte interna limpa: `d1f8fc136cc92bd896b88eaf41afeeba14fcd7a6`. Árvore Git: `50dad794fd780ab62ca567d914427700f97a8ceb`.

## Evidências de integração

- Host compilado /W4 /WX; testes nativos de controles e conversor de vídeo aprovados.
- Build completa do núcleo, diagnósticos e observador de sessão concluída com exit 0.
- Suíte nativa autoral: 237 aprovados, gameplayReady=false. Inclui um caso MMC3 adicional; o teste JavaScript foi atualizado de 236 para 237 para acompanhar esse caso, não para dispensar falhas.
- Suíte completa do Launcher: 836 testes, 835 aprovados, nenhuma falha, um ignorado por exigir DLL libretro real opcional. Sintaxe: exit 0.
- Nove testes de host: GB/GBC com persistência/reabertura em perfis isolados, descrição dos módulos, falha antes do primeiro frame, NES sintético e Start, captura BMP, recusa de sobrescrita e apresentação em janela oculta real.
- UI Electron: 32 módulos experimentais, ação autoral exclusiva, zero consulta a estado externo no lançamento e duas capturas.
- ROMs pessoais foram somente lidas; comparação SHA antes/depois confirmou preservação. Todos os saves dessa avaliação foram para pasta temporária, fora do perfil e do Vault.

## Jogos no host integrado

Após 600 frames, com o host integrado ao Launcher atual:

| Sistema e jogo | Saída observada |
|---|---|
| GB / Pokémon Red | Frame com 4 cores e PCM não zerado; não equivale a certificação do jogo inteiro |
| NES / Super Mario Bros. 3 | Frame com 3 cores e PCM não zerado; áudio possui defeitos conhecidos, gameplay não certificado |
| GBA / Pokémon FireRed | Frame totalmente branco; PCM zerado |
| SNES / Super Mario World | Frame totalmente preto; PCM zerado |
| N64 / Super Mario 64 | Frame totalmente preto; PCM zerado |
| DS / Super Mario 64 DS | Frame totalmente preto; PCM zerado |

Os seis processos terminaram com código 0 e confirmaram o container de save temporário. Isso demonstra execução do host e contrato de persistência, não funcionamento dos jogos. A contagem de cores não prova correção gráfica. O SNES ainda gera exclusivamente zeros na APU.

## Revisão independente e limites aceitos

Nenhum problema Critical/Important de segurança, persistência ou integração foi encontrado pelo revisor no escopo da build de testes. Ele verificou a igualdade exata do diff nativo com o snapshot, a manutenção dos formatos/tamanhos de saves carregados, o isolamento, a normalização de identidade/revisão/CRC, a recusa de fallback e7 testes de política/marca.

Defeitos conhecidos mantidos para correção posterior: NES força volume8 quando o jogo pede0 e determinadas escritas habilitam canais; o teste MMC3 descarta o byte lido, sem validar o banco. Não se usa som presente nem esse teste como prova de fidelidade.

A decisão foi preservar o host seguro2.1.7, não copiar o runner antigo nem chamar emuladores externos. Custo: recursos específicos da CLI alternativa não entram nesta publicação. A aceitação de cores incompletos permite bugs de emulação, não redução das garantias de integridade dos arquivos originais.

Não certificados pelo revisor: compatibilidade comercial dos32 sistemas, fidelidade CPU/PPU/APU, gameplay prolongado, controles físicos, pacote final e entrega pelo atualizador. A conferência de empacotamento e entrega é registrada separadamente após executada pelo coordenador.

## Pacote final

- Build Windows x64 de distribuição concluída com exit 0, árvore interna limpa, versão 2.1.8 e estágio experimental.
- ASAR: 188 fontes conferidas contra a árvore limpa; QR SVG/PNG, ZIP, Three.js e WebSocket executados em cópia isolada, sem poder buscar node_modules no desenvolvimento.
- Serviço JavaScript e host empacotados abriram uma sessão autoral e confirmaram save sintético isolado. Módulos registrados: 32; gameplayCertified=false.
- Entrada principal chegou a app-ready em perfil temporário, com página do jogo e Steam preservadas. O wrapper de teste registrou o aviso BigInt já observado nas versões anteriores; o teste separado com executável regular passou em primeiro acesso, reabertura sem repetição, novo download no mesmo caminho e preservação do perfil. Não representa instalação pessoal validada.
- ASAR e host extraídos diretamente do portátil têm hashes idênticos aos outputs verificados de produção.
- Portátil: 394334105 bytes; SHA-256 `6d0384a68fa85cbfde841f2179772ace0b6732bba65d0565c70147960f525176`.
- ASAR: SHA-256 `a089f51ef1002af82871f707c882e88b370aa126951b4ae9573165b1f9a80f8c`.
- Host: SHA-256 `dbb9a7769e4e177e1ac15ce73d9400577aa72ae2db37cd479fefeda3ddcc9730`.

## Publicação e atualizador ao vivo

Publicada como Latest oficial, não prerelease, em `v2.1.8`, commit público `bccadc4528b807ffae0adec704cfe551306568c7`. Executável, notas e manifesto tiveram tamanho e SHA-256 confirmados pela API do GitHub antes da publicação. O estágio experimental está explícito no título, nas notas e no Launcher.

O serviço real de atualização, simulando instalação 2.1.7 em perfil temporário, encontrou 2.1.8 e baixou integralmente 394334105 bytes. Estado final `ready / 100%`; SHA-256 `6d0384a68fa85cbfde841f2179772ace0b6732bba65d0565c70147960f525176` confirmado. A seleção da ponte 2.1.0-beta.3 também encontrou a versão nova.

O arquivo de controle do perfil temporário permaneceu intacto. Nenhuma instalação ou reinicialização foi executada sobre o perfil pessoal; a atualização real depende da confirmação explícita do usuário no Launcher.

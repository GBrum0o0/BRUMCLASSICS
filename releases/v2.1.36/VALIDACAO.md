# BRUMCLASSICS OFICIAL 2.1.36 — geração e validação

Fonte privado do Launcher: `20eb907feecf6f5467e031001035eed3e74ca8a0`. Fonte mobile: `0066dba4d797553261edc1098ad053e1b545728d`. Esta atualização implementa as tarefas 1, 2, 3, 5, 6 e 7; não adiciona os novos slots ou multijogador das tarefas 4 e 8.

## PC

- Executável portátil gerado com Electron 43.4.0 / electron-builder 26.15.3, versão 2.1.36 oficial.
- 682.474.145 bytes; SHA-256 `def795ee30409bb9dd7c36b3941bb8f4519aff0201353a7905a80121bc85b690`.
- Host, núcleos e ponte iOS reutilizados da versão anterior, sem alteração de código nativo. Host SHA-256 `3c908566be17d90918966168e211c5c22b74186d1954e371f0dfe21417a5d71f`. Não se alega recompilação do host nesta etapa.
- Oito testes focados de Drive/navegação aprovados. Sintaxe JS e diff-check aprovados. Não houve nova bateria de emulação.
- Revisão independente aprovou paridade dos 208 arquivos da interface e 241 fontes do host no pacote; licenças; manifesto com 3.047 entradas/33 sistemas/27 motores; amostras de integridade; hash do host e do portátil.
- Fonte correspondente do host: `BRUM-CORE-PC-HOST-SOURCE-2.1.36.zip`, SHA-256 `c33c99013bd25823e91bcc4b3ba123858c23ac1e94ec6d8ec2642d3730dd34a7`. CRC e paridade dos 243 arquivos do ZIP aprovados independentemente. A interface Electron privada não está no arquivo de fontes público.
- A política de conteúdo do popup foi ajustada para permitir somente o caminho necessário às imagens Pokémon, mantendo a restrição adicional de IDs/URLs no JavaScript. O pacote final foi regenerado com essa correção; a primeira geração foi descartada.

## Mobile

- iOS 0.27.0 / build 60: [build e publicação](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/45192531555).
- Android 0.36.0 / código 48: [build](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/45192531512).
- As publicações dependem do resultado efetivo desses jobs. Um job em fila não comprova compilação nem uma IPA disponível.
- Mesmos identificadores de aplicativo e mecanismos de atualização; no Android, a assinatura deve corresponder ao certificado das versões anteriores. iOS mantém publicação sem substituir Latest do PC e atualização da fonte SideStore após validar a IPA.

## Limites

Primeiro carregamento de cada imagem exige internet; as imagens são guardadas em cache. Não é distribuído um pacote de sprites Pokémon, nem atribuída autoria BRUM às imagens.

Drive usa links públicos compartilhados e leitura das páginas públicas, sujeita ao formato, disponibilidade e cotas do Google. Testou-se listagem pública de exemplo e downloads sintéticos isolados; não houve acesso ao Drive pessoal ou download de jogos comerciais do usuário.

As checagens desta etapa não certificam gameplay, captura real de Pokémon, operação em aparelho físico ou todos os 33 sistemas. O detector permanece piloto FireRed BPRE. ROMs, BIOS, saves, perfis e dados existentes não foram alterados nos testes.

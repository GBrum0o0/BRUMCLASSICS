# Validação — Launcher PC 2.1.7

## Procedência e integração

- Fonte interna limpa: `51aca5a35d43f5357022ec5bf74ba72d7667fac6`.
- Árvore Git: `f67511544665d326faa0ef6f7ae75d44f62caf30`.
- Antigravity revisado até `64cbc2d7f2f4f8a3ce61a2ccd81771504ccf7ae6`. A pasta original foi preservada. Fontes dos módulos coincidem com esse snapshot; o contrato foi documentado e o host foi integrado sobre a versão segura 2.1.6.
- Foram portados vídeo, foco e captura, não o antigo runner com CLI RetroArch-compatible/dual-save: copiá-lo inteiro descartaria controles corrigidos e proteção de saves da 2.1.6.

## Testes executados

- Suíte completa: 836 testes, 835 aprovados, zero falhas, um ignorado por exigir core libretro real opcional, fora do caminho autoral.
- Núcleo C++: 236/236, mantendo `gameplayReady=false`. Compilação de núcleo, diagnósticos e observador de sessão concluída.
- Host compilado com /W4 /WX. Adaptadores de controles e conversor de vídeo executados durante a build.
- Conversão real de RGBA/BGRA/XRGB8888, RGB565 e RGB555; pitch em bytes com preenchimento; rejeição de dimensões/pitch/formato inválidos.
- Nove testes de integração/captura: saves GB/GBC isolados, módulos registrados, erro antes do primeiro frame, execução NES, Start NES, BMP decodificável, ROM intacta, recusa de sobrescrita e desenho em janela oculta real.
- Os três testes de captura falharam antes da implementação e passaram depois. A primeira build dos novos testes nativos detectou o stride NES não corrigido; o snapshot final corrigiu NES e GBC.
- Sintaxe: exit 0. Electron visual: 32 módulos, somente ação autoral, zero consulta de estado externo, duas capturas.

## Revisão independente e limites

Nenhum apontamento Critical/Important. O revisor repetiu captura 3/3, conversor nativo e diff check. Pontos menores de cobertura ainda pendentes: falha GDI forçada, redimensionamento sob estresse, buffers deliberadamente desalinhados e composição de telas com larguras diferentes. O consumidor usa memcpy para leituras não alinhadas e mantém as validações e os limites de composição, mas esses cenários não foram certificados por esta revisão.

Compatibilidade comercial, gameplay prolongado e controles físicos continuam não certificados. A publicação permanece experimental, sem anúncio de suporte completo. Pacote e entrega pelo atualizador são verificados separadamente abaixo; nenhuma instalação é executada sobre perfil pessoal.

## Pacote de produção

- Build de distribuição Windows x64 concluída com exit 0, em fonte limpa. Versão do portátil: 2.1.7.
- ASAR: 188 fontes conferidas contra a árvore limpa. Dependências executadas em cópia isolada, sem node_modules do desenvolvimento: QR SVG/PNG, ZIP, Three.js e WebSocket.
- Serviço JavaScript empacotado iniciou o host empacotado, encontrou os 32 módulos e confirmou um save sintético isolado; ROM fixture preservada.
- Inicialização principal chegou a app-ready em perfil temporário, mantendo detalhes do jogo e Steam. Como na versão anterior, o wrapper de teste registrou um aviso BigInt no primeiro acesso; o teste separado com identidade de executável regular passou em abertura inicial, reabertura, novo download no mesmo caminho e preservação do perfil. Isso não equivale à instalação no perfil pessoal.
- ASAR e host extraídos diretamente do portátil coincidem com os arquivos de produção verificados.
- Portátil: 394304008 bytes; SHA-256 `4938af33fdc4044683f847d1cd958c2c548a4c92d6fc61a90719408b7cd5afb7`.
- ASAR: SHA-256 `f90e56a41f16b3fecef1e66c9895d78f59c9dd4593058974e293d11290965ef7`.
- Host: SHA-256 `e764ae29e3512abec0221ee68e8395f3497eaf4d27214e90d2e03531d4a24292`.

## Publicação e download real

Publicada como Latest oficial, não prerelease, em `v2.1.7`, commit público `6e4f7a09ae942f3416d2a0938d14c9dd083f558a`. Executável, notas e manifesto tiveram tamanho e SHA-256 confirmados pela API do GitHub antes da publicação.

O serviço de atualização real do Launcher, simulando instalação 2.1.6 em pasta temporária, encontrou 2.1.7 e baixou integralmente 394304008 bytes. Estado final `ready / 100%`; SHA-256 `4938af33fdc4044683f847d1cd958c2c548a4c92d6fc61a90719408b7cd5afb7` confirmado. A seleção da ponte 2.1.0-beta.3 também encontrou a atualização.

O perfil temporário permaneceu intacto. Nenhuma instalação/reinicialização foi executada sobre o perfil pessoal: essa etapa depende da confirmação explícita do usuário pelo Launcher. A última conferência do Antigravity manteve HEAD em `64cbc2d`; a pasta de trabalho original não foi alterada.

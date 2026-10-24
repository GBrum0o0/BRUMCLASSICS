# Validação — Launcher PC 2.1.5

## Origem da build

- Fonte interna limpa: `b2645eb3882080adbcaf84d08b367d956b87d679`.
- Árvore Git: `2f9a2b6915bfbc8a5ea111a894887efe2a765404`.
- Versão: `2.1.5`; edição pública técnica `distribution`, marca BRUMCLASSICS OFICIAL, estágio Beta apenas como codinome.
- Compilação Windows x64 de produção e empacotamento portátil concluídos. Os arquivos de desenvolvimento não commitados da engine não foram incorporados.

## Testes realizados

- Suíte integral na árvore limpa: **800 aprovados, 0 falhas, 17 ignorados**, de 817 testes. Concorrência limitada a duas tarefas apenas no executor de testes, não no produto.
- Os 17 casos ignorados exigem DLL de core real ou artefatos/instrumentação de desenvolvimento da engine autoral. Não foram usados para anunciar compatibilidade ou gameplay da M.U.R.B.
- Cofre visual: galeria inicialmente vazia, primeiro scan/import seletivo, associação FireRed com categoria antiga, versões divergentes preservadas, escolha ativa separada, cancelamento/confirmação de exclusão e original intacto. Layouts 1440×900 e 1024×768.
- Página do jogo: capa não instala; ação explícita instala uma única vez; notas persistem; consulta lenta de backups não bloqueia ações; troca de perfil fecha/limpa dados anteriores. Layout compacto sem rolagem horizontal.
- Steam: duas contas persistidas no armazenamento protegido, união de títulos exclusivos e compartilhados, conquistas consultadas pela conta selecionada, falha parcial preservando propriedade conhecida, estatísticas não transferidas entre proprietários, desconexão e limpeza do token familiar.
- Roteamento: preparação, confirmação de instalação e abertura verificam a conta armazenada. Confirmação humana sem a sessão correspondente continua bloqueada. A interface oferece conta adicional.
- Intro real no Electron: 1920×1080, 24 FPS, 110 quadros decodificados, 4,583333 segundos, término automático único; áudio AAC comprimido preservado byte a byte. Original não alterado.
- ASAR: **187 arquivos de fonte** conferidos contra a árvore limpa. Dependências executadas a partir de cópia isolada, sem poder recorrer ao node_modules dos fontes: QR SVG/PNG, ZIP, Three.js e WebSocket.
- Entrada principal empacotada chegou a `app-ready` em perfil temporário. Primeiro acesso foi testado separadamente com identidade de executável regular: exibição inicial, reabertura sem repetição, novo download e preservação do perfil. O teste de entrada principal por wrapper não equivale à instalação do executável no perfil pessoal.
- Conteúdo extraído do portátil: ASAR e host nativo idênticos aos arquivos de produção verificados.

## Revisão e correções

Uma revisão independente encontrou quatro problemas importantes: dados do detalhe após troca de perfil; classificação arquivada de Classics antigos; perda de propriedade adicional em falha Steam; sinopse descartada no mapeamento. Cada caso foi reproduzido com teste em falha, corrigido e validado antes da suíte final. Nenhum apontamento menor foi adiado.

A primeira tentativa de empacotamento reutilizando uma junction deixou uma dependência transitiva fora do ASAR. Esse pacote foi rejeitado. A build final usa instalação local independente pelo lockfile e passou nos testes isolados de dependências.

Uma execução concorrente anterior encontrou EPERM transitório ao renomear um arquivo de fixture temporária do teste Ubisoft. O caso isolado passou, e a suíte final completa passou; não houve mudança nas permissões dos arquivos do usuário.

## Decisões e limites

## Publicação e atualizador ao vivo

Publicada como Latest oficial, não prerelease, em `v2.1.5`. O mesmo serviço de atualização do Launcher, simulando a versão instalada 2.1.4 em pasta temporária, consultou o GitHub, encontrou 2.1.5 e baixou integralmente **393.785.066 bytes**, chegando ao estado **ready / 100%**. SHA-256 conferido: `d05240a4c893329c7bda0ff284a0c3e1899dab3bd34a52f082d1007e47cfd82f`.

A seleção também confirmou compatibilidade da ponte 2.1.0-beta.3. Nenhuma instalação/reinicialização foi executada sobre o perfil pessoal; o arquivo de controle do perfil temporário permaneceu intacto. A troca real dos executáveis no computador do usuário continua sendo uma ação explícita pelo botão Reiniciar e atualizar.

### Limites de uso

1. Um cartão por AppID preserva IDs, notas e organização. A conta principal tem preferência nos jogos compartilhados; a página identifica qual conta fornece as estatísticas. Não há soma de conquistas ou horas entre contas. Uma visualização com cartões separados por conta não foi adicionada.
2. A troca Steam é assistida no cliente oficial, com nova conferência da sessão. Não foi implementada autenticação silenciosa, alteração de arquivos de login ou cópia de tokens. Login/Steam Guard de duas contas reais continuam dependentes do usuário.
3. O upscale melhora a apresentação, não recria detalhes ausentes. O foco e a experiência audiovisual durante a abertura de jogos reais ainda dependem da validação no computador do usuário.
4. Publicação e atualização são verificações separadas da maturidade da engine. Esta versão não libera gameplay autoral nem novos consoles; backends externos permanecem disponíveis.

Não foram usados saves pessoais, ROMs comerciais ou BIOS para os testes desta etapa. O pacote não inclui ferramentas internas de análise.

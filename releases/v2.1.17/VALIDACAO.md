# Validação da versão 2.1.17

- Suíte completa do Launcher: 938 testes, 937 aprovados, zero falhas e um teste opcional ignorado.
- Verificação direcionada da publicação: 110 testes de Bridge, download iOS, atualizações, transição de canal, perfis e notícias aprovados.
- Revisão independente da implementação: 69 testes direcionados aprovados e smoke Electron aprovado, incluindo seleção por teclado, opções estáveis, importação durante carregamento e buscas duplicadas.
- Regressões reproduzidas antes das correções: substituição desnecessária de opções, perda de seleção de IPA, erro do perfil antigo no novo perfil e duas buscas após cliques rápidos. Testes de regressão passaram após os ajustes.
- Fluxo visual completo do Bridge e 41 verificações visuais do Launcher aprovados com perfis temporários.
- Download real iOS verificado: ios-v0.15.1, 4.408.194 bytes, SHA-256 A11A5860198177AB73C2E3B15E13ACF88621539880E3C85E7F91A176C8306423. A escolha não depende de versão ou identificador fixos no código.
- Inspeção e importação da IPA pelo helper nativo verificadas com perfil temporário e sem autenticação, assinatura ou escrita no iPhone.
- Helper nativo preservado: SHA-256 C02C7AB76ED79903A4F3D17F207E60D7CC43E87C6E4C32D091E924B2770FD817.
- Host de emulação preservado: SHA-256 B489A258F07CF803E17B69AA0E1831C477987BA75A9A7B544104E1CA5BCC0DBA.
- Inventário das 386 dependências nativas conferido contra o Cargo.lock; fontes e licenças continuam incluídos.
- Auditoria independente da publicação: 83/83 testes aprovados; a repetição isolada do smoke Electron passou após uma execução anterior inconclusiva por timeout, sem alterar os limites do teste.
- Pacote oficial 2.1.17: os 196 arquivos da aplicação no ASAR correspondem aos fontes conferidos. A auditoria identificou 1.345 entradas no ASAR e 859 arquivos dos fontes nativos, sem ferramentas pessoais de agentes, credenciais, ROMs, saves, IPAs ou caches de compilação.
- Download e importação reais da IPA executados também a partir do código empacotado, usando o helper distribuído e um perfil temporário; integridade conferida, sem contato com Apple ou escrita em aparelho.
- Execução sintética do host e recuperação protegida GBA passaram no pacote oficial: cancelamento preserva o original, confirmação produz backup verificado e o próximo lançamento reutiliza o slot separado. Não certifica gameplay comercial.
- Extração do portátil final: aplicação e executáveis nativos idênticos ao pacote auditado; fontes e 758 avisos presentes com hashes corretos.
- Executável oficial: 410.431.394 bytes; SHA-256 6B87922392FB89DFC90D505EDBE15ADA930BB18327F78E892032F89EA1FFB32E.

## Pendências em aparelho

O usuário conectou a conta Apple e a interface indicou sessão conectada. Uma consulta independente e somente leitura retornou zero iPhones, embora o Windows enumerasse hardware Apple USB/WPD. Não foram reiniciados serviços nem modificados drivers para tentar mascarar esse estado.

Ainda exigem validação: reconhecimento real do aparelho no ambiente atual, assinatura aceita pela Apple, instalação e atualização preservando dados, comunicação Wi-Fi e renovação física. A publicação não certifica suporte concluído dos emuladores ou partidas completas.

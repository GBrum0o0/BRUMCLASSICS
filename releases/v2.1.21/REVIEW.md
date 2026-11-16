# Revisão técnica e escopo da entrega — 2.1.21

Base de referência: `v2.1.20` (repositório público) e checkpoint interno anterior de integração dos 30 grupos. Esta publicação entrega no canal `Official` Windows apenas o lote efetivamente validado, mantendo rotulagem honesta dos limites reais observados nos testes comerciais.

## Decisões de auditoria

1. **Separação estrita entre sistemas validados e experimentais:** Embora o registro interno ainda enumere os 32 módulos e alguns motores de diagnóstico/referência exponham rótulos internos de protótipo ou padrões sintéticos de áudio/vídeo, o runtime público (`murbOnly: true`) e esta release mantêm `gameplayReady=false` na suíte e classificam explicitamente como **Jogável Verificado** apenas **Atari 2600**, **NES**, **SNES** e **GBA**, preservando **GB** e **GBC** em regressão sem alteração de política de produção.
2. **Correções de interface aplicadas antes do empacotamento:** A auditoria identificou strings fixas desatualizadas na tela BRUMNEWS e no título inicial de atualização da interface HTML/renderer, corrigidas para `2.1.21` antes do build final.
3. **Correção de empacotamento de worktree:** O primeiro teste de abertura do `.exe` empacotado revelou ausência do módulo transitivo `dijkstrajs` dentro do `app.asar` por causa de link (`Junction`) de dependências; a árvore de dependências foi reinstalada de forma limpa e o empacotamento foi refeito e revalidado ponta a ponta em perfil isolado.
4. **Higiene pública garantida:** Nenhum código-fonte do core, ferramentas internas, configurações de agentes, ROMs, BIOS, saves pessoais ou credenciais foi incluído no pacote portátil ou neste repositório público.

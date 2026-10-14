# BRUMCLASSICS OFICIAL 2.1.1 — codinome Beta

Atualização oficial pelo próprio Launcher, no mesmo GitHub e sem reinstalação manual.

## Como atualizar na sua instalação

Em **Configurações → Sistema → Atualizações**, use **Verificar → Baixar → Reiniciar e atualizar**.

- Quem está na **2.1.0-beta.2** recebe primeiro a atualização de compatibilidade **2.1.0-beta.3**, já publicada. Depois de reiniciar, clique em **Verificar novamente** para receber esta versão oficial **2.1.1**.
- Quem já está na **2.1.0-beta.3**, **2.1.0 oficial** ou num Launcher oficial anterior compatível recebe **2.1.1** diretamente.
- O perfil, a biblioteca, as contas, as configurações e o Cofre da instalação atual são preservados; não se mesclam dados de outra instalação. Uma instalação Beta anterior atualiza seu próprio executável, sem sobrescrever outra cópia oficial ao lado.

**Beta é somente o codinome de desenvolvimento.** Esta versão tem tag numérica `v2.1.1`, asset padrão `BRUMCLASSICS-OFICIAL.exe` e é publicada como release oficial/Latest. As próximas versões continuam no fluxo oficial normal do aplicativo.

## Correção do fluxo visual

Os estilos flex anteriores mantinham controles visíveis mesmo quando o aplicativo os marcava como ocultos. Esta versão corrige especificamente a central de atualização:

- **Baixar** só aparece/habilita quando existe download disponível ou uma tentativa que pode ser repetida.
- **Reiniciar e atualizar** só aparece/habilita depois que o download passou na verificação.
- O acesso ao executável permanente fica oculto corretamente numa instalação Beta anterior preservada; não sugere usar o arquivo de outra instalação.
- Estado, notas e progresso continuam seguindo o mesmo atualizador, com tamanho e SHA-256 conferidos, backup e recuperação do executável anterior.

O Save Vault manual e a base BRUM Core PC da 2.1.0 permanecem incluídos. Não foram adicionados outros recursos, sincronização automática, servidor externo ou novo mecanismo de distribuição. RetroArch e funcionalidades existentes permanecem disponíveis.

Consulte `SAVE-VAULT-BETA.md` e [a validação desta correção](VALIDACAO.md).

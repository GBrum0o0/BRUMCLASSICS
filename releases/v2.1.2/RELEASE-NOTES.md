# BRUMCLASSICS OFICIAL 2.1.2 — Save Sync e BRUM Core PC

Atualização oficial pelo próprio Launcher, no mesmo GitHub. Beta continua apenas como codinome de desenvolvimento.

## Como atualizar

Em **Configurações → Sistema → Atualizações**, clique em **Verificar → Baixar → Reiniciar e atualizar**.

- Na **2.1.0-beta.2**, a primeira atualização oferecida é a ponte **2.1.0-beta.3** já publicada. Depois de reiniciar, clique em Verificar novamente para receber a oficial **2.1.2**.
- Na **2.1.0-beta.3** ou em uma versão oficial anterior compatível, a **2.1.2** é oferecida diretamente.
- A instalação mantém seu perfil, biblioteca, contas, configurações e Cofre. Dados de outra instalação não são mesclados e seu executável não é substituído.

Esta release tem tag numérica `v2.1.2`, não é prerelease e utiliza o asset padrão `BRUMCLASSICS-OFICIAL.exe`. O download continua sendo validado por tamanho e SHA-256 antes de preparar a atualização.

## Save Sync: jogos ausentes

- O Cofre passa a usar o catálogo completo atual do Launcher, sem depender da categoria antiga `classic`, da aba selecionada ou da cópia desatualizada da biblioteca na interface.
- **Atualizar jogos** consulta novamente o catálogo. Mudanças na biblioteca também atualizam o Cofre quando a tela está aberta.
- A associação de saves no scan deixa de excluir jogos com outra categoria ou sem esse campo. A regressão foi reproduzida e corrigida com uma entrada de teste **Pokémon FireRed**, ausente da biblioteca antiga da interface e com categoria antiga diferente.
- Jogos retirados da biblioteca continuam acessíveis como arquivados quando possuem revisões no Cofre do próprio perfil. Saves de outros perfis não são exibidos.
- Importar, definir como ativo e excluir continuam sendo ações separadas. Divergências são preservadas; a origem nunca é apagada ou sobrescrita pela importação.

## BRUM Core integrado ao Launcher PC

- Em **Configurações → CLASSICS → BRUM Core no Launcher**, é possível selecionar uma pasta própria de núcleos locais, verificar a presença de DLLs e consultar os caminhos de firmware.
- A preferência é persistente e prioriza a pasta escolhida. **Usar pasta padrão** remove apenas a preferência; não apaga cores, firmware nem saves.
- ROMs cadastradas manualmente também podem escolher **BRUM CORE PC · SAVE NATIVO** ao abrir, mesmo sem os campos antigos de cadastro RetroArch. O arquivo e o sistema são verificados antes da execução.
- O host nativo é iniciado e gerenciado pelo Launcher; usa saves próprios por perfil e ROM e só confirma uma sessão após o primeiro vídeo válido. Preparação, alteração de configuração e sessões concorrentes têm proteção; falha de inicialização encerra o processo daquela tentativa.
- Corrigido um encerramento intermitente do host: a leitura de comandos usa agora o pipe sem bloquear a emulação, sem deixar uma thread solta durante a saída. O comando de encerramento continua funcionando, inclusive quando chega dividido em mensagens.

**Limite desta integração:** a rota nativa oferece **GB, GBC e GBA com mGBA; NES com Nestopia; SNES com Snes9x**, mediante DLL local compatível. Encontrar uma DLL não certifica todos os jogos. Outros sistemas continuam pelo caminho existente do RetroArch, que foi preservado. O pacote inclui o host, mas não ROMs, BIOS ou DLLs dos emuladores; não há download automático de cores.

Esta etapa não acrescenta sincronização automática, transferência de rede, Gamepad, segunda tela, streaming ou conquistas online ao host. O Cofre guarda a escolha manual do save ativo; essa escolha não aplica o save automaticamente ao emulador.

Consulte o guia `SAVE-VAULT-BETA.md` anexo e a [validação desta versão](VALIDACAO.md).

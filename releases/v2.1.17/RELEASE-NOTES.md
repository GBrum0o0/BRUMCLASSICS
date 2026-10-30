# BRUMCLASSICS OFICIAL 2.1.17 — IPA do GitHub e seleção estável

Atualização oficial do Launcher Windows, disponível pelo verificador de atualizações do aplicativo.

## Brum iOS Bridge

- **Baixar IPA mais recente do GitHub:** consulta as releases iOS do repositório do Brum Classics, incluindo versões de teste, baixa a IPA com tamanho e SHA-256 conferidos e importa uma cópia no perfil ativo. A versão do aplicativo iOS é independente da versão do Launcher PC.
- **Seleção estável:** as opções deixam de ser recriadas quando nada mudou. A IPA importada ou baixada fica selecionada mesmo quando a tela estava sendo atualizada. Um único aparelho ou aplicativo disponível é selecionado; múltiplos candidatos exigem escolha.
- **Busca e orientação:** abrir a seção procura o iPhone. Se nenhum aparelho for detectado, a tela orienta a conexão USB, desbloqueio, confiança no computador e conferência no iTunes ou Dispositivos Apple.
- **Cancelamento e perfis:** sair ou trocar de perfil interrompe downloads pendentes sem importar no perfil seguinte. Erros de operações antigas não ficam no novo perfil. Cliques rápidos na aba compartilham a mesma busca.

Baixar e importar não assina nem instala automaticamente. A instalação continua exigindo confirmação. A opção de importar um arquivo local permanece disponível, sem alterar o original.

## Validação e limites

Foram aprovados 937 testes do Launcher, com zero falhas e um teste opcional ignorado, além de testes visuais em Electron, seleção nativa por teclado e revisão independente. A busca e o download reais da IPA publicada no GitHub passaram pela conferência de integridade e pela inspeção/importação nativa em perfil temporário.

**A detecção do iPhone não está concluída no ambiente atual:** o Windows reconhece o hardware USB, mas o serviço Apple devolveu uma lista vazia ao Bridge. A conta Apple foi conectada pelo usuário; isso não confirma a disponibilidade física do aparelho. É necessário conferir desbloqueio, confiança e reconhecimento no aplicativo Apple. Esta versão corrige o comportamento da interface e explica a ausência do aparelho; não cria um dispositivo fictício.

**Assinatura, instalação/atualização preservando dados, Wi-Fi e renovação física continuam pendentes de validação real.** A renovação automática é opcional e exige Launcher aberto, sessão autenticada e iPhone alcançável; fechar o Launcher exige novo login. Os demais limites do Bridge estão nas [notas da versão 2.1.16](../v2.1.16/RELEASE-NOTES.md).

Esta publicação contém somente o Launcher PC. Não inclui uma nova build de IPA ou APK e não altera os emuladores. Saves, Save Vault, biblioteca, perfis e IPAs originais são preservados. ROMs, BIOS, saves, credenciais e ferramentas pessoais de agentes não fazem parte do pacote. [Relatório de validação](VALIDACAO.md).

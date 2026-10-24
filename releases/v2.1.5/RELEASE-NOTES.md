# BRUMCLASSICS OFICIAL 2.1.5 — biblioteca, intro e contas Steam

Atualização do Launcher PC no mesmo GitHub e pelo atualizador existente. Beta continua apenas como codinome de desenvolvimento. Não inclui IPA/APK nem libera novos sistemas da M.U.R.B ENGINE.

## Atualizar pelo aplicativo

Configurações → Sistema → Atualizações → Verificar → Baixar → Reiniciar e atualizar.

O executável é `BRUMCLASSICS-OFICIAL.exe`, em uma publicação oficial não prerelease. O atualizador verifica tamanho e SHA-256 e preserva o vínculo com seu perfil. A antiga 2.1.0-beta.2 ainda precisa receber a ponte 2.1.0-beta.3 antes de verificar novamente a versão oficial.

## Novidades

- As capas abrem uma página completa do jogo. Instalar ou Jogar passa a ser uma ação explícita nessa página.
- Capa, fundo disponível, tempo de jogo, conquistas, atividades e anotações ficam juntos. Onde parei, objetivos, dicas e comandos continuam separados por jogo e perfil. Sinopses são exibidas quando disponíveis; a integração IGDB já configurada também pode fornecê-las. Dados indisponíveis não são inventados.
- A intro enviada foi tratada e ampliada para 1920×1080, mantendo animação, duração e áudio. Ela substitui a tela intermediária de notas e pode ser pulada; o encerramento também é automático. O tratamento não recupera detalhes perdidos na compressão do original.
- O Save Sync exibe somente Classics com saves registrados. Um Classic sem save continua disponível para associação durante a importação, mas não ocupa a galeria. Saves arquivados continuam acessíveis; importar, ativar e aplicar permanecem ações separadas.
- É possível adicionar mais de uma conta Steam sem substituir a anterior. Os catálogos são reunidos, e jogos em comum mantêm uma capa com os proprietários conhecidos. Tempo e conquistas não são somados entre contas.
- A página identifica a conta usada para jogar e para as estatísticas. Se a Steam estiver em outra conta, o Launcher abre o cliente oficial e orienta a troca. O usuário conclui login/Steam Guard na própria Steam; só confirmar a mensagem não basta: a sessão é conferida novamente antes da operação. Não há troca silenciosa, coleta de senha ou transferência de jogos entre contas.

## Preservação e limites

Stable, perfis, anotações, biblioteca, saves, Cofre e backends externos continuam no fluxo existente. Excluir uma cópia do Cofre não apaga o original de outro dispositivo. Esta atualização não inclui sincronização automática de saves.

A M.U.R.B ENGINE autoral continua em validação e bloqueada para gameplay público. Não se anuncia suporte autoral concluído e nenhum emulador externo é renomeado como M.U.R.B. O pacote não contém ROMs, BIOS, saves pessoais, credenciais, ferramentas internas ou DLLs de cores externos.

O teste com suas duas contas reais e a confirmação do foco ao abrir seus jogos dependem da validação no seu computador. Consulte `VALIDACAO.md` nesta mesma pasta para as verificações do pacote.

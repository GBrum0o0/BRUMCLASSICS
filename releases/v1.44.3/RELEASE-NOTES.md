# BRUMCLASSICS 1.44.3 — Executável permanente

Esta versão resolve o problema de atalhos quebrados ou duplicados após uma atualização. O launcher passa a usar **`BRUMCLASSICS OFICIAL.exe`** como nome permanente.

## O que mudou

- O nome e o caminho do executável não mudam mais entre versões.
- A versão 1.44.3 cria automaticamente o executável permanente ao lado do arquivo antigo, preservando o mesmo perfil.
- **Configurações → Sistema → Atualizações → ABRIR LOCAL** seleciona o arquivo correto no Explorador para que ele seja fixado na barra de tarefas uma única vez.
- A cada abertura, o launcher consulta silenciosamente se existe uma versão nova, quando **Verificar ao iniciar** está habilitado.
- Downloads e instalações continuam exigindo confirmação do usuário.
- Atualizações futuras fazem backup, substituem e reiniciam o executável permanente.
- Um asset versionado de transição permite que as versões 1.44.2 e anteriores reconheçam esta Release.

## Como migrar o atalho

1. Atualize normalmente pelo launcher ou instale a versão 1.44.3.
2. Abra a versão 1.44.3 uma vez pelo executável atual.
3. Vá a **Configurações → Sistema → Atualizações**.
4. Clique em **ABRIR LOCAL** ao lado de `BRUMCLASSICS OFICIAL.exe`.
5. Clique com o botão direito nesse arquivo e escolha **Fixar na barra de tarefas**.
6. Remova somente o atalho antigo que contém o número da versão.

O Windows não oferece uma API oficial segura para um aplicativo se fixar sozinho. Por isso, essa única ação manual evita alterações ocultas na barra de tarefas.

## Segurança e dados

- A migração é feita por identidade da instalação, não pelo conteúdo da biblioteca.
- Contas, jogos, coleções, favoritos, anotações, capas personalizadas, saves e configurações permanecem no perfil atual.
- O executável antigo não é apagado automaticamente e pode servir como recuperação.
- O novo binário e a cópia permanente são verificados por SHA-256.
- Instalações públicas novas continuam isoladas de perfis pessoais existentes no computador.

## Arquivos da Release

- `BRUMCLASSICS OFICIAL.exe` — executável permanente recomendado.
- `BRUMCLASSICS-OFICIAL-1.44.3-portable.exe` — cópia de compatibilidade para o atualizador antigo.
- `BRUMCLASSICS-OFICIAL-1.44.3-COMPLETO.zip` — pacote limpo completo.
- `BRUMCLASSICS-MOVEL-0.9.1-debug.apk` — aplicativo Android complementar, sem alteração nesta versão.
- `SHA256SUMS.txt` — hashes dos arquivos publicados.

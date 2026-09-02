# BRUMCLASSICS OFICIAL 1.54.0

Data: 2 de setembro de 2026

## Família Steam

Esta versão permite importar jogos compartilhados atualmente acessíveis pela sua Família Steam sem confundi-los com jogos comprados pela conta.

- A ativação é opcional e fica na linha da Steam em **Configurações → Conexões**.
- O vínculo usa um token temporário obtido numa página oficial da sessão Steam.
- Jogos compartilhados recebem o estado `family_shared` e a origem `steam_family_api`.
- Jogos próprios têm prioridade quando o mesmo AppID também aparece na família.
- Aplicativos excluídos do compartilhamento, indisponíveis, gratuitos da outra conta, ferramentas, servidores e outros itens que não sejam jogos são ignorados.
- O catálogo público da loja nunca é usado como prova de propriedade ou acesso familiar.
- O token fica protegido pela criptografia segura do Windows e não é exposto pela interface pública nem pelos logs estruturados.
- Se o token expirar ou a resposta estiver incompleta, a biblioteca própria continua sincronizando e o último catálogo familiar válido é preservado.
- Desativar a Família Steam não desconecta a Steam nem apaga capas, coleções, favoritos, saves ou outras personalizações.

## Como ativar

1. Conecte a Steam normalmente usando seu SteamID64 e sua Web API Key.
2. Abra **Configurações → Conexões** e clique em **ATIVAR FAMÍLIA**.
3. Clique em **ABRIR TOKEN OFICIAL** e faça login na Steam, se necessário.
4. Copie o JSON exibido e cole no campo do BRUMCLASSICS.
5. Clique em **ATIVAR E SINCRONIZAR**.

Quando o token temporário vencer, a ação muda para **RENOVAR FAMÍLIA**. Repita os passos 3 a 5.

## Validação

- 464 testes automatizados aprovados.
- Parser de token direto e do JSON oficial validado.
- Expiração, ausência de grupo e limitação temporária têm diagnósticos próprios.
- Exclusão do usuário atual, itens bloqueados e não jogos validada.
- Deduplicação por AppID e prioridade de licença própria validadas.
- Token omitido do contrato público e dos logs.
- Perfis `official` e `distribution` verificados separadamente dentro dos executáveis.

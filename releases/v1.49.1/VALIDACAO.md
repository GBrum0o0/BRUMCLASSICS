# Validação 1.49.1

- 419 testes de regressão aprovados; verificação de sintaxe JavaScript aprovada.
- 98 arquivos src do app.asar público conferidos por SHA-256 contra o código validado.
- Teste de perfil empacotado 1.49.0 → 1.49.1 preservou o perfil official; uma instalação nova permaneceu distribution.
- Os 18 diálogos também foram testados no renderer do app.asar público compilado.

- Regressões novas executam o serviço RetroAchievements com respostas controladas: catálogo indisponível preserva dados, hash incompatível recusa fallback de título e hash oficial associa um título renomeado.
- Renderer Electron: 18 diálogos fechados pelo X, pilha invertida validada por Escape, primeiro acesso aberto e dispensado.
- APK 0.13.1 compilado; HomeLibraryTest aprovado; assinatura v2/v3 preservada.
- Metadados efetivos conferidos por aapt: com.brumclassics.mobile, versionCode 20, versionName 0.13.1.
- SHA-256 APK: CFBA4A54AF0390190A5DB97FF05211A2C727AACB8FB6DFAC2293D3308E6781AE.

Não foi testado um desbloqueio de conquista real em cada ROM nem um novo teste em celular físico. As verificações automatizadas não garantem disponibilidade dos serviços externos.

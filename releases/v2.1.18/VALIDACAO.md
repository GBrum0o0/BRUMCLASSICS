# Validação da versão 2.1.18

- Snapshot original do Antigravity: compilação MSVC C++17 /W4 /WX aprovada, 347 testes aprovados. Isso não foi tratado como certificação de compatibilidade.
- Integração seletiva: 355/355 testes nativos aprovados em compilação independente, incluindo seis regressões novas de SMS/PCE e as proteções de saves GBA/NES.
- Testes focados SMS/Game Gear/PC Engine: 21/21 aprovados. O teste de timing falhou com o código lançado anterior e passou após a integração.
- Comparação independente de 29 arquivos protegidos de host e GB/GBA/NES com a base 2.1.17: zero divergências de bytes. Os 114 arquivos de entrada do build nativo ficaram inalterados durante a compilação.
- Host nativo recompilado a partir do código protegido com os núcleos integrados; SHA-256 4A7C38B2AEFF6B00265C6C83522CC67D214FD08E6863AE5E839BD55E0AD42F02.
- A integração não incorporou ferramentas ou definições de agentes, matriz de prontidão do snapshot ou recursos demonstrativos de host/GPU/JIT/conquistas.
- Suíte completa do Launcher: 938 testes, 937 aprovados, zero falhas e um teste opcional ignorado.
- Pacote oficial 2.1.18: os 196 arquivos da aplicação no ASAR correspondem aos fontes conferidos.
- Execução sintética do host empacotado e recuperação protegida GBA aprovadas; cancelamento preserva o original, confirmação cria backup verificado e o slot Flash separado é reutilizado.
- Contrato empacotado SMS, Game Gear e PC Engine aprovado com entradas sintéticas, encerramento normal e saves isolados; arquivos de entrada preservados. Não certifica partidas comerciais.
- Extração do portátil final: aplicação e executáveis nativos idênticos ao pacote auditado; fontes e 758 avisos de licenças presentes com hashes corretos.
- Executável oficial: 410.438.939 bytes; SHA-256 3E8F107D1A5BCDA67152ABEA379FB434F68A5BF95DC2A89D76075D455D5675D4.

## Limites

Os testes exercitam contratos e comportamentos sintéticos; não confirmam partidas completas de jogos comerciais, fidelidade audiovisual ou compatibilidade concluída dos 32 sistemas. Os resultados excluídos e os motivos estão em [REVIEW.md](REVIEW.md).

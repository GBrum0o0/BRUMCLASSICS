# Extensão 001 — integração e limites de validação

As entregas originais da Pokédex estavam em branches de desenvolvimento. A fonte SideStore 0.25.0 já havia sido publicada; isso não incluía a Pokédex. Esta integração preserva a base oficial e prepara PC 2.1.35, iOS 0.26.0 (59) e Android 0.35.0 (47).

## Correções após revisão independente

- Preservação de timestamps ISO válidos no hash v1, permitindo backups e sincronização entre Java, Swift e Node sem reescrever a representação recebida.
- Validação integral de lotes antes de alterar a coleção; falhas de persistência não confirmam descobertas nem notificações. Mutações concorrentes por perfil são serializadas.
- Validação do proprietário do backup/evento e da ativação da extensão antes de aceitar descobertas remotas ou mostrar popups.
- Desempate de registros equivalentes pelo identificador de captura; rejeição de delimitadores ambíguos na serialização v1.
- Leituras incompletas da RAM/boxes não estabelecem uma coleção inicial nem geram falsas descobertas quando a leitura se recupera.
- Acesso à Pokédex no PC; aba Extensões no Gaming Mode móvel. Espécies ocultas permanecem como `???`.
- Publicação iOS fixa o commit compilado e não sobrescreve binários já publicados.

## Evidências automatizadas locais

- Adaptador C++: 115 verificações aprovadas, incluindo leitura incompleta e recuperação, usando dados sintéticos.
- Android: 12 programas de contrato aprovados e compilação dos fontes Java/recursos; isso não equivale a um teste no aparelho.
- iOS: 33 testes Python e validador do projeto aprovados; Swift, simulador e build de distribuição dependem do CI macOS.
- Revisão independente executou casos adversariais de backup, lote inválido, falha de disco, concorrência, autenticação e isolamento de perfil.
- Paridade Java/Node: 802 registros sintéticos com Unicode e representações ISO distintas produziram o mesmo hash e passaram pelo merge/export/verify.
- Interface PC: oito verificações com Electron, preload e serviços reais; capturas inspecionadas com dados sintéticos, abas normal/shiny e perfil vazio.

## Limites obrigatórios

O catálogo offline contém 802 espécies, de Bulbasaur a Marshadow. Não representa 802 jogos compatíveis nem todos os Pokémon lançados. A arte incluída é ilustrativa; não se apresenta como um catálogo de sprites oficiais.

O adaptador disponível é um **piloto para FireRed BPRE v1.0/v1.1**, sujeito à validação interativa. Testes anteriores de boot e diferenças entre saves sintéticos não comprovam uma captura realizada durante gameplay. Captura real, popup sobre jogo real, sincronização entre aparelhos físicos e jogabilidade continuam pendentes de evidências específicas. Não se atribui status JOGÁVEL VERIFICADO a partir destes testes.

Descobertas da Pokédex são registros locais da extensão, distintos de conquistas oficiais do RetroAchievements. Nenhuma ROM, BIOS, save pessoal, ferramenta ou configuração de agentes integra esta entrega.

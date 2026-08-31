# Validação da release 1.47.0

- 408 testes automatizados: todos passaram, incluindo persistência do cache de conquistas, cancelamento de consulta ao encerrar a sessão e contagem preservada na reconciliação seguinte.
- Sintaxe dos módulos JavaScript validada.
- Os 98 arquivos de src foram comparados por SHA-256 com o app.asar compilado: iguais.
- Menu contextual testado no renderer compilado usando eventos nativos de mouse no Electron: jogo moderno, seleção em lote e CLASSICS; Escape fecha e a seleção permanece intacta. Verificação inclui opacidade e captura renderizada, não apenas presença no DOM.
- Atualização 1.46.1 → 1.47.0 validada com perfil de teste: instalação pessoal mantém a identidade official e suas coleções; instalação nova usa distribution.
- Classificação consultada na Steam: software reconhecido pelo catálogo oficial, sem lista manual e sem usá-lo como prova de propriedade.
- Recuperação Ubisoft testada com conta correspondente, conta divergente, cache vazio e exclusões; o escopo local participa do fast boot.
- Sessões interrompidas: testes de idempotência e preservação de duração, sem estimar horas ausentes.
- APK MOVEL 0.11.0: assinatura v2/v3 verificada. O binário móvel não foi alterado nesta release; documentação revisada. Não foi executado um novo teste em celular físico nesta rodada.

Não há garantia de disponibilidade das APIs de terceiros. Ubisoft permanece em fallback local confirmado. Os testes não desbloqueiam conquistas reais nem substituem a validação de uma sessão de jogo pelo usuário.

# BRUMCLASSICS 1.66.0 — Conquistas e coleções protegidas

Esta atualização corrige a perda aparente de conquistas Steam, protege a organização da biblioteca e reduz a espera antes de os jogos aparecerem.

## Conquistas Steam

- A atualização rápida da biblioteca não apaga mais catálogos oficiais já armazenados.
- Estados contraditórios — sincronização disponível com catálogo vazio — são identificados e consultados novamente sem aguardar sete dias.
- A recuperação continua em segundo plano depois que a interface é aberta.
- A API oficial foi validada com títulos afetados como Left 4 Dead 2, Portal 2, Cuphead, Stardew Valley e The Witcher 3.

## Coleções

- Os vínculos entre jogos e coleções passam a ser guardados em um índice independente de `library.json`.
- Sincronizações de lojas e reconstruções da biblioteca reaplicam a organização por ID do jogo ou identidade oficial da loja.
- Remover voluntariamente um jogo de uma coleção continua funcionando e também limpa o vínculo protegido.
- Na primeira abertura, o launcher procura uma cópia válida anterior quando encontra evidência de corrupção e recupera somente associações verificáveis.

## Inicialização

- Uma biblioteca disponível no cache não fica mais aguardando o orçamento completo de seis segundos do preparo de conquistas.
- Após 700 ms, a interface é liberada e o trabalho restante segue sem bloquear o uso do launcher.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não precisam de novos pacotes para esta correção exclusiva do launcher Windows.

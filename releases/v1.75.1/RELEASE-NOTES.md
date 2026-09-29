# BRUMCLASSICS OFICIAL 1.75.1

Esta atualização corrige o acompanhamento de downloads iniciados diretamente no cliente Steam.

## Steam em tempo real

- A pasta oficial `steamapps\\downloading` passa a ser acompanhada recursivamente junto do manifesto do jogo.
- Instalações novas e atualizações de jogos já instalados entram automaticamente na Central de Downloads.
- Durante uma transferência ativa, porcentagem, bytes, velocidade e previsão são atualizados a cada 1,5 segundo.
- A primeira verificação da Steam acontece logo após a abertura do launcher.

## Correções de estado

- Uma transferência ativa não é mais tratada como concluída apenas porque o jogo já possui pasta ou executável instalado.
- Foi corrigida a transição interna que bloqueava o estado **Baixando** quando a operação começava fora do launcher.
- Ao terminar, a instalação continua sendo confirmada pelas evidências oficiais da Steam.

Android 0.20.0 e iOS 0.11.0 continuam compatíveis e não receberam alterações de código nesta atualização.

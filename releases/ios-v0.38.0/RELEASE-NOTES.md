# BRUMCLASSICS+ iOS 0.38.0 — Pacote de Correções e Controle de Regressões

- **Auditoria e proteção contra regressões:**
  - Protege a barra de seções do Gaming Mode (`JOGADOS RECENTEMENTE` · `BIBLIOTECA` · `EXTENSÕES`) e o logo superior contra cortes horizontais em retrato/telas compactas, mantendo o ícone de QR Code do MyBrumControl e o acesso à Pokédex sempre visíveis.
- **Simplificação da interface e navegação:**
  - Simplifica o indicador de sincronização para símbolo visual sem texto (Verde = sincronizado, Laranja = sincronizando, Vermelho = não sincronizado) vinculado ao estado real de sincronização e acessibilidade preservada.
  - Remove o card "Tudo sincronizado" da tela inicial, oculta temporariamente a Central de Notificações (preservando código, histórico, contratos e pop-ups em jogo) e retira a seção Estatísticas/gráfico da interface principal.
  - Adiciona ícone próprio de Perfil no topo ao lado de Controles, QR Code e Configurações, separando identidade/contas/conexões (PC, RetroAchievements, Google Drive e vínculos) das Configurações técnicas.
  - Corrige a rolagem das telas (`Home`, `Companion` e demais abas) para evitar sobreposição pela barra inferior.
- **Pokédex Universal (design Kanto G1 preservado):**
  - Corrige a detecção de Pokémon iniciais (ex.: escolha de Squirtle no FireRed mesmo antes do recebimento da Pokédex), evoluções (ex.: Pidgey → Pidgeotto preservando a espécie anterior e a independência normal/shiny), roteamento do pop-up no emulador ativo e sincronização automática com o PC.

Instale e atualize conectando o iPhone ao PC exclusivamente pelo **Brum iOS Bridge** no BRUMCLASSICS Desktop.

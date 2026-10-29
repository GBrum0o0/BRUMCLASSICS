# Validação da versão 2.1.16

- Suíte completa do Launcher: 884 testes, 883 aprovados, zero falhas e um teste opcional ignorado.
- 41 verificações visuais e de interação em Electron aprovadas, com perfil temporário: sobreposição das Configurações, preservação de notas, conteúdo por seção, fundo dinâmico e estados do Bridge.
- Seis testes nativos Rust aprovados; helper compilado para Windows x64.
- Verificação direcionada de publicação: 42 testes de atualização, transição de canal, notícias e Bridge aprovados.
- Revisão independente: 29 testes de isolamento de perfis e Bridge aprovados, além da inspeção dos arquivos e das licenças empacotadas.
- Inventário de licenças: 386 dependências conferidas contra o Cargo.lock, com avisos, autoria e hashes. Ausências de arquivo de licença upstream são documentadas com declarações originais e proveniência dos textos canônicos.
- Helper: SHA-256 C02C7AB76ED79903A4F3D17F207E60D7CC43E87C6E4C32D091E924B2770FD817.
- Host de emulação preservado: SHA-256 B489A258F07CF803E17B69AA0E1831C477987BA75A9A7B544104E1CA5BCC0DBA.
- Pacote oficial Windows x64: os 195 arquivos da aplicação no ASAR correspondem aos fontes conferidos; versão 2.1.16 e edição official confirmadas.
- Auditoria independente do pacote: 1.344 entradas do ASAR e 859 arquivos dos fontes nativos, sem ferramentas de agentes, dados pessoais, ROMs, saves ou IPAs; as 758 cópias de avisos têm os hashes esperados.
- Execução sintética do host empacotado aprovada, com save temporário e arquivo de entrada preservado. As dependências da aplicação funcionam a partir do próprio ASAR.
- Recuperação GBA empacotada aprovada: cancelamento preserva o original, confirmação cria backup verificado e o próximo lançamento reutiliza o slot Flash separado.
- Smoke do helper distribuído: importação da IPA por cópia, SHA-256 original preservado e duplicata reconhecida. Nenhuma autenticação, assinatura ou escrita em aparelho foi tentada; o iPhone estava desconectado nesse teste final.
- Extração do executável portátil final: aplicação, host e helper idênticos ao pacote auditado; fontes nativos e todos os 758 avisos de licenças presentes e com hashes corretos.
- Executável portátil: 410.413.467 bytes; SHA-256 33D331A658737C828B1C510CB5801A9E1DDE2E4FA3E56347C81ACC81F8F39EF6.

## Limites em aparelho

Foi comprovada a detecção USB do iPhone e a leitura de aplicativos instalados, sem realizar instalação ou alterar dados. A inspeção da IPA existente também foi executada.

Permanecem pendentes: login Apple real, 2FA e seleção de equipe reais, assinatura aceita pela Apple, instalação e atualização preservando os dados, comunicação Wi-Fi e renovação física. Testes com provedores e aparelhos simulados não substituem essas verificações.

A renovação automática depende do Launcher aberto, sessão autenticada e dispositivo alcançável. Não há tarefa autônoma após fechar o Launcher. Os testes desta release não certificam partidas completas dos emuladores.

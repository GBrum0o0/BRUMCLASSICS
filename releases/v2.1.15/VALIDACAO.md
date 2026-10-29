# Validação da versão 2.1.15

- Suíte completa do Launcher: 869 testes, 868 aprovados, zero falhas e um teste opcional ignorado.
- Verificação de sintaxe do projeto aprovada.
- QA independente: 74 testes direcionados aprovados e smoke Electron aprovado.
- Smoke visual final com perfil temporário: capas abrem detalhes sem instalar; ação explícita instala uma vez; campo único preserva os quatro textos antigos, salva e reabre; troca de perfil limpa o conteúdo pessoal anterior.
- Coleções com identificação por seção: migração idempotente, renomear/remover isolados, movimento e desfazer, edição de categoria e preservação de perfis inativos.
- Contagens da interface conferidas em Jogos e Clássicos, inclusive IDs legados compartilhados.
- Capturas em 1440 e 1024 pixels: conquistas com imagem e alternativa para imagem ausente, detalhes sem mensagens técnicas, largura útil ampliada e ausência de rolagem horizontal no detalhe.
- Executável Windows x64 empacotado com electron-builder 26.15.3 / Electron 43.4.0.
- Os 190 arquivos da pasta de aplicação no ASAR correspondem aos fontes verificados.
- Dependências empacotadas verificadas: QR em SVG/PNG, ZIP, Three.js e WebSocket.
- Host nativo preservado da versão anterior; SHA-256: B489A258F07CF803E17B69AA0E1831C477987BA75A9A7B544104E1CA5BCC0DBA.
- Teste sintético do host: execução autoral, gravação em pasta temporária e ROM preservada. Não certifica jogos comerciais nem os 32 sistemas.
- Recuperação GBA empacotada: cancelamento preserva o original; confirmação gera backup verificado; slot Flash separado aceito e reutilizado.
- Sem novas builds de Android/iOS. Clientes antigos têm a limitação de edição de anotações descrita nas notas da versão.

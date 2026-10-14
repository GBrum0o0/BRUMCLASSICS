# Validação — PC 2.1.0-beta.2

Fonte do Launcher: commit local `fca46fb` (branch de desenvolvimento Beta). A tag pública desta release contém documentação de publicação; o Launcher é distribuído como binário, conforme o fluxo existente.

- Suíte completa: **716 testes passaram**, 0 falhas, 0 ignorados.
- Verificação de sintaxe do Launcher e dos módulos de scan/interface: concluída.
- Testes de origem, importação seletiva, conflito, ativação separada, perfis, persistência e exclusão segura: concluídos.
- Saves que mudam depois do scan, seleção forjada/duplicada, corrupção e travessia de caminhos: rejeitados.
- Junction no destino do Cofre: rejeitado sem criar revisão no armazenamento externo.
- Backups e restauração anteriores, fluxo móvel manual preexistente e host PC: testes preservados.
- Interface Electron testada com serviço real de Cofre e arquivos sintéticos em perfil temporário: capas, prévia, seleção, origem personalizada, conflito, ativação e cancelamento/exclusão. Resoluções 1440×900 e 1024×768, sem overflow horizontal da tela do Cofre.
- Host PC validado com núcleo mGBA real e ROM GB sintética própria, incluindo persistência de save. Testes adicionais de host simulado verificam falha de abertura, tempo de vídeo e proteção de saves.
- Atualizador Beta testado para consulta, seleção semântica, download, SHA-256, preparação do update e preservação do executável Stable e do perfil. Helper Windows de troca/recuperação validado na suíte existente.

Antes da publicação, o arquivo `app.asar` da build é comparado com a fonte atual e o host empacotado é comparado por SHA-256 com o host compilado. Assets são verificados por tamanho e digest retornados pelo GitHub antes de tornar a release pública.

Esses testes não substituem validação dos jogos e saves pessoais em cada dispositivo. Não foi realizado teste de jogo no iPhone nesta etapa PC, nem foi certificado suporte nativo a consoles adicionais.

# Validação — atualização oficial 2.1.0 e compatibilidade Beta 3

- Fonte do Launcher: commit local `4779023`; a tag pública contém a documentação da publicação. Os binários são distribuídos pelo fluxo GitHub existente.
- Suíte completa: **720 testes passaram**, 0 falhas, 0 ignorados.
- Código real do atualizador já distribuído na Beta `2.1.0-beta.2` carregado nos testes: encontra a publicação `2.1.0-beta.3` com o nome de asset compatível e versão correta.
- Atualizador novo na instalação anterior: seleciona a release oficial numérica `2.1.0` depois da atualização de compatibilidade.
- Atualizador oficial anterior: seleciona diretamente `2.1.0`, ignorando a publicação de compatibilidade.
- Bootstrap das duas etapas conserva o vínculo e o diretório do perfil anterior, sem tocar nos dados de outra instalação. Nome apresentado: BRUMCLASSICS OFICIAL; Beta separado como codinome.
- Transação de atualização oficial em perfil Beta anterior: mantém executável/dados daquela instalação, cria backup e não substitui um executável oficial adjacente.
- Cofre manual, conflitos, origens, importação seletiva, segurança dos caminhos e exclusão: testes mantidos. QA visual de capas/prévia/conflito/exclusão em Electron, com arquivos sintéticos e serviço real, passou em 1440×900 e 1024×768.
- Host PC testado com mGBA real e ROM GB sintética própria; não certifica todos os jogos/cores.
- Fonte do ASAR e host incluído conferidos antes da publicação. Assets conferidos no GitHub por tamanho e SHA-256 antes de publicar.

O executável não contém biblioteca pessoal, saves, contas, ROMs, BIOS ou core de teste. A edição pública mantém o mecanismo de isolamento das instalações já existente; não força migração nem mescla de perfis.

Instalação/troca/recuperação verificadas com fixtures isoladas. Nenhuma instalação pessoal foi atualizada durante o teste. As checagens remotas de descoberta e download utilizam arquivos temporários, sem aplicar a atualização ao launcher pessoal.

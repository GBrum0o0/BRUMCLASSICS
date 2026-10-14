# Validação — oficial 2.1.1

- Fonte local do Launcher: commit `17a1547`.
- Suíte completa: **721 testes passaram**, 0 falhas, 0 ignorados.
- Transição pelo atualizador real da Beta 2, preservação de perfil, download/checksum e proteção de executável oficial adjacente: testes mantidos.
- Regressão específica para ocultação de controles no painel de atualização e instalação somente em estado `ready`: incluída.
- QA Electron conferiu **estilo calculado**, não apenas o atributo `hidden`: quando disponível, Baixar está visível e Reiniciar está realmente oculto; após download verificado, Baixar está realmente oculto e Reiniciar está visível/habilitado. Campo de executável de outra instalação permanece realmente oculto.
- Capturas realizadas após renderização do estado da tela, evitando leitura de um frame visual anterior. Marca: BRUMCLASSICS OFICIAL; Beta como codinome.
- Fonte empacotada do ASAR comparada com a fonte validada e host PC incluído conferido por SHA-256; ausência de biblioteca/contas/saves pessoais, ROMs/BIOS e core de teste verificada.
- Assets conferidos por tamanho e digest do GitHub antes de publicar. Instalação/troca/recuperação testadas em fixtures; nenhuma instalação pessoal foi modificada pelos testes.

A compatibilidade intermediária 2.1.0-beta.3 já publicada permanece válida, sem substituir seus assets. Não é necessário baixar um novo instalador manualmente: o filtro antigo reconhece a ponte, e a ponte reconhece as versões oficiais mais recentes.

# BRUMCLASSICS OFICIAL 2.1.38 — Correção de Vídeo PSP, Busca/Filtros, Controles, MYbrumCONTROL e Lançamento Direto

- **PSP no PC (OpenGL FBO & Leitura):** corrigido dimensionamento e estado OpenGL (`1920x1088` dinâmico, retângulo `activeSrcW x activeSrcH`, orientação bottom-left, proporção 16:9 e resolução interna `960x544`), eliminando distorção/recorte no canto da tela em jogos PSP com imagem, áudio e entrada verificados.
- **Pesquisa e Filtro por Console no CLASSICS:** pesquisa por nome ignorando maiúsculas/acentos com limpeza rápida e seletor dinâmico por console (**Todos os consoles** + consoles presentes + **Não identificado**), sem mover ou alterar arquivos.
- **Deduplicação de Controles:** um controle físico conectado é reconhecido como apenas 1 jogador lógico (suportando dois controles idênticos como P1/P2 e ignorando receptores em standby, teclados e dispositivos auxiliares).
- **MYbrumCONTROL (Somente Rede Local):** recepção dedicada em **Controles -> MYbrumCONTROL** com QR Code (`murb://`), código `MBC-...`, porta e estado ao vivo para parear celular na LAN como controle virtual isolado.
- **Lançamento Direto em Jogar & Menor Latência:** clicar em **Jogar** abre o jogo diretamente na M.U.R.B Engine sem o modal intermediário *"TESTAR NA M.U.R.B ENGINE"*, com cache de identidade de ROMs, selo de recursos já extraídos (`.brum-stage-*.json`), paralelização pré-lançamento e remoção de consultas de rede bloqueantes.
- Preserva todos os 33 sistemas, Save Vault, perfis, RetroAchievements, Pokédex Universal, Google Drive e o fluxo oficial de atualização.

Atualize por **Verificar atualização** no Launcher ou pelo executável oficial desta release (`BRUMCLASSICS-OFICIAL.exe`). Não desinstale nem apague seus saves para atualizar.

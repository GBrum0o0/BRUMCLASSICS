# Validação — BRUMCLASSICS 1.69.0

- Verificação sintática completa: aprovada, incluindo o novo módulo de biblioteca persistente.
- Suíte automatizada: **588 testes aprovados, zero falhas**, nenhum teste ignorado.
- Onze novos testes de regressão cobrem expiração e renovação familiar, serialização, consultas parciais e completas, catálogos, migração, remoção explícita, conta ativa e biblioteca durável.
- Catálogos não confirmados e registros de outras contas não se tornam jogos possuídos.
- Coleções, favoritos, capas e conquistas existentes permanecem na reconciliação simulada após falha e renovação.
- A fonte durável prevalece sobre o cache derivado; uma biblioteca vazia salva não ressuscita entradas removidas do cache.
- Verificação visual Electron isolada em 1440 × 900: dois cartões preservados, avisos de renovação/acesso, capa carregada, opacidade completa e ausência de rolagem horizontal.
- Os testes foram isolados; não foi feita uma renovação real das contas pessoais do usuário.
- Pacote ASAR: versão 1.69.0 e edição oficial confirmadas; **126 arquivos de src comparados byte a byte** com o conteúdo empacotado.
- Auditoria das dependências de produção: **zero vulnerabilidades conhecidas**.
- Android 0.19.0 e iOS 0.10.0: código e protocolo inalterados; nenhum pacote móvel novo.
- Executáveis: `BRUMCLASSICS-OFICIAL-1.69.0-portable.exe` e `BRUMCLASSICS-OFICIAL.exe`.
- Tamanho de cada executável: `385829659` bytes.
- SHA-256: `eff3cf54469804ff8132dc06af455a0391fa4f3fc2dd9a2aa9e4d1c3fbb81954`.

Esta validação não equivale a testar todos os serviços remotos em todas as contas nem garante disponibilidade offline de imagens que ainda não foram baixadas.

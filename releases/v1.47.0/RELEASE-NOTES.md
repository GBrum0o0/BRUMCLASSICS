# BRUMCLASSICS OFICIAL 1.47.0 — Correções da auditoria

- Ubisoft: o fast boot respeita o vínculo local, antes ignorado. Confirmações existentes são recuperadas por identidade e conta, sem usar catálogo público como prova de propriedade. Jogos rejeitados ou de outra loja permanecem excluídos.
- Sessões: inícios sem encerramento são marcados como interrompidos na próxima abertura. O histórico original recebe backup; horas totais não são recalculadas nem estimadas.
- Steam: catálogo oficial classifica software, vídeos, hardware e DLC separadamente. Esse catálogo não concede propriedade. O cache da classificação dura 14 dias.
- Botão direito: removida a referência à antiga ação Fila que lançava uma exceção antes de exibir o menu. Seleção preservada; verificação com entrada nativa do Electron.
- Conquistas: timestamps/status da sincronização passam a persistir; consultas limitadas, concorrência controlada, cache de resultados sem suporte e monitor adaptativo encerrado ao finalizar o jogo. HTTP 400 genérico não é confundido com jogo sem conquistas.
- BRUMWORLD: sumário de 14 páginas e orientações de Ubisoft, sessões, conquistas e celular revisadas. Linha do tempo atualizada.
- BRUMCLASSICS MOVEL permanece na versão 0.11.0. Documentação atualizada para HTTPS, QR completo, atualização, uso offline e Companion.

## Limites importantes

Ubisoft usa o fallback local confirmado, não uma nova autenticação online. Conquistas dependem da disponibilidade e privacidade da API; não há promessa de atualização instantânea. Sessões antigas sem evidência do encerramento não recebem duração inventada. Não é necessário limpar banco, reinstalar ou apagar o perfil.

## Instalação

Use Configurações → Sistema → Atualizações. Aguarde o download, confira as notas e escolha Reiniciar e atualizar. Instalações existentes mantêm seu perfil; a distribuição nova começa limpa.

# BRUMCLASSICS 1.70.2 — Biblioteca estável

Esta atualização corrige o efeito de piscar dos jogos durante o monitoramento automático de instalações.

## Monitoramento mais preciso

- Arquivos temporários do GOG, dados de conquistas da Ubisoft, logs e outros eventos sem relação com instalações deixam de acionar auditorias completas.
- Eventos repetidos das lojas são agrupados e recebem um intervalo de segurança.
- As verificações periódicas de Steam, Epic, GOG e Ubisoft são escalonadas para não acontecerem todas juntas.
- Instalações, desinstalações e alterações reais continuam sendo detectadas normalmente.

## Biblioteca sem reconstruções desnecessárias

- O launcher compara o estado real das instalações antes de salvar.
- Mudanças apenas em timestamps ou metadados de consulta não regravam a biblioteca de jogos nem o cache.
- O aviso **VERIFICANDO** atualiza somente o cartão correspondente.
- Capas, foco, seleção e rolagem permanecem estáveis enquanto o monitor trabalha.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não receberam alterações nesta atualização exclusiva do launcher Windows.

Validação: 606 testes automatizados aprovados, zero falhas, verificação sintática, auditoria de dependências, teste visual de identidade dos cartões e inspeção integral do pacote ASAR.

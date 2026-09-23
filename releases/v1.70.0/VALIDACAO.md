# Validação — BRUMCLASSICS 1.70.0

- Verificação sintática completa: aprovada.
- Suíte automatizada: **595 testes aprovados, zero falhas**, nenhum teste ignorado.
- Novos testes cobrem bloqueio após reinício, isolamento explícito por perfil, mesclagem concorrente de conquistas, sessão vinculada ao jogador inicial, desconexão durante sincronização, recuperação parcial da biblioteca e renovação do executável permanente.
- Verificação visual Electron em 1440 × 900: resumo centralizado, três cartões pessoais, raio de 30 px, ausência de rolagem horizontal, tela de configurações e retorno aprovados.
- Exclusão protegida e preservação dos dados existentes na configuração do Jogador principal continuam aprovadas.
- Auditoria das dependências de produção: **zero vulnerabilidades conhecidas**.
- Pacote ASAR: versão 1.70.0 e edição oficial confirmadas; **127 arquivos de `src` comparados por SHA-256**, sem divergências.
- Android 0.19.0 e iOS 0.10.0: código e protocolo inalterados; nenhum pacote móvel novo.
- Executáveis: `BRUMCLASSICS-OFICIAL-1.70.0-portable.exe` e `BRUMCLASSICS-OFICIAL.exe`.
- Tamanho de cada executável: `385850532` bytes.
- SHA-256: `423155add5181048156eec12e5ca94199f97e86706419174ec81692dc5d2070e`.

Esta validação não equivale a testar todos os serviços remotos em todas as contas nem garante disponibilidade offline de imagens que ainda não foram baixadas.

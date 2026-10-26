# BRUMCLASSICS OFICIAL 2.1.12 — recuperação segura do save experimental GBA

Corrige o fluxo que exibia `save content/format/size mismatch; original preserved` ao abrir uma ROM Flash128 com um snapshot experimental SRAM antigo da mesma ROM.

## Como funciona

O Launcher verifica o container antigo e a identidade da ROM. No caso elegível SRAM de 64 KiB → Flash de 128 KiB, apresenta uma confirmação, com **Cancelar** como padrão.

Ao escolher **Preservar backup e iniciar save novo**:

1. O original permanece intacto, no mesmo lugar.
2. Uma cópia de backup é criada sem substituir arquivos e conferida por SHA256.
3. Um save Flash128 novo é criado em arquivo separado (`.flash128.onbrum`).
4. O jogo é iniciado e as próximas aberturas reutilizam esse novo arquivo.

**O progresso antigo não é convertido.** Confirme apenas se quiser iniciar um teste com save novo. O caminho do backup aparece na confirmação. Não é necessário apagar manualmente o save antigo.

Cancelar preserva o save. Dados corrompidos, de outra ROM, modificados durante a confirmação ou um destino novo já existente não são sobrescritos. Mudanças de perfil/ROM bloqueiam a operação. Falhas de armazenamento preservam o original e o backup já confirmado; arquivos temporários próprios são limpos quando possível. Se o volume não permitir a publicação exclusiva do arquivo, a operação é recusada com segurança.

## O que não mudou

- Save Vault, saves originais dos jogos, perfis e biblioteca não são migrados ou apagados.
- A recuperação é limitada aos saves de teste isolados da M.U.R.B ENGINE. Não é um conversor de saves nem aplicação de conteúdo do Cofre.
- Esta versão não traz novas correções de imagem ou áudio. O GBA e os demais módulos continuam experimentais, com as limitações da 2.1.11. Não é anúncio de 32 consoles concluídos.
- Somente Launcher PC Windows x64, sem ROMs, BIOS, credenciais ou ferramentas internas distribuídas.

Atualize em **Configurações → Sistema → Atualizações → Verificar atualizações**. Canal oficial existente; a instalação depende da sua confirmação.

Veja [VALIDACAO.md](https://github.com/GBrum0o0/BRUMCLASSICS/blob/main/releases/v2.1.12/VALIDACAO.md).

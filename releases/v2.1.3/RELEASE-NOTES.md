# BRUMCLASSICS OFICIAL 2.1.3 — Cofre e base ON BRUM

Release oficial do **Launcher PC**, no mesmo GitHub e no fluxo de atualização existente. Beta permanece apenas como codinome de desenvolvimento. Não inclui IPA/APK.

## Atualizar pelo Launcher

Abra **Configurações → Sistema → Atualizações → Verificar → Baixar → Reiniciar e atualizar**.

- Versões oficiais anteriores e a ponte `2.1.0-beta.3` reconhecem esta release diretamente.
- Quem ainda usa `2.1.0-beta.2` recebe primeiro a ponte `2.1.0-beta.3`; depois de reiniciar, verifique novamente para receber `2.1.3`.
- Tag `v2.1.3`, release não prerelease, asset padrão `BRUMCLASSICS-OFICIAL.exe`. O atualizador confere tamanho e SHA-256; mantém o perfil da instalação.

## Save Sync / Cofre

- Importação manual de containers próprios `.onbrum`, com origem, identificação da ROM por SHA-256, mapper, CRC32 e integridade do container verificados. Renomear para `.srm` não converte o formato.
- Importar, definir como ativo e **Aplicar ao BRUM Core…** são três ações separadas. A aplicação aparece para uma revisão autoral escolhida manualmente como ativa e pede confirmação nativa, com Cancelar como padrão.
- O jogo precisa estar fechado. O host usa o mesmo bloqueio exclusivo da sessão e recusa destino ou origem modificados depois da confirmação.
- O principal substituído fica em cópia de recuperação exclusiva. O Cofre, armazenamento de origem e backup anterior não são apagados. Principal corrupto ou ausente com backup exige recuperação explícita.
- Isolamento por perfil, caminhos Unicode longos, conflitos preservados e ausência de migração automática. Saves externos continuam no formato e fluxo existentes.
- Mantém a correção de catálogo da 2.1.2, inclusive a regressão sintética de Pokémon FireRed: o Cofre não depende da categoria antiga nem de uma cópia desatualizada da biblioteca.

## BRUM Core e ON BRUM: o que está e não está pronto

O host nativo faz parte do Launcher e recebe a API de aplicação/recuperação de containers. Os backends externos existentes e o RetroArch permanecem funcionais e separados da engine autoral.

A ON BRUM interna 0.6.0 acrescenta fetcher e filas de pixels BG/OBJ e corrige headroom da conversão PCM. Diagnósticos locais Red/Yellow preservaram os framebuffers esperados, o ciclo de save/restore do Red e não atingiram os rails PCM nas sessões medidas.

**Isso não libera a ON BRUM para gameplay público nem representa suporte 100% concluído.** O gate de distribuição permanece fechado. Há uma falha independente de fase pós-boot DMG e faltam validação raster/sonora mais ampla, STOP/RTC/conflitos de bus e pontes móveis. Nenhum emulador externo foi renomeado como autoral. A rota pública continua usando os backends existentes; o pacote não contém DLLs de cores, ROMs ou BIOS.

Não adiciona sincronização automática, rede local automática, Gamepad, segunda tela, streaming, conta online ou novos consoles. [Validação e limites](VALIDACAO.md).

# BRUMCLASSICS OFICIAL 2.1.4 — manutenção do BRUM Core PC

Atualização oficial do **Launcher PC**, no mesmo GitHub e pelo atualizador existente. Beta permanece apenas como codinome de desenvolvimento. Não inclui IPA/APK.

## Atualizar pelo aplicativo

Abra **Configurações → Sistema → Atualizações → Verificar → Baixar → Reiniciar e atualizar**.

- Versões oficiais anteriores e a ponte `2.1.0-beta.3` recebem esta versão diretamente.
- A Beta antiga `2.1.0-beta.2` recebe primeiro a ponte `2.1.0-beta.3`. Depois de reiniciar, verifique novamente para receber `2.1.4`.
- Tag `v2.1.4`, publicação oficial não prerelease, executável padrão `BRUMCLASSICS-OFICIAL.exe`. Tamanho e SHA-256 são verificados antes da instalação; o vínculo do perfil é preservado.

## O que mudou

- O host BRUM Core PC incorpora a evolução local da ON BRUM: correções de janela WX0/WX4/WX5/WX6, scroll alto, estágios de leitura gráfica e áudio wave CH3.
- Diagnóstico de áudio ampliado, com resultado por memória e proteção contra falsos positivos quando o processo é interrompido ou retorna estado contraditório.
- BRUMNEWS informa a versão atual e distingue a atualização do Launcher da maturidade da engine autoral.
- Cofre de Saves, perfis e backends externos permanecem no fluxo existente. Importar, ativar e aplicar saves continuam ações separadas, com confirmação, bloqueio exclusivo e cópia anterior preservada.

## Limite importante: não libera gameplay ON BRUM

**A ON BRUM ainda não está pronta para jogar publicamente. Esta atualização não anuncia suporte autoral concluído.** O gate de distribuição permanece fechado, inclusive diante de tentativa de ativação experimental por argumento. Os emuladores externos e o RetroArch continuam disponíveis; nenhum core externo foi renomeado ON BRUM.

Validação independente local: gráficos **12/25 aprovados e 13 divergentes**; Mooneye **93/94 DMG**, com uma falha pós-boot; SameSuite **2/2 DMG**; diagnósticos DMG sound **12/12**. Nove referências gráficas também dependem de dados pós-firmware ausentes no boot simulado; quatro casos autossuficientes continuam falhando. Há regressão conhecida no caso de tamanho OBJ sem scroll, mantida no relatório e não ocultada. Esses números não representam porcentagem de conclusão ou compatibilidade geral de jogos.

O pacote não inclui ROMs, BIOS, saves pessoais, fontes diagnósticos externos ou DLLs de cores. Não adiciona sincronização automática, streaming, novos consoles, conta online, Gamepad ou segunda tela. Publicação somente PC. [Validação e limites](VALIDACAO.md).

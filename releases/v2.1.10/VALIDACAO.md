# Validação — 2.1.10 experimental, Windows PC

## Fontes e escopo

Base interna2.1.9: `0ea716443f6fca8bb7c3e4518b59979d3d22946f`. Fonte final2.1.10: `111d5d0a45ac1a037005e5a7710046f6ec8b0b2d`; árvore `bde8d01757e53936f1e2b4cc5ca28c1be8456623`.

Snapshot Antigravity conferido: `7241a8f5aedde6124875e5b941a33160ffeb505d`, contendo áudio/vídeo GBA/GBC078903f e alteração GB0b6145c. Importado o delta dos quatro arquivos GBA/GBC, com correções locais, e adaptação restrita da mudança PPU GB. Não importados o host antigo, fallback externo, ferramentas internas ou alegações de conclusão total. Raiz do Antigravity/scratch preservados; implementação em worktree isolado.

Usuário autorizou build experimental para testar e corrigir depois. Não é entrega dos32 sistemas concluídos. Nenhuma ROM, BIOS, conta, save ou biblioteca pessoal distribuída.

## Revisão e regressões

Revisor independente retornou quatro problemas concretos Important e foi interrompido antes do relatório final. Portanto, **não há parecer independente final limpo**. Coordenador verificou os achados, corrigiu e testou, sem declarar auditoria concluída:

- FIFO sem temporizador podia crescer indefinidamente: limite32 bytes, com teste100000 escritas sem consumo.
- DirectSound ignorava mute/rotas e master-off: retirado áudio forçado, testes de saída zero.
- Dois sinais positivos podiam somar e virar negativos por overflow: acumulação32 bits e saturação final16 bits, teste127+127.
- DMA1/2 eram presos aos FIFOs A/B e consumiam amostra ao habilitar: refill separado do clock de amostra, destino real, origem fixa/incremental/decremental, repetição e IRQ preservados. Testes DMA1→FIFO B e fonte fixa confirmam comportamento observável, não leitura de registrador write-only.

Seis testes reproduziram esses defeitos antes e passaram depois. Cinco testes adicionais ficaram RED na2.1.9 e GREEN após importação: registradores/FIFO, bitmap4, sprite, sequenciador GBC e amostragem em double-speed. Ajuste da fixture FIFO usa evento de temporizador antes da amostra, sem alterar produção para satisfazer teste.

A remoção ampla do comparador GB no snapshot corrigia o teste novo de coluna, mas quebrou `ppu-window` existente. Não foi dispensado o teste: restringimos a exclusão ao início visível x0, mantendo rematches posteriores. Teste novo confere todos160×144 pixels de BG com janela desligada; os12 testes PPU passaram. Trata-se de modelo de compatibilidade, não prova elétrica de hardware.

Mantidas proteções2.1.9: limites de RAM, bloqueio de reentrada DMA, divisão64 bits, limite defensivo de IRQ e64KiB de `gba-sram-v1`. Host, serviços de saves/Vault e contratos de entrada/vídeo não foram substituídos.

## Suítes e jogos

- Build nativa completa, diagnóstico e observador: exit0, **253 testes nativos aprovados**, gameplayReady=false.
- `npm test`: **837 totais /836 aprovados /0 falhas /1 ignorado** por DLL libretro opcional. Não removida falha para publicar.
- Sintaxe `npm run check`: exit0. Integração de host/captura: **10/10**. Reexecução final do wrapper nativo e integração:14/14.
- Comparação independente Mealybug, mesmo material compilado antes/depois:24 casos,15 aprovados ambos,9 divergências de pixels idênticas ambos, **zero novas regressões**. Os9 não viraram aprovação. Sem firmware executado, sem Acid2 nessa comparação; baseline histórico de25 casos não foi apresentado como execução nova.
- Harness/matriz novos do Antigravity não adotados: caminhos pessoais fixos, escrita truncando relatórios, execução conjunta sem watchdog e flags input/save/timing inferidas sem testes suficientes. Seus rótulos VALIDATED não certificam esta publicação.

Nove ROMs pessoais,600 frames headless cada, saves/capturas exclusivos em pasta temporária. Todos processos exit0; SHA256 das ROMs idêntico antes/depois:

| Sistema / jogo | Cores no frame final | PCM não zerado |
|---|---:|---:|
| GB / Pokémon Red | 4 | 152892 |
| NES / Super Mario Bros.3 | 3 | 721972 |
| GBA / FireRed | 7 | 917642 |
| SNES / Mario World | 1, preto | 0 |
| N64 / Mario64 | 1, preto | 0 |
| DS / Mario64DS | 1, preto | 0 |
| GBC / Crystal | 3 | 197292 |
| GBC / Yellow | 2 | 101370 |
| GBA / Yoshi's Island | 14 | 0 |

Não certifica gameplay, áudio audível/fiel, controles, save do jogo inteiro ou compatibilidade geral. GB Red aos600 frames apresentou80 pixels brancos na primeira coluna tanto antes quanto depois; esse probe não demonstra mudança visual comercial. A regressão sintética comprova o cenário específico de coluna inicial, não eliminação universal de faixas.

## Decisões e pendências explícitas

Não adotada a supressão ampla do comparador PPU porque regrediu teste existente; não adotada a matriz como certificação porque suas métricas não validam os recursos declarados. Custo: o comportamento distribuído difere do relatório de entrega original, e continua parcial.

Pendência menor adiada: acesso byte ao último endereço FIFO B0x040000A7 não encaminhado pelo barramento; caminho DMA32 bits validado. Permanecem reset GBA após Halt, sprites/afinidade/prioridades parciais, protocolos EEPROM/Flash incompletos, áudio NES incorreto e SNES sem áudio; outros sistemas podem continuar pretos. Não incluídos novos recursos de frontend/contas/rede/mobile.

Saves experimentais permanecem separados por perfil/sistema/SHA256 em murb-test-saves. Sem migração automática, aplicação do Vault, save states ou desbloqueios online nesse runtime. Integridade do container não prova fidelidade do core. Originais e perfis preservados; instalação pessoal não executada.

## Pacote

- Build distribuição Windows x64, exit0, versão2.1.10/experimental e fonte interna limpa.
- 188 fontes do ASAR conferidas; QR SVG/PNG, ZIP, Three.js, WebSocket e sessão JS/native/save sintético em cópia isolada, todos aprovados.
- App-ready com perfil temporário, Steam/página do jogo preservados,32 módulos registrados e autoria exclusiva. Primeiro acesso, reabertura, novo download no mesmo caminho, BRUMWORLD e arquivo de perfil preservado passaram. Wrapper registra aviso BigInt; teste separado com executável regular passou.
- ASAR/host extraídos diretamente do portátil conferem com recursos verificados; extração exit0, aviso esperado de dados adicionais do autoextraível.
- Portátil:394352553 bytes, versão2.1.10; SHA256 `eda02f3d08654da8df77898e125ee8187d1c42e12d76c24d8c31786cdf3419c8`.
- ASAR: `4a066405b1a5f32f2c66422210282325dfa187b0a3aa33b5516c602d8513aa09`.
- Host: `fda940059ff698d1b29e3ff8857139e5434b9f6bc94cf87464bc77aa4ffee37b`.

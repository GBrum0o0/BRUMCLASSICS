# RetroAchievements no BRUM Core

## Estado atual

O BRUMCLASSICS integra oficialmente o avaliador nativo `rcheevos` v12.5.0 (revisão `1433173220a7eaede6a9ed7a18e94117be1821e0`, licença MIT) em `shared/brum-core/RetroAchievementsRuntime.{hpp,cpp}` para **PC (`brum-core-pc`)**, **iOS** e **Android** (além da consulta de catálogo pela Web API):

- `login2`/`login` converte usuário e senha em token de runtime armazenado no Keychain (iOS), Android Keystore (`SecureSecretStore`) ou `safeStorage` (PC), sem salvar a senha;
- o hash oficial é calculado via `rc_client`/`rhash` e o mapa de memória Libretro (`SET_MEMORY_MAPS` + fallback `RETRO_MEMORY_SYSTEM_RAM`) é conectado diretamente ao `rc_libretro`;
- `rc_client_do_frame()` é executado quadro a quadro durante emulação normal e avanço rápido, e `rc_client_reset()` acompanha resets e carregamento de save state;
- **Softcore por padrão**: nenhum popup é exibido nem gravado antes de resposta oficial HTTP `200` com `"Success": true` em `r=awardachievement`;
- o popup visual segue o molde horizontal **BRUM CLASSICS** (`#090d0e`, borda `#35413f`, barra lateral `#9dff3b`, ícone vetorial em cartucho, `+N PTS`) no computador, iOS e Android (incluindo sessões Gamepad remoto, com deduplicação por `eventId`);
- **Nintendo 3DS (`Azahar`) não possui suporte oficial a RetroAchievements** nesta versão (`console_id = 0` no runtime nativo móvel/PC), exibindo estado honesto de indisponibilidade sem falsos positivos.

O desbloqueio real em conta de usuário e o registro de jogo/hash/conquista específicos dependem de execução com ROM reconhecida e credenciais reais em conta válida.

## O que falta para ativar desbloqueios

1. Incorporar `rcheevos`/`rc_client` nos dois hosts móveis e gerar o hash RA oficial da mídia. O SHA-256 interno do BRUMCLASSICS continua sendo usado para saves e identidade local, mas não substitui o hash RA.
2. Expor a memória emulada com o mapa Libretro correto e implementar `read_memory`. O runtime precisa ler a memória depois de cada frame.
3. Implementar o transporte HTTPS pedido pelo `rc_client`, com User-Agent versionado e retorno obrigatório de todos os callbacks.
4. Fazer login inicialmente com senha e guardar somente o token retornado, protegido por Android Keystore ou iOS Keychain. A Web API Key existente não é senha nem token de runtime.
5. Identificar e carregar o jogo por `rc_client_begin_identify_and_load_game`, comparando o jogo reconhecido com o vínculo manual já salvo.
6. Executar `rc_client_do_frame` uma vez por frame em velocidade normal e também em avanço rápido.
7. Tratar unlocks, progresso medido, placar, rich presence, queda/reconexão e erros do servidor na interface.
8. Manter Hardcore desativado até a integração ser auditada e validada pelo RetroAchievements. Save states e avanço rápido precisam respeitar as regras do modo antes de habilitá-lo.

## Mapeamento inicial de consoles

| Sistema BRUM | `rcheevos console_id` |
|---|---:|
| Mega Drive/Genesis | 1 |
| Nintendo 64 | 2 |
| SNES | 3 |
| Game Boy | 4 |
| Game Boy Advance | 5 |
| Game Boy Color | 6 |
| NES | 7 |
| PC Engine | 8 |
| Master System | 11 |
| PlayStation | 12 |
| Atari Lynx | 13 |
| Game Gear | 15 |
| GameCube | 16 |
| Nintendo DS | 18 |
| PlayStation 2 | 21 |
| Atari 2600 | 25 |
| Arcade/Neo Geo `.neo` | 27 |
| Saturn | 39 |
| Dreamcast | 40 |
| PSP | 41 |
| Atari 5200 | 50 |
| Atari 7800 | 51 |
| WonderSwan | 53 |
| Nintendo 3DS | 62 |

O ID é apenas uma entrada para o hash e o mapa de memória; ele não prova que a ROM foi reconhecida nem que o core é compatível.

## Critérios para declarar suporte ativo

- a tela informa claramente login, jogo reconhecido e quantidade de conquistas;
- uma ROM alterada ou não reconhecida não reutiliza o ID digitado manualmente;
- nenhum unlock é enviado sem sessão confirmada pelo `rc_client`;
- o runtime processa todos os frames, inclusive durante avanço rápido;
- desconexão não fecha o jogo e erros pendentes são mostrados;
- carregar estado reinicia ou restaura o estado do runtime de forma compatível;
- testes em conta separada confirmam unlock, reconexão e ausência de falsos positivos.

Referências oficiais:

- <https://github.com/RetroAchievements/rcheevos>
- <https://github.com/RetroAchievements/rcheevos/wiki/rc_client-integration>
- <https://github.com/RetroAchievements/rcheevos/blob/master/README.md>
- <https://github.com/RetroAchievements/rcheevos/blob/master/LICENSE>

# Revisão técnica — 2.1.22

Base: `v2.1.21` (`103b904`). Alteração focal para resolver falha de descoberta automática de ROMs novas no startup (`providers: ['retro']` quando o `quick-state` excede `350 ms`), autodetectar pastas locais `games`/`RETROGAMES` ao lado do executável mesmo quando há pasta legada configurada, permitir gerenciar múltiplos diretórios de jogos em **Configurações → CLASSICS** e identificar ISOs Wii/GameCube (inclusive `.nkit.iso`).

Nenhum código privado do core, ferramentas internas, configurações de agentes, ROMs, BIOS, saves pessoais ou tokens foi adicionado ao pacote Windows ou a este repositório público. Permanece a classificação honesta dos 30 grupos estabelecida na `2.1.21`.

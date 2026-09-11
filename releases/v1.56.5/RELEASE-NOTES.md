# BRUMCLASSICS 1.56.5

## Controles personalizados

- Cada dispositivo conectado agora possui o botão **AJUSTAR** em **Configurações → Controles**.
- Um controle genérico pode usar a apresentação PlayStation/DualShock 4, Xbox, Nintendo ou a detecção automática.
- O comando **ESCUTAR** associa o próximo botão físico pressionado a Cruz/A, Círculo/B, gatilhos, direcionais, Share, Options e demais comandos.
- O mapeamento também pode ser alterado diretamente pelo número do botão.
- O perfil fica salvo separadamente para cada dispositivo e adapta os símbolos e a navegação do launcher.

## CLASSICS e RetroArch

- Os botões personalizados e as hotkeys seguras são enviados ao RetroArch em um perfil temporário por sessão.
- O arquivo pessoal `retroarch.cfg` continua intocado.
- O mapeamento cobre até quatro jogadores e preserva a ordem real dos controles ativos.

## Limite de compatibilidade

O BRUMCLASSICS preserva a identidade real do controle e não instala driver virtual. A opção PlayStation adapta o launcher e o RetroArch; ela não transforma o dispositivo em um DualShock 4 para todo o Windows. Jogos externos podem continuar dependendo de suporte nativo, Steam Input ou DS4Windows.

## Validação

- 496 testes automatizados aprovados.
- 21 testes direcionados ao sistema de controles aprovados.
- Sintaxe completa do launcher aprovada.
- Conteúdo empacotado confirmado como edição `official`, versão `1.56.5` e modelo de configurações de controle v3.
- Editor visual validado no Electron em 1280 × 900, inclusive a partir do conteúdo extraído do pacote final.

## Preservação

Contas, biblioteca, coleções, saves, capas, anotações, configurações existentes, Android e iOS permanecem preservados. Perfis antigos de controle são migrados de forma aditiva.

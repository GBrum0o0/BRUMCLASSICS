# BRUMCLASSICS OFICIAL 1.52.0

## BRUMCOMPANION: métricas completas

- FPS real capturado pelo PresentMon durante o processo do jogo.
- Ativação manual em **Configurações → MOVEL → ATIVAR FPS**.
- Executável portátil aceito somente do repositório oficial `GameTechDev/PresentMon` e validado pelo SHA-256 publicado no GitHub.
- O provedor de FPS não instala driver ou serviço e não injeta DLL.
- Uso de GPU por processo e VRAM via contadores nativos do Windows para AMD e Intel.
- NVIDIA continua usando `nvidia-smi` quando disponível e possui fallback para os contadores do Windows.
- Temperatura da CPU via LibreHardwareMonitor/OpenHardwareMonitor já ativos ou ACPI explicitamente identificado como CPU.
- Sensores ausentes ou ambíguos continuam como **indisponíveis**; nenhum valor é estimado.
- BRUMWORLD, BRUMNEWS e linha do tempo atualizadas.

## Como ativar o FPS

1. Abra **Configurações → MOVEL**.
2. Clique em **ATIVAR FPS**.
3. Leia e confirme o download do PresentMon portátil.
4. Inicie um jogo pelo launcher e abra o BRUMCOMPANION no celular.

## Limites honestos

- A temperatura da CPU depende de um sensor que identifique de forma confiável a CPU. O launcher não instala drivers de sensores.
- A temperatura de GPUs AMD/Intel depende de um sensor compatível já exposto por LibreHardwareMonitor/OpenHardwareMonitor; uso e VRAM não dependem disso.
- Jogos que não apresentam frames pelo caminho observado pelo PresentMon mantêm FPS indisponível.
- O aplicativo Android permanece na versão 0.15.0 porque o protocolo móvel já suporta esses campos.

Contas, bibliotecas, coleções, favoritos, capas, anotações, saves, caminhos e configurações existentes são preservados.

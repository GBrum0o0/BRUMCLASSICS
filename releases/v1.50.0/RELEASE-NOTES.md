# BRUMCLASSICS OFICIAL 1.50.0 — BRUMCOMPANION desempenho ao vivo

O BRUMCOMPANION agora acompanha a sessão ativa com métricas reais do computador.

## O que foi adicionado

- CPU total e CPU do processo do jogo.
- RAM total e RAM do processo.
- GPU NVIDIA, temperatura, uso e VRAM quando `nvidia-smi` está disponível.
- Duração da sessão e alternância entre visão simples e detalhada no MOVEL 0.14.0.
- Alerta térmico opcional da GPU em 85 °C.
- Controles para desligar completamente o monitor ou somente o alerta.

## Segurança e limites

A coleta ocorre em worker isolado a cada três segundos e apenas durante uma sessão. Nenhum driver, serviço administrativo ou DLL é instalado ou injetado. PID e detalhes internos do provedor não são transmitidos. Histórico permanece desativado por padrão.

FPS depende do PresentMon e temperatura da CPU depende de um provedor de sensores compatível. Se não houver uma fonte real, o aplicativo mostra **INDISP.**; não apresenta zero falso nem valor simulado. Em GPUs não NVIDIA, as métricas específicas podem permanecer indisponíveis nesta versão.

## Atualização

Instale `BRUMCLASSICS-MOVEL-0.14.0.apk` sobre o aplicativo existente para preservar biblioteca, capas, anotações e galeria offline. O pareamento HTTPS atual continua válido. No desktop, contas, coleções, saves e configurações permanecem no perfil separado do executável.

## Validação

- 438 testes automatizados aprovados no código final.
- Coleta real validada no Windows com CPU Intel e GPU NVIDIA GTX 1050 Ti.
- APK 0.14.0: versionCode 21, Android 8.0+, assinatura v2/v3 preservada e teste da biblioteca aprovado.
- Pacote público auditado com RETROGAMES vazia e sem contas, tokens, biblioteca, saves, logs ou caminhos pessoais.

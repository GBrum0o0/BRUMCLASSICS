# BRUMCLASSICS 1.65.0 — Instalações em tempo real e Console no PC

Esta atualização melhora a resposta do launcher às mudanças nas lojas, elimina a necessidade de provocar o carregamento das capas com o ponteiro e transforma Console no PC em uma central mais completa.

## Monitoramento de instalações

- O monitor passa a reagir às alterações locais das lojas e usa verificações adaptativas em segundo plano.
- Um jogo só deixa de constar como instalado depois de duas verificações negativas, reduzindo falsos estados durante atualizações ou troca de manifestos.
- Steam acompanha apenas arquivos relevantes ao AppID; Epic, GOG, Ubisoft, EA, Amazon Games e Xbox usam as evidências locais realmente disponíveis em cada cliente.
- Conexões mostra o estado do monitor por loja e oferece **VERIFICAR AGORA**.
- Integrações sem uma fonte local conclusiva preservam o último estado em vez de inventar uma desinstalação.

## Capas imediatas

- A arte local original aparece já no primeiro frame da biblioteca.
- Quando a miniatura otimizada fica pronta, ela substitui a arte original sem piscar e sem exigir movimento do mouse.
- Eventos reais de carregamento e erro atualizam o cartão e fornecem um fallback seguro quando necessário.

## Console no PC

- Os modos **Placa de captura** e **Uso remoto oficial** ficam reunidos na mesma central.
- Perfis guardam console, cor, jogo associado, aplicativo auxiliar, preset de imagem, formato, áudio, reconexão e duração do replay.
- A central oferece gravação, replay dos últimos 30 ou 60 segundos, captura de imagem, janela flutuante e tela cheia.
- Há opção de 120 FPS quando o dispositivo oferece suporte e otimização automática para o computador atual.
- O diagnóstico ao vivo informa formato, quadros descartados, áudio, processamento, CPU, memória e estado da GPU sem simular latência física.
- PlayStation Remote Play e Xbox são abertos pelos meios oficiais; o launcher não substitui os aplicativos, contas ou serviços das plataformas.

Android 0.19.0 e iOS 0.10.0 permanecem compatíveis e não precisam de novos pacotes para esta atualização exclusiva do launcher Windows.

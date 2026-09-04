# CLASSICS no iPhone: horas offline e conquistas

iOS **0.5.0 (build 8)** + launcher **1.55.3 ou posterior**.

## Configuração inicial

1. Instale o IPA por Sideloadly/AltStore sobre o app existente, com a mesma conta Apple. Não desinstale para atualizar: isso apagaria o armazenamento local do aplicativo.
2. Instale o RetroArch separadamente. O BRUMCLASSICS não instala drivers, núcleos, ROMs ou BIOS, nem altera configurações/saves do emulador.
3. No RetroArch, habilite **Settings → Playlists → Save runtime log (aggregate)**. Confira **Settings → Directory → Runtime Logs**. Use a pasta agregada, não a subpasta de um núcleo.
4. No BRUMCLASSICS, abra **Perfil → Configurações do app → CLASSICS → Autorizar pasta de logs**. Selecione essa pasta pelo app Arquivos. Se sua instalação do RetroArch não expuser essa pasta ao seletor, a medição não poderá funcionar até escolher uma pasta acessível no emulador. Não há acesso oculto aos dados de outro app no iOS.
5. Em **Início → CLASSICS in every everywhere**, importe uma ROM que você tem direito de usar. Envie-a ao RetroArch e execute-a nele primeiro. Mantenha o mesmo nome de arquivo: os logs usam o nome da ROM sem extensão. Para ZIPs extraídos, importe o arquivo final correspondente; nomes diferentes e ROMs com o mesmo nome-base não podem ser reconciliados por adivinhação.
6. Abra os detalhes desse jogo, escolha **Mesmo jogo no launcher** e salve o vínculo. Com o PC conectado, inicie uma vez pelo botão **Jogar no RetroArch**: isso prepara o contador e registra o ponto de partida no PC. O histórico anterior dos logs não é importado silenciosamente.

## Exemplo: jogar 3 horas fora de casa

- Jogue normalmente, mesmo sem rede local ou sem internet. O RetroArch mede o tempo de execução.
- Ao terminar, use **Close Content** no RetroArch para gravar o arquivo `.lrtl`. Depois retorne ao BRUMCLASSICS.
- O aplicativo lê o aumento do contador e salva as horas no próprio iPhone. Um indicador mostra o tempo local e o que ainda está pendente no PC.
- De volta à rede local, deixe o launcher e o app abertos. A fila é enviada ao reconectar e verificada periodicamente enquanto o app estiver ativo. Também existe **Atualizar horas e conquistas** na página do jogo.
- O PC combina as horas com o registro existente. Reenviar o mesmo contador, inclusive depois de reiniciar ou perder uma resposta, não duplica o tempo.

O iOS não garante execução contínua do BRUMCLASSICS enquanto o RetroArch está aberto ou o telefone está bloqueado. Por isso **não usamos um cronômetro baseado na troca de aplicativos**. Os dados dependem de o RetroArch efetivamente gravar os logs; encerramento abrupto antes dessa gravação pode perder o trecho ainda não registrado.

## Histórico, proteção e limites

- O contador e a fila são persistentes. Nenhum banco do launcher é recriado ou limpo.
- O PC mantém `pocket-playtime.json`, separado da biblioteca, com contadores cumulativos por jogo e perfil. O celular envia apenas identidade e segundos; não envia ROMs, saves ou credenciais RetroAchievements ao PC.
- O primeiro envio de zero, antes de jogar, estabelece a base para somar o próximo tempo móvel. Se o primeiro vínculo ocorrer só depois de jogar, um total global do RetroAchievements pode já conter aquelas horas; nesse caso a reconciliação é conservadora para não contar duas vezes.
- O jogo e o PC ficam vinculados ao registro de horas. Não redirecionamos uma fila antiga para outro jogo, computador ou perfil silenciosamente.
- Se o contador do RetroArch diminuir por restauração/limpeza, paramos de acrescentar horas daquele log. **Reestabelecer ponto de partida** mantém as horas já registradas e começa a medir futuros aumentos do contador atual.
- Se você selecionar outra pasta de logs, os registros já medidos também exigem esse novo ponto de partida. Isso impede importar como sessões novas o histórico de outra pasta.

## Conquistas: diferente das horas

Entre na **mesma conta RetroAchievements no RetroArch, no app e no launcher**. A senha é usada no emulador; no BRUMCLASSICS a Web API Key é somente para consulta e fica no Keychain do iPhone. Associe o ID oficial correto da ROM.

Fora da rede do PC, mas com internet, o RetroArch pode validar conquistas normalmente. O app consulta e guarda o progresso oficial, e o launcher o reconsulta pelo próprio vínculo autenticado quando você retorna à rede local.

**Sem internet não garantimos desbloqueios oficiais.** O RetroAchievements precisa iniciar a sessão online. Eventuais desbloqueios pendentes após uma queda dependem da reconexão do próprio emulador antes de encerrá-lo. O BRUMCLASSICS não converte conquistas declaradas localmente em conquistas oficiais, nem substitui a validação do RetroAchievements.

## Validação

Os testes verificam parsing do formato real `runtime: H:MM:SS`, deltas, persistência, recuperação após reinício, ACK perdido, rejeição de contadores inválidos, autorização de API, isolamento de registros e ausência de duplicação com totais oficiais. A permissão de pasta entre aplicativos e a gravação do RetroArch precisam também de teste no seu iPhone real.

# BRUMCLASSICS MOVEL 0.13.1

Guia compatível com BRUMCLASSICS OFICIAL 1.49.1. Android 8.0 ou superior.

## Instalar e atualizar

Instale o APK 0.13.1 da release oficial sobre o aplicativo existente, sem limpar seus dados. Para próximas versões, use **Perfil → Atualizações**. O Android pede confirmação para instalar: o launcher não atualiza silenciosamente nem exige copiar arquivos manualmente. Se a rede externa estiver indisponível, o launcher pareado pode oferecer o mesmo APK localmente.

## Parear com segurança

1. Abra o launcher atualizado no computador e coloque ambos os aparelhos na mesma rede local confiável.
2. Abra **Configurações → MÓVEL → Conectar novo celular**.
3. No celular, abra **Perfil → Conectar ao launcher** e leia o QR completo. Ele inclui endereço HTTPS, porta, código temporário e identidade do certificado.
4. Ao migrar de versões antigas HTTP para 0.11.0 ou superior, refaça o pareamento uma vez. Não desinstale nem apague os dados.

O código expira. Se expirar, gere outro. Não desative a validação do certificado. Troca de computador/certificado exige novo pareamento. Não exponha a porta do launcher à Internet.

## Início, biblioteca e uso offline

A tela Início destaca o último jogo, Favoritos, Quero jogar e Minha jornada. Depois de sincronizadas, biblioteca, capas, conquistas, estatísticas e anotações permanecem no celular. Fora da rede, mostram a última cópia recebida, não dados em tempo real. Itens ainda não baixados podem ficar indisponíveis offline.

Anotações e Quero jogar editados offline entram em uma fila. Ao retornar à rede com o launcher aberto, as alterações são enviadas. Se os dois aparelhos alterarem o mesmo campo, escolha qual versão preservar; não é necessário limpar o banco.

## B-CARD

Na tela Início, abra **B-CARD** para ver somente jogos cuja instalação foi confirmada pelo launcher. Toque em um jogo, arraste o cartão para cima e solte para enviar a solicitação autenticada ao computador. O launcher valida novamente a identidade e o estado do jogo antes de abrir. Em CLASSICS, escolha Novo jogo, autosave ou save manual. O gesto exige que o computador pareado esteja ligado e na mesma rede; nenhuma execução fica pendente para depois.

## BRUMCOMPANION

Inicie o jogo pelo launcher. O jogo ativo aparece no Companion somente quando tem pelo menos uma anotação (Onde parei, Objetivos, Dicas ou Comandos). Crie a primeira no Perfil do Jogo. O Companion acompanha a sessão detectada, permite editar notas e solicitar capturas para BRUMMOMENTS. Capturar exige computador conectado e jogo ativo; consultar a galeria já sincronizada funciona offline.

## Conquistas e sessões

O móvel recebe os dados do launcher; não autentica suas lojas novamente. Conquistas dependem do suporte da plataforma, privacidade e disponibilidade da API. Atualização em segundo plano não significa desbloqueio instantâneo. No launcher 1.49.1, CLASSICS usam o hash da ROM para localizar o conjunto oficial e explicam quando o arquivo não é reconhecido.

## Botão e gesto Voltar

- Em detalhes, Voltar retorna à seção de origem.
- Em B-CARD e BRUMMOMENTS, fecha somente a camada atual.
- Na Biblioteca, limpa primeiro a pesquisa e depois os filtros.
- Em Estatísticas, Perfil ou Biblioteca, retorna à Início.
- Na Início, pressione novamente dentro de 1,8 segundo para sair.
- Android 13 ou superior usa também o Predictive Back.

## Se não conectar

Confirme mesma rede, launcher aberto, QR recente e permissão de rede privada no Windows. Redes de convidados podem isolar dispositivos. Consulte o diagnóstico no desktop. Não compartilhe códigos, QR ou arquivos de contas. O APK público não contém contas nem ROMs.

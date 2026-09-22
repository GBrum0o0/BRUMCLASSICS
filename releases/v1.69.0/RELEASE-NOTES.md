# BRUMCLASSICS 1.69.0 — Biblioteca persistente

Os jogos já reconhecidos ficam registrados no launcher, sem depender de uma nova resposta da loja para aparecerem a cada abertura.

## Seus jogos e sua organização ficam salvos

- Expiração e renovação do token da Família Steam preservam os cartões, coleções, favoritos, capas e conquistas já armazenadas.
- Respostas vazias ou incompletas não apagam registros previamente confirmados.
- Instalações locais verificadas ficam no catálogo mesmo depois da desinstalação.
- A biblioteca durável é a fonte principal ao abrir; um cache antigo não substitui os dados mais recentes.
- O monitor local preserva a organização e atualiza a versão mais recente da biblioteca, evitando gravações antigas sobre alterações do usuário.

## Verificações em segundo plano

- Cada abertura verifica as lojas conectadas com a biblioteca local já disponível.
- As verificações manuais e o monitoramento local de instalações continuam funcionando.
- Jogos novos de qualquer loja acionam o preparo de capas e catálogos de conquistas pendentes.
- Capas e catálogos válidos já armazenados são reaproveitados; isso não garante que toda imagem secundária ou emblema esteja disponível offline.

## Registro salvo não é licença

- Uma ausência isolada numa consulta completa pede verificação.
- Duas consultas completas sem o jogo sinalizam acesso indisponível, mantendo o cartão.
- Falhas parciais não contam como confirmação de perda de acesso.
- Conexões expiradas e acesso indisponível recebem avisos no cartão.
- As lojas oficiais continuam verificando a licença ao instalar ou jogar.
- Catálogos públicos não confirmados, ferramentas, DLCs, remoções explícitas e isolamento entre contas mantêm as regras existentes.
- Desconectar explicitamente uma loja mantém o comportamento de retirada dos jogos daquela conexão.

## Conquistas e dispositivos móveis

Os catálogos compatíveis de outras fontes continuam permitindo marcação manual quando não há leitura direta. A consulta ao catálogo Steam requer as credenciais Steam já usadas pela integração; não há garantia de catálogo para todo jogo.

Android 0.19.0 e iOS 0.10.0 permanecem sem mudanças de código ou protocolo. Não é necessário instalar um novo APK ou IPA para esta atualização do launcher.

Validação: 588 testes automatizados aprovados, zero falhas, além de verificação visual isolada. Os testes não dependem de alterar as contas reais do usuário.

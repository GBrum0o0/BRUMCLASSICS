# Conexões e origem dos dados

O BRUMCLASSICS mostra somente recursos que cada plataforma oferece por uma API pública, ferramenta autorizada ou evidência local verificável. Uma integração conectada não significa que todas as capacidades estão disponíveis.

## Estados exibidos

- **Conectada:** o vínculo necessário está disponível.
- **Cliente não encontrado:** a conta pode continuar visível pelo cache ou API, mas o aplicativo oficial não foi localizado para jogar.
- **Login necessário:** a credencial ou sessão deve ser renovada; o catálogo anterior permanece salvo.
- **Biblioteca no cache:** a consulta atual falhou e o último snapshot válido continua em uso.
- **Sincronização parcial:** a fonte entregou somente parte do catálogo que consegue comprovar.
- **Monitoramento ativo:** instalações e sessões compatíveis são acompanhadas localmente.

## O que os números significam

- **Propriedade confirmada:** licença informada por uma fonte apropriada para a conta.
- **Instalação detectada:** arquivos ou manifesto encontrados neste computador; isoladamente, isso não comprova propriedade.
- **Assinatura:** acesso condicionado a uma assinatura atualmente identificada.
- **Família Steam:** acesso compartilhado, separado de uma compra da conta.
- **Cache preservado:** registro conhecido de uma sincronização válida anterior.

## Diagnosticar conexão

Em **Configurações → Conexões → Explorar conexões → Detalhes**, o botão **Diagnosticar conexão** verifica cliente, acesso, biblioteca, origem dos jogos e monitoramento. O resultado apresenta uma ação compreensível, como renovar acesso, abrir o cliente ou tentar novamente. Logs técnicos, senhas, tokens e cookies não são exibidos.

As sincronizações entram em uma fila central e são processadas uma por vez. Uma falha não descarta as próximas solicitações. Quando a lista permanece estável, somente cartões modificados são atualizados; adições, remoções ou mudanças de ordem provocam uma reconstrução segura da grade.

## Limites por plataforma

| Plataforma | Fonte principal | Limitação importante |
| --- | --- | --- |
| Steam | Steam Web API e manifestos locais | Biblioteca e conquistas dependem da privacidade e do acesso fornecido pela conta. |
| Epic Games | Legendary, ferramenta de terceiros, e manifestos locais | Epic EOS não oferece a um launcher independente acesso global às conquistas da conta. |
| GOG | Cache e banco local somente leitura | O Galaxy SDK é vinculado ao produto do desenvolvedor, não à biblioteca global. |
| Ubisoft Connect | Instalações locais revisadas | Não existe API pública equivalente para biblioteca e conquistas globais de consumidor. |
| EA app | Catálogo e instalações locais verificáveis | O resultado pode ser parcial; instalação e login continuam no cliente oficial. |
| Amazon Games | Cliente oficial e cadastro local | Não existe protocolo público por jogo ou API pública global adequada. |

O launcher não reutiliza sessões privadas, não consulta endpoints internos e não transforma presença de arquivos em falsa propriedade.

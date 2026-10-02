# Jogar os jogos do PC no celular

O Gaming Mode oferece a ação simples **jogo → jogar no celular**, mas mantém responsabilidades claras:

1. O BRUMCLASSICS valida o aparelho, o perfil e a instalação do jogo.
2. O launcher inicia o jogo no computador.
3. Sunshine transmite vídeo e áudio do PC.
4. Moonlight recebe a imagem e envia o controle.

## Preparação única

- Instale e configure o [Sunshine](https://github.com/LizardByte/Sunshine) no computador.
- Instale o [Moonlight](https://moonlight-stream.org/) no Android ou iPhone e faça o pareamento inicial com o Sunshine.
- No launcher, abra **Configurações → Móvel → Gaming Mode** e use **Diagnosticar**.
- Para jogar fora de casa, instale o Tailscale no PC e no celular e mantenha os dois na mesma rede privada.

Depois disso, abra o Gaming Mode, escolha um jogo instalado no computador e toque em **Jogar no celular**. O BRUMCLASSICS inicia o jogo e abre o cliente disponível. No iOS, quando a versão instalada do Moonlight não aceitar abertura por URL, o sistema abre a página oficial do aplicativo; então basta selecionar o computador já pareado.

## Segurança

- A ponte móvel continua protegida por TLS e token individual revogável.
- O comando de início expira rapidamente e não pode ser repetido.
- O QR pode guardar os endereços local e Tailscale, sempre vinculados à mesma impressão do certificado.
- Não encaminhe a porta da ponte BRUMCLASSICS no roteador e não a publique na internet.
- Credenciais do Sunshine, lojas e Tailscale não são copiadas para o BRUMCLASSICS.

## Limites honestos

Sunshine, Moonlight e Tailscale são aplicativos independentes e não acompanham o APK ou IPA. O primeiro pareamento do Moonlight com Sunshine continua sendo feito no cliente oficial. Qualidade e latência dependem do computador, codificador da GPU, rede e aparelho.

# Atualizações no iPhone com SideStore

O BRUMCLASSICS+ iOS oferece suporte a **atualizações diretamente no iPhone via SideStore**, mantendo também a instalação tradicional de `.ipa` via **Sideloadly**.

## Endereço oficial da fonte SideStore

```text
https://raw.githubusercontent.com/GBrum0o0/BRUMCLASSICS/sidestore-source/sidestore-source.json
```

A fonte aponta exclusivamente para releases oficiais `ios-v*` do BRUMCLASSICS no GitHub (nunca `/releases/latest`, que pertence ao Launcher Windows), e só é atualizada depois que o `.ipa` é compilado, verificado (`validate_ipa.py`), publicado e conferido quanto a HTTP `200`, tamanho exato e `SHA-256`.

---

## Configuração inicial (apenas na primeira vez)

Para que o SideStore assine e atualize aplicativos no iPhone sem depender de PC nas próximas versões, é necessária uma configuração inicial única seguindo a documentação oficial do SideStore (<https://docs.sidestore.io/>):

1. No computador, instale o **SideStore** no iPhone usando o **AltServer / Jitterbugpair** (ou ferramenta recomendada na documentação atual do SideStore) para gerar o **arquivo de pareamento** do aparelho com a sua conta Apple.
2. No iPhone, instale o **StosVPN** (App Store oficial, listado na documentação do SideStore) e mantenha-o disponível para criar a conexão de loopback local quando for atualizar ou renovar assinaturas.
3. No SideStore, importe o arquivo de pareamento gerado e toque em **Sources → +**, colando a URL oficial acima (ou toque em **Abrir fonte oficial no SideStore** dentro de **Perfil → Atualização no iPhone** no BRUMCLASSICS).

Depois dessa configuração inicial, consultar atualizações e instalar novas versões `ios-v*` do BRUMCLASSICS é feito pelo próprio iPhone com o **StosVPN** ativado e acesso à internet.

---

## Como preservar seus saves ao migrar do Sideloadly

No iOS, dois instaladores de sideload só compartilham o mesmo container de dados se preservarem exatamente o mesmo **Bundle ID** efetivo (`com.brumclassics.mobile.ios`) e o mesmo certificado/equipe da conta Apple. O SideStore e o Sideloadly podem alterar ou acrescentar sufixo de equipe ao Bundle ID, caso em que o iOS trata o app como outro identificador e **não transfere os saves automaticamente**.

**Antes de remover ou substituir o app instalado pelo Sideloadly:**

1. Abra **Perfil → Atualização no iPhone → Backup de saves para migração (Sideloadly → SideStore)** no BRUMCLASSICS atual.
2. Toque em **Exportar backup verificado** e escolha uma pasta em **Arquivos** ou **iCloud Drive**. O app gera `BRUMCLASSICS-Backup-<data>/` com checksum `SHA-256` verificado de cada save (`IntegratedEmulator/Saves`, incluindo `PSP/SAVEDATA` e vínculos JSON de `ClassicsEverywhere`, sem exportar segredos do Keychain).
3. Instale o BRUMCLASSICS pela fonte oficial no SideStore.
4. Caso os saves não tenham sido mantidos no container, abra o mesmo menu de **Backup para migração**, toque em **Restaurar backup verificado** e selecione a pasta salva no passo 2.

---

## Limitações da assinatura gratuita da Apple

- Contas Apple gratuitas assinam aplicativos por **7 dias** e contam com o limite imposto pela Apple de até **3 aplicativos ativos** e **10 App IDs** por janela de 7 dias.
- O **SideStore** permite renovar a assinatura dos 7 dias pelo próprio iPhone (e tentar renovações em segundo plano quando o iOS agenda e o StosVPN/rede atendem às condições), **mas não remove a validade de 7 dias da Apple** nem garante renovação automática se o iPhone ficar sem rede local/VPN ou sem execução em segundo plano.
- Caso o certificado de 7 dias expire antes da renovação, conecte ao **StosVPN** e toque em **Refresh All** no SideStore (ou reenvie o pairing se a Apple invalidar a sessão).

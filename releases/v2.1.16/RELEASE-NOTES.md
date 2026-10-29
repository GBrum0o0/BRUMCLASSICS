# BRUMCLASSICS OFICIAL 2.1.16 — interface e Brum iOS Bridge

Atualização oficial do Launcher PC, disponível pelo verificador de atualizações do aplicativo.

- **Configurações:** o painel aparece acima dos detalhes do jogo. Abrir e fechar as Configurações preserva as anotações que estavam sendo editadas.
- **Jogos modernos:** os blocos Últimas Atividades e Saves deixam de aparecer nos detalhes. Os Clássicos mantêm essas informações.
- **Fundo dinâmico:** as cores acompanham a arte do jogo selecionado com transição suave, incluindo imagens recebidas após a abertura da biblioteca. As opções de Economia, animação reduzida e fundo desativado continuam respeitadas.
- **Brum iOS Bridge:** nova seção nas Configurações para importar uma cópia de IPAs, localizar o iPhone, autenticar a conta Apple na interface e gerenciar assinatura, instalação e renovação.

## Brum iOS Bridge — estado e limites

O componente foi compilado e testado; a detecção real por USB e a leitura dos aplicativos instalados foram verificadas sem alterar o iPhone. **Login Apple real, assinatura, instalação/atualização preservando dados, Wi-Fi e renovação física ainda não foram validados em aparelho.** A validação autenticada foi adiada pelo usuário. Esta publicação permite continuar esses testes, sem anunciar o Bridge como substituto já comprovado do Sideloadly.

O login e os códigos da Apple são informados somente na interface do Launcher. É necessário autorizar um provedor anisette de confiança; o componente usa implementações comunitárias dos protocolos da Apple, e não um SDK oficial de assinatura para Windows.

A renovação automática é opcional e vem desativada. Exige Launcher aberto, sessão Apple autenticada e iPhone alcançável. A senha e a sessão ficam somente em memória: após fechar o aplicativo, é necessário entrar novamente. A validade é lida do perfil emitido pela Apple; as tentativas ocorrem nas últimas 24 horas, com intervalo mínimo de 15 minutos após uma falha. Não há promessa de renovação com o PC desligado.

Não há desinstalação automática nem revogação de certificados para liberar espaço. As IPAs originais permanecem intactas. Os fontes do helper, fontes do assinador LGPL, instruções de reconstrução e avisos das 386 dependências fixadas são distribuídos junto ao componente.

## Verificação e preservação

Suíte completa: 884 testes do Launcher, sendo 883 aprovados, zero falhas e um teste opcional ignorado. Também foram executados testes visuais em Electron, testes nativos Rust, testes direcionados de atualização e perfis, e revisão independente.

Os saves, o Save Vault, as bibliotecas e os perfis existentes são preservados. Contas, ROMs, BIOS, saves e ferramentas pessoais de agentes não fazem parte da publicação. [Relatório de validação](VALIDACAO.md).

Esta release contém somente o Launcher Windows x64; não inclui nova IPA ou APK. Os emuladores não foram alterados nesta etapa e mantêm as limitações experimentais da versão 2.1.14. A publicação não certifica uso pleno dos 32 sistemas. A compatibilidade de anotações com aplicativos móveis antigos continua descrita nas [notas da versão 2.1.15](../v2.1.15/RELEASE-NOTES.md).

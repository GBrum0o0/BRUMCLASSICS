# BRUMCLASSICS MÓVEL iOS 0.13.1

## Correção de acesso às ROMs

- Corrige o aviso de falta de permissão ao iniciar uma ROM no BRUM Core.
- Downloads, iCloud Drive e outros provedores passam a ser lidos com `NSFileCoordinator`, como exigido pelo seletor de documentos do iOS.
- O bookmark existente da pasta é preservado e renovado quando estiver desatualizado.
- A ROM original continua intacta; apenas uma cópia temporária protegida é usada durante a execução.
- A tela de erro agora oferece **Reautorizar pasta** para recuperar o acesso sem procurar a configuração manualmente.

O IPA é arm64, sem assinatura e deve ser assinado pelo Sideloadly ou AltStore.

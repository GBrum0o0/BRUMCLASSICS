# BRUMCLASSICS MÓVEL iOS 0.13.5

## Fundação do Gaming Mode

- GB, GBC e GBA agora recebem uma identidade estável pelo conteúdo da ROM, independente do nome e da pasta.
- O cabeçalho real do jogo tem prioridade sobre a extensão do arquivo.
- O BRUM Core escolhe o núcleo por um registro versionado que declara sistema, versão e licença.
- Saves passam a usar o hash do jogo, evitando colisões entre arquivos com o mesmo nome.
- Cada save possui manifesto com geração, integridade, sistema, core e dispositivo.
- Saves antigos são migrados por cópia na primeira abertura; o original permanece disponível para recuperação.
- O cálculo de identidade acontece fora da interface, sem travar a tela durante a preparação.

O IPA é arm64, sem assinatura, e deve ser assinado pelo Sideloadly ou AltStore.

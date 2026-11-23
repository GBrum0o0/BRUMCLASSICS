# BRUMCLASSICS OFICIAL 2.1.35 — validação da integração

Integração da Extensão 001 sobre a base PC 2.1.34, preservando os núcleos, assets livres, Cemu gerenciado, Save Vault, atualizador e iOS Bridge existentes. A interface privada Electron não integra o repositório público; o fonte correspondente necessário ao host nativo acompanha a release.

## Código e evidências

- Fonte PC: `7a9e75c87758e8993c382f724d9711e56e7966bb`; código do host compilado: `b95f7cb5dc6a901edb4d0cc0f8eb6ded2fbbfd08`.
- Build C++ executado com Visual Studio 2022. Adaptador FireRed: **115 verificações aprovadas**.
- Suíte Node após build: **78 testes aprovados, zero falhas e zero ignorados**. Inclui contratos da Pokédex, bridge, host, configuração, RetroAchievements e atualizador. O teste com ROM FireRed usa boot headless e saves de teste isolados; não comprova captura em gameplay.
- Interface Electron com preload e serviços reais: oito verificações aprovadas com dados sintéticos e capturas inspecionadas, cobrindo abertura/fechamento, espécie oculta, normal/shiny, ativação e troca de perfil.
- Paridade entre fonte e pacote: **206 arquivos da interface, 859 arquivos do iOS Bridge e 241 arquivos do host** conferidos byte a byte.
- Runtime: **3.047 arquivos verificados** contra manifesto revisado; **33 entradas de sistema encontradas em perfil vazio**, sem depender de caminhos de desenvolvimento ou RetroArch externo. Presença de núcleo não certifica jogabilidade dos 33 sistemas.
- Host distribuído executou `--self-test` com sucesso; dependências Node, geração QR e dez DLLs MSVC adjacentes conferidas.
- Arquivo de fontes: CRC e 243 fontes/avisos comparados independentemente à árvore correspondente; 246 entradas incluindo licença GPL, instruções e revisão. Ausência de interface Electron privada, ROMs, BIOS, saves pessoais e ferramentas de agentes conferida.

## Artefato PC

`BRUMCLASSICS-OFICIAL.exe`: 682.453.954 bytes.

SHA-256: `12ef3886e96d25226381217381a79849ebeeb755f9337315524b762f56b473bd`.

Host nativo: `3c908566be17d90918966168e211c5c22b74186d1954e371f0dfe21417a5d71f`.

Os demais hashes estão em `SHA256SUMS.txt`. O pacote de fontes e `SOURCE-REFERENCES.json` preservam os avisos, receitas e referências dos componentes de terceiros.

## Mobile correspondente

Fonte público compartilhado: `05d6c53a932487da1113e0997bc88edf8803a38c`.

- [iOS CI](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/45100509964): componentes compartilhados, modelos/navegação no simulador, compilação Release, núcleos e empacotamento aprovados. IPA oficial **0.26.0 / 59**, 15.497.788 bytes, SHA-256 `ef4ef9b2a92ffd66b2f34c18995ea57bde38d6744973649a92f49b41099a99d5`. Fonte SideStore conferida com os mesmos tamanho/hash e histórico preservado.
- [Android CI](https://github.com/GBrum0o0/BRUMCLASSICS/actions/runs/45100510034): build completo, verificação dos núcleos e contratos aprovados. APK **0.35.0 / 47**, 27.573.799 bytes, SHA-256 `7acb9e4caddfcf44fc37d94aa549567801149e371d9e4f279b61b0e38888082f`.
- Certificado Android mantido: `abd2913f77da03b82b3792f58fee044787855e0ed56af0b26f21a8a3ff0634b8`; assinaturas v2/v3 verificadas.
- Catálogo e licença PokeAPI nos APK/IPA comparados byte a byte à fonte; ambos contêm 802 espécies. Testes automatizados não equivalem a teste no aparelho físico.

## Limites

A captura automática continua um piloto FireRed BPRE, com gameplay/captura/popup real e uso entre aparelhos físicos pendentes. Os demais jogos necessitam adaptadores e validação. Arte ilustrativa não é catálogo de sprites oficiais. Descobertas da Pokédex não equivalem a conquistas RetroAchievements.

Revisão independente do código, arquivo de fontes e executável **aprovada**. No pacote final, QA conferiu separadamente as paridades de 206 arquivos da interface e 241 fontes do host, licenças, manifesto idêntico ao revisado, 33 sistemas/27 motores, 38 amostras de integridade, autoteste e hash do portátil. Os 3.047 hashes foram verificados integralmente pelo coordenador; QA não apresentou essa execução como própria. A inspeção final foi retomada após o fim do limite temporário de uso, com a mesma configuração de agente.

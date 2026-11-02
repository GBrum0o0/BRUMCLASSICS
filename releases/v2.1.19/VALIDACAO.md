# Validação da versão 2.1.19

## Verificações direcionadas

- PSP: 1.056 combinações válidas de EXT/INS; base publicada com 1.025 divergências, integração isolada sem divergências. Campos de 32 bits incluídos. Regressão adicional com origem e destino no mesmo registrador.
- Neo Geo Pocket: base com 255/256 leituras incorretas do registro de controle; hunk isolado sem divergências, preservando endereço vizinho e estado da persistência.
- Integração direcionada PSP/NGP: 12 testes aprovados, incluindo as duas novas regressões.
- Catálogo/perfis, identificação, serviço e adaptador de controles: revisão independente com 33 testes aprovados; entradas raw, cabeçalhos truncados/falsos, arquivos ausentes e formatos sem leitor são exercitados sem modificar as entradas.
- Candidato completo do Antigravity: compilação MSVC C++17 /W4 /WX, 438 testes sintéticos aprovados em cópia externa; nenhum jogo comercial foi certificado por esse resultado.

## Build e pacote

- Suíte nativa integrada: **357 testes aprovados**, exit 0, `gameplayReady=false`, MSVC C++17 /W4 /WX /O2 /MP4. Os 118 arquivos de entrada não mudaram durante o build.
- Suíte completa do Launcher: **946 testes, 945 aprovados, zero falhas e um opcional ignorado**. Inclui os testes Windows de troca/reinicialização e preservação de perfil. Na primeira execução da base houve um timeout de handoff; o grupo passou isolado e novamente na suíte final, sem alteração do atualizador.
- Host recompilado com as duas mudanças isoladas: SHA-256 `38f793d53d6754df36ea67344d7faea64dd2fdfcb5f8335dffa11e5cde1e4604`.
- Comparação com a base 2.1.18: nenhum diff de host, armazenamento, API da engine, GB/GBC/GBA/NES ou iOS Bridge.
- Build oficial Windows aprovado. Os **196 arquivos da aplicação** no ASAR final correspondem aos fontes validados; edição official, versão 2.1.19.
- Pacote final: execução sintética GB e commit de save isolado aprovados; QR/ZIP/Three/WebSocket carregam pelo ASAR isolado.
- Recuperação GBA empacotada aprovada: cancelar preserva o original, confirmação cria backup verificado e um slot Flash128 separado, reutilizado no próximo lançamento.
- PSP e Neo Geo Pocket empacotados: lançamento sintético pelo serviço do Launcher, encerramento normal, caminhos de save isolados e entradas preservadas. Descoberta/hash de cartucho e catálogo carregados do próprio ASAR conferidos.
- Executável oficial: **410.447.604 bytes**. SHA-256: `a616560e0eb36e807b15010920eb738601253a6c6198b362755554a02ba600f0`.
- Auditoria independente do portátil: **866 arquivos extraídos**, nenhum ausente ou divergente; fontes adicionais privadas e ferramentas pessoais ausentes do ASAR. Os 859 arquivos de fontes/licenças do iOS Bridge são idênticos aos da 2.1.18; 386 dependências e 758 hashes de avisos/licenças conferidos. Helper preservado: SHA-256 `c02c7ab76ed79903a4f3d17f207e60d7cc43e87c6e4c32d091e924b2770fd817`.

## Limites

Os testes de CPU/barramento e de integração não confirmam partidas completas ou fidelidade audiovisual. Catálogos de controles e hashes não comprovam suporte de todos os sistemas. Nenhum save real, ROM ou BIOS pessoal foi alterado. Instalação no iPhone e renovação do iOS Bridge continuam pendentes de validação no aparelho.

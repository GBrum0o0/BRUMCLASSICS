# BRUMCLASSICS OFICIAL 2.1.47 — Revogação Confirmada no Brum iOS Bridge + Melhorias 2.1.46

- **Brum iOS Bridge — Controle explícito no limite de certificados Apple (erro `7460`):**
  - Quando a conta Apple atinge o limite máximo de certificados ativos (por exemplo, após uso do SideStore ou Sideloadly), o Brum iOS Bridge passa a exibir a lista de certificados encontrados e permite escolher explicitamente qual certificado revogar (**Revogar e continuar**) ou **Cancelar** sem alterar nenhum certificado.
  - Preserva a proteção contra revogação automática silenciosa.
- **Inclui integralmente todas as melhorias da versão `2.1.46`:**
  - Correção gráfica do Nintendo GameCube (`dolphin_libretro.dll`) sem tela preta/piscadas e em 4:3 autêntico.
  - Transição suave entre a intro e os jogos (`DwmFlush` + revelação no 1º quadro visível).
  - Otimizações na **MURB Engine** e no Launcher Desktop (caches persistentes em disco e contenção em segundo plano).
  - Nomenclatura oficial **BRUMCLASSICS+** / **MURB Engine**, catálogo Pokédex enriquecido (`809` espécies) e adaptador Gen 4 **Pokémon Platinum (`CPUE`)**.

Atualize pelo botão **Verificar** no Launcher ou pelo executável oficial desta release. Jogos, ROMs, BIOS, configurações e saves existentes são preservados.

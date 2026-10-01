package com.brumclassics.mobile.classics;

import java.io.ByteArrayInputStream;

public final class ClassicsRulesTest {
    public static void main(String[] args) throws Exception {
        if (!ClassicsRules.accepts("Chrono Trigger (USA).sfc")) throw new AssertionError("Extensão válida recusada");
        if (ClassicsRules.accepts("save.srm")) throw new AssertionError("Save aceito como ROM");
        if (!"Chrono Trigger".equals(ClassicsRules.cleanTitle("001 - Chrono_Trigger (USA) [!].sfc"))) throw new AssertionError("Título não foi limpo");
        if (!"pokemon versao".equals(ClassicsRules.normalizedTitle("Pokémon_Versão.gba"))) throw new AssertionError("Título não foi normalizado");
        if (ClassicsRules.parseRuntimeSeconds("{\"runtime\":\"12:34:56\"}") != 45_296L) throw new AssertionError("Runtime incorreto");
        if (!"Jogo.lrtl".equals(ClassicsRules.runtimeLogName("Jogo.gba"))) throw new AssertionError("Nome do log incorreto");
        java.util.List<String> art = java.util.Arrays.asList("Named_Boxarts/Chrono Trigger (Japan).png", "Named_Boxarts/Chrono Trigger (USA).png");
        if (!"Named_Boxarts/Chrono Trigger (USA).png".equals(ClassicsRules.matchArtwork("Chrono Trigger (USA).sfc", art))) throw new AssertionError("Capa regional incorreta");
        byte[] rom = new byte[512]; rom[0xB2] = (byte) 0x96;
        EmulationIdentity first = EmulationIdentity.inspect(new ByteArrayInputStream(rom), "renamed.gb");
        EmulationIdentity second = EmulationIdentity.inspect(new ByteArrayInputStream(rom), "another.gba");
        if (!"gba".equals(first.systemId) || !"header".equals(first.detectionSource)) throw new AssertionError("Cabeçalho GBA não detectado");
        if (!first.canonicalGameId().equals(second.canonicalGameId())) throw new AssertionError("ID mudou após renomear a ROM");
        if (!"mgba".equals(CoreRegistry.retroArchCore(first.systemId, "renamed.gb"))) throw new AssertionError("Core incorreto");
        if (!CoreRegistry.supportsIntegrated("gba", "renamed.gba")) throw new AssertionError("GBA deveria usar o BRUM Core");
        if (CoreRegistry.supportsIntegrated("sfc", "game.sfc")) throw new AssertionError("SNES ainda deve usar o fallback");
        SaveManifest manifest = SaveManifest.next(null, first, "mgba", "save-a", 32, 1000, "phone");
        SaveManifest same = SaveManifest.next(manifest, first, "mgba", "save-a", 32, 2000, "phone");
        SaveManifest changed = SaveManifest.next(same, first, "mgba", "save-b", 32, 3000, "phone");
        if (manifest.generation != 1 || same.generation != 1 || changed.generation != 2) throw new AssertionError("Geração de save incorreta");
        System.out.println("ClassicsRulesTest: OK");
    }
}

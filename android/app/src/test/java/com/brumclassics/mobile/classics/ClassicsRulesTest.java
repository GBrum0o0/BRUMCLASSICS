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
        if (!"libmgba_libretro.so".equals(CoreRegistry.integratedCore("gba", "renamed.gba").androidLibraryName)) throw new AssertionError("Biblioteca integrada incorreta");
        if (!CoreRegistry.supportsIntegrated("nds", "game.nds")) throw new AssertionError("Nintendo DS deveria usar o BRUM Core");
        if (!"libskyemu_libretro.so".equals(CoreRegistry.integratedCore("nds", "game.nds").androidLibraryName)) throw new AssertionError("Biblioteca SkyEmu incorreta");
        byte[] ps2 = new byte[4096]; System.arraycopy("BOOT2".getBytes(java.nio.charset.StandardCharsets.US_ASCII), 0, ps2, 1024, 5);
        EmulationIdentity ps2Identity = EmulationIdentity.inspect(new ByteArrayInputStream(ps2), "game.iso");
        if (!"ps2".equals(ps2Identity.systemId)) throw new AssertionError("Imagem de PS2 não detectada pelo conteúdo");
        if (!CoreRegistry.supportsIntegrated("ps2", "game.iso")) throw new AssertionError("PS2 deveria usar Play! no Android");
        if (!"play_libretro_android.so".equals(CoreRegistry.integratedCore("ps2", "game.iso").androidLibraryName)) throw new AssertionError("Biblioteca Play! incorreta");
        if (CoreRegistry.integratedCore("", "ambiguous.iso") != null) throw new AssertionError("ISO ambígua não pode ser classificada apenas pela extensão");
        EmulationIdentity neoGeo = EmulationIdentity.inspect(new ByteArrayInputStream(new byte[] {1, 2, 3}), "game.neo");
        if (!"neogeo".equals(neoGeo.systemId) || !CoreRegistry.supportsIntegrated("neogeo", "game.neo")) throw new AssertionError("Neo Geo deveria usar Geolith");
        if (!"libgeolith_libretro.so".equals(CoreRegistry.integratedCore("neogeo", "game.neo").androidLibraryName)) throw new AssertionError("Biblioteca Geolith incorreta");
        if (!"libgearsystem_libretro.so".equals(CoreRegistry.integratedCore("sms", "game.sms").androidLibraryName)) throw new AssertionError("Master System deveria usar Gearsystem");
        if (!"libgearsystem_libretro.so".equals(CoreRegistry.integratedCore("gg", "game.gg").androidLibraryName)) throw new AssertionError("Game Gear deveria usar Gearsystem");
        if (!"libnestopia_libretro.so".equals(CoreRegistry.integratedCore("nes", "game.nes").androidLibraryName)) throw new AssertionError("NES deveria usar Nestopia UE");
        if (!"libmednafen_pce_fast_libretro.so".equals(CoreRegistry.integratedCore("pce", "game.pce").androidLibraryName)) throw new AssertionError("PC Engine deveria usar Beetle PCE Fast");
        if (!"libbsnes_mercury_performance_libretro.so".equals(CoreRegistry.integratedCore("sfc", "game.sfc").androidLibraryName)) throw new AssertionError("SNES deveria usar bsnes-mercury Performance");
        if (!CoreRegistry.supportsIntegrated("smc", "game.smc")) throw new AssertionError("Super Famicom .smc deveria usar o BRUM Core");
        SaveManifest manifest = SaveManifest.next(null, first, "mgba", "save-a", 32, 1000, "phone");
        SaveManifest same = SaveManifest.next(manifest, first, "mgba", "save-a", 32, 2000, "phone");
        SaveManifest changed = SaveManifest.next(same, first, "mgba", "save-b", 32, 3000, "phone");
        if (manifest.generation != 1 || same.generation != 1 || changed.generation != 2) throw new AssertionError("Geração de save incorreta");
        System.out.println("ClassicsRulesTest: OK");
    }
}

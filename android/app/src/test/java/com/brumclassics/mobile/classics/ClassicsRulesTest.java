package com.brumclassics.mobile.classics;

public final class ClassicsRulesTest {
    public static void main(String[] args) {
        if (!ClassicsRules.accepts("Chrono Trigger (USA).sfc")) throw new AssertionError("Extensão válida recusada");
        if (ClassicsRules.accepts("save.srm")) throw new AssertionError("Save aceito como ROM");
        if (!"Chrono Trigger".equals(ClassicsRules.cleanTitle("001 - Chrono_Trigger (USA) [!].sfc"))) throw new AssertionError("Título não foi limpo");
        if (!"pokemon versao".equals(ClassicsRules.normalizedTitle("Pokémon_Versão.gba"))) throw new AssertionError("Título não foi normalizado");
        if (ClassicsRules.parseRuntimeSeconds("{\"runtime\":\"12:34:56\"}") != 45_296L) throw new AssertionError("Runtime incorreto");
        if (!"Jogo.lrtl".equals(ClassicsRules.runtimeLogName("Jogo.gba"))) throw new AssertionError("Nome do log incorreto");
        java.util.List<String> art = java.util.Arrays.asList("Named_Boxarts/Chrono Trigger (Japan).png", "Named_Boxarts/Chrono Trigger (USA).png");
        if (!"Named_Boxarts/Chrono Trigger (USA).png".equals(ClassicsRules.matchArtwork("Chrono Trigger (USA).sfc", art))) throw new AssertionError("Capa regional incorreta");
        System.out.println("ClassicsRulesTest: OK");
    }
}

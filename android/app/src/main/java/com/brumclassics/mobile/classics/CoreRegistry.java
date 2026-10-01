package com.brumclassics.mobile.classics;

public final class CoreRegistry {
    private CoreRegistry() {}

    public static String retroArchCore(String systemId, String filename) {
        if ("gba".equals(systemId)) return "mgba";
        if ("gb".equals(systemId) || "gbc".equals(systemId)) return "gambatte";

        String extension = ClassicsRules.extension(filename);
        if ("gba".equals(extension)) return "mgba";
        if ("gb".equals(extension) || "gbc".equals(extension)) return "gambatte";
        if ("nes".equals(extension)) return "mesen";
        if ("sfc".equals(extension) || "smc".equals(extension)) return "snes9x";
        if ("n64".equals(extension) || "z64".equals(extension) || "v64".equals(extension)) return "mupen64plus_next";
        if ("nds".equals(extension)) return "melondsds";
        if ("sms".equals(extension) || "gg".equals(extension) || "md".equals(extension) || "gen".equals(extension)) return "genesis_plus_gx";
        if ("pce".equals(extension)) return "mednafen_pce_fast";
        return null;
    }
}

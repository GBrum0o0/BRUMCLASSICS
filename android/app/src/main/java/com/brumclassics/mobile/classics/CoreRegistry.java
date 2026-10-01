package com.brumclassics.mobile.classics;

public final class CoreRegistry {
    public static final class Descriptor {
        public final String id;
        public final String displayName;
        public final String version;
        public final String license;
        public final String androidLibraryName;
        private final String[] systems;

        Descriptor(String id, String displayName, String version, String license,
                   String androidLibraryName, String... systems) {
            this.id = id;
            this.displayName = displayName;
            this.version = version;
            this.license = license;
            this.androidLibraryName = androidLibraryName;
            this.systems = systems;
        }

        boolean supports(String systemId) {
            for (String system : systems) if (system.equals(systemId)) return true;
            return false;
        }
    }

    public static final Descriptor MGBA = new Descriptor(
        "mgba", "mGBA", "7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6", "MPL-2.0",
        "libmgba_libretro.so", "gb", "gbc", "gba"
    );
    private static final Descriptor[] INTEGRATED = { MGBA };

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

    public static boolean supportsIntegrated(String systemId, String filename) {
        return integratedCore(systemId, filename) != null;
    }

    public static Descriptor integratedCore(String systemId, String filename) {
        String resolved = systemId == null || systemId.isEmpty() ? ClassicsRules.extension(filename) : systemId;
        for (Descriptor descriptor : INTEGRATED) if (descriptor.supports(resolved)) return descriptor;
        return null;
    }
}

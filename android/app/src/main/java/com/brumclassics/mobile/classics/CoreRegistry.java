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
    public static final Descriptor SKYEMU = new Descriptor(
        "skyemu", "SkyEmu", "36771a16bfde7eb5c1c0315877b5e465e6f38858", "MIT",
        "libskyemu_libretro.so", "nds"
    );
    public static final Descriptor PLAY = new Descriptor(
        "play", "Play!", "83700b2c31e593bc94e845b4b31b797be84dda59", "BSD-2-Clause",
        "play_libretro_android.so", "ps2"
    );
    public static final Descriptor GEOLITH = new Descriptor(
        "geolith", "Geolith", "194024931935eff2092e36fc4f8e53e62ed11097", "BSD-3-Clause",
        "libgeolith_libretro.so", "neogeo"
    );
    public static final Descriptor GEARSYSTEM = new Descriptor(
        "gearsystem", "Gearsystem", "2d9106f2063d1a6e0661cc8938bb7f8eb737bcae", "GPL-3.0-or-later",
        "libgearsystem_libretro.so", "sms", "gg"
    );
    public static final Descriptor NESTOPIA = new Descriptor(
        "nestopia", "Nestopia UE", "8f00f500912a847062de432e38765c7285483e62", "GPL-2.0-or-later",
        "libnestopia_libretro.so", "nes"
    );
    public static final Descriptor BEETLE_PCE_FAST = new Descriptor(
        "beetle-pce-fast", "Beetle PCE Fast", "3f946f277aef3aa99a95551618bbcd1dd2bda0d9", "GPL-2.0-or-later",
        "libmednafen_pce_fast_libretro.so", "pce"
    );
    public static final Descriptor BSNES_MERCURY = new Descriptor(
        "bsnes-mercury-performance", "bsnes-mercury Performance", "79d7f9de218b6ffa65a80bbdc5828532bc239232", "GPL-3.0",
        "libbsnes_mercury_performance_libretro.so", "sfc", "smc"
    );
    private static final Descriptor[] INTEGRATED = { MGBA, SKYEMU, PLAY, GEOLITH, GEARSYSTEM, NESTOPIA, BEETLE_PCE_FAST, BSNES_MERCURY };

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
        if ("sms".equals(extension) || "gg".equals(extension)) return "gearsystem";
        if ("md".equals(extension) || "gen".equals(extension)) return "genesis_plus_gx";
        if ("pce".equals(extension)) return "mednafen_pce_fast";
        if ("elf".equals(extension) || "isz".equals(extension) || "ps2".equals(systemId)) return "play";
        if ("neo".equals(extension) || "neogeo".equals(systemId)) return "geolith";
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

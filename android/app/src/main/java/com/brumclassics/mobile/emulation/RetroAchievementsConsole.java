package com.brumclassics.mobile.emulation;

/** Console identifiers defined by the official rcheevos rc_consoles.h API. */
public final class RetroAchievementsConsole {
    private RetroAchievementsConsole() {}

    public static int idForSystem(String systemId) {
        if (systemId == null) return 0;
        switch (systemId.toLowerCase(java.util.Locale.ROOT)) {
            case "md": return 1;
            case "n64": return 2;
            case "sfc": return 3;
            case "gb": return 4;
            case "gba": return 5;
            case "gbc": return 6;
            case "nes": return 7;
            case "pce": return 8;
            case "segacd": return 9;
            case "32x": return 10;
            case "sms": return 11;
            case "psx": return 12;
            case "lynx": return 13;
            case "gg": return 15;
            case "nds": return 18;
            case "a2600": return 25;
            case "neogeo": return 27;
            case "saturn": return 39;
            case "dreamcast": return 40;
            case "psp": return 41;
            case "ws":
            case "wsc": return 53;
            // RetroAchievements has no official memory/achievement runtime for Nintendo 3DS.
            case "3ds":
            default: return 0;
        }
    }
}

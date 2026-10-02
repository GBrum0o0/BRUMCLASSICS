package com.brumclassics.mobile.emulation;

/** Console identifiers defined by the official rcheevos rc_consoles.h API. */
public final class RetroAchievementsConsole {
    private RetroAchievementsConsole() {}

    public static int idForSystem(String systemId) {
        if (systemId == null) return 0;
        switch (systemId) {
            case "sfc": return 3;
            case "gb": return 4;
            case "gba": return 5;
            case "gbc": return 6;
            case "nes": return 7;
            case "pce": return 8;
            case "sms": return 11;
            case "gg": return 15;
            case "nds": return 18;
            case "neogeo": return 27;
            case "ws":
            case "wsc": return 53;
            default: return 0;
        }
    }
}

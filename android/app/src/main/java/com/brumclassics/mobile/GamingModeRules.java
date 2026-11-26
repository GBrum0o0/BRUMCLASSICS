package com.brumclassics.mobile;

import com.brumclassics.mobile.classics.ClassicsRules;
import com.brumclassics.mobile.model.Game;
import java.util.List;

/** Shared eligibility for Gaming Mode shelves, restored details and local links. */
final class GamingModeRules {
    static final String LABEL_AVAILABLE = "Disponível";
    static final String LABEL_ON_COMPUTER = "No computador";
    static final String LABEL_IN_CLOUD = "Na nuvem";
    static final String LABEL_DOWNLOADING = "Baixando";
    static final String LABEL_INCOMPATIBLE = "Incompatível";

    public enum AvailabilityState {
        AVAILABLE(LABEL_AVAILABLE, "green"),
        ON_COMPUTER(LABEL_ON_COMPUTER, "gray"),
        IN_CLOUD(LABEL_IN_CLOUD, "cloud_blue"),
        DOWNLOADING(LABEL_DOWNLOADING, "amber"),
        INCOMPATIBLE(LABEL_INCOMPATIBLE, "muted_red");

        public final String label;
        public final String colorToken;

        AvailabilityState(String label, String colorToken) {
            this.label = label;
            this.colorToken = colorToken;
        }
    }

    static AvailabilityState resolveAvailability(boolean isClassic, boolean installedLocally,
                                                 boolean availableInCloud, boolean downloading,
                                                 boolean supportedOnMobile) {
        if (!supportedOnMobile) return AvailabilityState.INCOMPATIBLE;
        if (downloading) return AvailabilityState.DOWNLOADING;
        if (installedLocally) return AvailabilityState.AVAILABLE;
        if (isClassic && availableInCloud) return AvailabilityState.IN_CLOUD;
        return AvailabilityState.ON_COMPUTER;
    }

    private GamingModeRules() {}

    static String availabilityLabel(boolean availableOnPhone) {
        return availableOnPhone ? LABEL_AVAILABLE : LABEL_ON_COMPUTER;
    }

    static boolean isDesktopPlatform(String platform) {
        if (platform == null) return false;
        String lower = platform.trim().toLowerCase(java.util.Locale.ROOT);
        if (lower.isEmpty()) return false;
        String norm = ClassicsRules.normalizedPlatform(lower);
        switch (lower) {
            case "pc": case "windows": case "win": case "win32": case "win64":
            case "steam": case "epic": case "epic games": case "gog":
            case "ea": case "ea app": case "origin":
            case "ubisoft": case "ubisoft connect": case "battlenet": case "battle.net":
            case "amazon": case "amazon games": case "microsoft store": case "xbox app":
            case "xbox": case "xbox one": case "xbox series": case "xbox series x": case "xbox series s":
            case "ps4": case "ps5": case "playstation 4": case "playstation 5":
            case "switch": case "nintendo switch":
                return true;
            default:
                break;
        }
        return "pc".equals(norm) || "windows".equals(norm) || "steam".equals(norm)
            || "ps4".equals(norm) || "ps5".equals(norm) || "switch".equals(norm);
    }

    static boolean includes(String category, boolean installed) {
        return installed && "classic".equals(category);
    }

    static boolean includes(String category, String platform, boolean installed) {
        return includes(category, installed) && !isDesktopPlatform(platform);
    }

    static boolean includes(Game game) {
        if (game == null || !includes(game.category, game.platform, game.installed)) return false;
        String title = game.title == null ? "" : game.title.trim().toLowerCase(java.util.Locale.ROOT);
        return !title.endsWith(".exe");
    }

    static Game launcherGameFor(String title, String systemId, String launcherGameId, List<Game> games) {
        if (!launcherGameId.isEmpty()) for (Game game : games)
            if ("classic".equals(game.category) && !isDesktopPlatform(game.platform) && game.id.equals(launcherGameId)) return game;
        String wanted = ClassicsRules.normalizedTitle(title);
        if (wanted.isEmpty()) return null;
        Game platformMatch = null;
        Game titleMatch = null;
        int titleCount = 0;
        for (Game game : games) {
            if (!"classic".equals(game.category) || isDesktopPlatform(game.platform)) continue;
            if (!ClassicsRules.normalizedTitle(game.title).equals(wanted)) continue;
            if (ClassicsRules.platformMatches(systemId, game.platform)) {
                if (platformMatch == null || (!platformMatch.installed && game.installed)) platformMatch = game;
            }
            titleMatch = game;
            titleCount++;
        }
        if (platformMatch != null) return platformMatch;
        return titleCount == 1 ? titleMatch : null;
    }

    static String normalizeSearch(String value) {
        if (value == null) return "";
        String decomposed = java.text.Normalizer.normalize(value, java.text.Normalizer.Form.NFD);
        String stripped = decomposed.replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
        return stripped.toLowerCase(java.util.Locale.ROOT).trim().replaceAll("\\s+", " ");
    }

    static String canonicalConsoleKey(String platform) {
        if (platform == null) return "unidentified";
        String lower = platform.trim().toLowerCase(java.util.Locale.ROOT).replace('_', ' ').replaceAll("\\s+", " ");
        if (lower.isEmpty() || "unknown".equals(lower) || "unidentified".equals(lower)
            || "classic".equals(lower) || "retro".equals(lower) || "auto".equals(lower)
            || "other".equals(lower) || "outros".equals(lower)) {
            return "unidentified";
        }
        String norm = ClassicsRules.normalizedPlatform(lower);
        if ("psx".equals(norm)) return "ps1";
        if ("sfc".equals(norm)) return "snes";
        if (norm.isEmpty() || "unknown".equals(norm) || "classic".equals(norm)) return "unidentified";
        return norm;
    }

    static String consoleDisplayName(String consoleKey) {
        if (consoleKey == null) return "Não identificado";
        switch (consoleKey) {
            case "all": return "Todos os consoles";
            case "unidentified": return "Não identificado";
            case "gb": return "Game Boy";
            case "gbc": return "Game Boy Color";
            case "gba": return "Game Boy Advance";
            case "nds": case "ds": return "Nintendo DS";
            case "3ds": return "Nintendo 3DS";
            case "nes": return "NES";
            case "snes": case "sfc": return "Super Nintendo";
            case "n64": return "Nintendo 64";
            case "gamecube": return "GameCube";
            case "wii": return "Nintendo Wii";
            case "wiiu": return "Wii U";
            case "ps1": case "psx": return "PlayStation";
            case "ps2": return "PlayStation 2";
            case "psp": return "PSP";
            case "md": return "Mega Drive";
            case "sms": return "Master System";
            case "gg": return "Game Gear";
            case "segacd": return "Sega CD";
            case "32x": return "Sega 32X";
            case "saturn": return "Sega Saturn";
            case "dreamcast": return "Dreamcast";
            case "pce": return "PC Engine";
            case "neogeo": return "Neo Geo";
            case "ngp": return "Neo Geo Pocket";
            case "ws": return "WonderSwan";
            case "wsc": return "WonderSwan Color";
            case "atari2600": return "Atari 2600";
            case "arcade": return "Arcade";
            default: return consoleKey.toUpperCase(java.util.Locale.ROOT);
        }
    }

    static boolean matchesFilter(String title, String platform, String query, String consoleKey) {
        if (consoleKey != null && !"all".equals(consoleKey) && !consoleKey.isEmpty()) {
            if (!canonicalConsoleKey(platform).equals(consoleKey)) return false;
        }
        String q = normalizeSearch(query);
        if (q.isEmpty()) return true;
        return normalizeSearch(title).contains(q);
    }
}

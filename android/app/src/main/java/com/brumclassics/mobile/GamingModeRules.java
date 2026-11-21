package com.brumclassics.mobile;

import com.brumclassics.mobile.classics.ClassicsRules;
import com.brumclassics.mobile.model.Game;
import java.util.List;

/** Shared eligibility for Gaming Mode shelves, restored details and local links. */
final class GamingModeRules {
    static final String LABEL_AVAILABLE = "Disponível";
    static final String LABEL_ON_COMPUTER = "No computador";

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
}

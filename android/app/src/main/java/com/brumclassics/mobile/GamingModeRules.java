package com.brumclassics.mobile;

import com.brumclassics.mobile.classics.ClassicsRules;
import com.brumclassics.mobile.model.Game;
import java.util.List;

/** Shared eligibility for Gaming Mode shelves, restored details and local links. */
final class GamingModeRules {
    private GamingModeRules() {}

    static boolean includes(String category, boolean installed) {
        return installed && "classic".equals(category);
    }

    static Game launcherGameFor(String title, String systemId, String launcherGameId, List<Game> games) {
        if (!launcherGameId.isEmpty()) for (Game game : games)
            if ("classic".equals(game.category) && game.id.equals(launcherGameId)) return game;
        String wanted = ClassicsRules.normalizedTitle(title);
        if (wanted.isEmpty()) return null;
        Game platformMatch = null;
        Game titleMatch = null;
        int titleCount = 0;
        for (Game game : games) {
            if (!"classic".equals(game.category)) continue;
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

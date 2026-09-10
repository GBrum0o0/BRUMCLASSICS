package com.brumclassics.mobile.data;

import com.brumclassics.mobile.model.Game;
import java.time.Instant;
import java.util.List;

public final class HomeLibrary {
    private HomeLibrary() {}

    public static Game lastPlayed(List<Game> games) {
        if (games == null || games.isEmpty()) return null;
        Game selected = games.get(0);
        long selectedAt = timestamp(selected.lastPlayedAt);
        for (Game game : games) {
            long candidateAt = timestamp(game.lastPlayedAt);
            if (candidateAt > selectedAt) { selected = game; selectedAt = candidateAt; }
        }
        return selected;
    }

    static long timestamp(String value) {
        try { return value == null || value.isEmpty() ? 0 : Instant.parse(value).toEpochMilli(); }
        catch (Exception ignored) { return 0; }
    }
}

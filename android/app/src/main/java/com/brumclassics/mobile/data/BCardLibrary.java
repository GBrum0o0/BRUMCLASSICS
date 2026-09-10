package com.brumclassics.mobile.data;

import com.brumclassics.mobile.model.Game;
import java.util.ArrayList;
import java.util.List;

public final class BCardLibrary {
    private BCardLibrary() {}
    public static List<Game> installed(List<Game> games, String category) {
        List<Game> selected = new ArrayList<>();
        if (games != null) for (Game game : games) {
            if (game != null && game.installed && game.category.equals(category)) selected.add(game);
        }
        return selected;
    }
}

package com.brumclassics.mobile.data;

import com.brumclassics.mobile.model.Game;
import java.util.Arrays;
import java.util.List;

public final class BCardLibraryTest {
    private static Game game(String id, String platform, String category, boolean installed) {
        return new Game(id, id, "", platform, "Aventura", Game.Status.BACKLOG, 0, 0, false,
            0, 0, "custom-cover", installed, null, false, false, "notes", "", "", "", 0, "",
            true, true, 0, "", "", category);
    }
    public static void main(String[] args) {
        Game modern = game("pc", "PC", "modern", true);
        Game classic = game("rom", "PC", "classic", true);
        Game explicitModern = game("modern-ps", "PS1", "modern", true);
        Game oldClassic = game("old", "Game Boy Advance", "", true);
        Game uninstalled = game("missing", "PS2", "classic", false);
        List<Game> all = Arrays.asList(modern, classic, explicitModern, oldClassic, uninstalled);
        if (!BCardLibrary.installed(all, "modern").equals(Arrays.asList(modern, explicitModern))) throw new AssertionError("JOGOS não segue a categoria oficial");
        if (!BCardLibrary.installed(all, "classic").equals(Arrays.asList(classic, oldClassic))) throw new AssertionError("CLASSICS não segue categoria/cache antigo");
        if (!BCardLibrary.installed(null, "classic").isEmpty()) throw new AssertionError("Lista ausente");
        if (all.size() != 5 || !classic.favorite || !"notes".equals(classic.whereStopped) || !"custom-cover".equals(classic.artworkPath)) throw new AssertionError("Dados modificados pelo filtro");
        System.out.println("BCardLibraryTest: OK");
    }
}

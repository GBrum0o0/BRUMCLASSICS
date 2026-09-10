package com.brumclassics.mobile.data;

import com.brumclassics.mobile.model.Game;
import java.util.Arrays;

public final class HomeLibraryTest {
    private static Game game(String id, String lastPlayedAt) {
        return new Game(id, id, "", "PC", "Jogo", Game.Status.PLAYING, 0, 0, true,
            0, 0, "", false, null, true, false, "", "", "", "", 0, "",
            false, false, 0, "", lastPlayedAt);
    }

    public static void main(String[] args) {
        Game older = game("antigo", "2026-08-01T12:00:00Z");
        Game latest = game("recente", "2026-08-29T18:30:00Z");
        Game invalid = game("invalido", "não é uma data");
        if (HomeLibrary.lastPlayed(Arrays.asList(older, invalid, latest)) != latest) throw new AssertionError("A Home não escolheu a sessão mais recente.");
        if (HomeLibrary.timestamp("inválido") != 0) throw new AssertionError("Data inválida não usa fallback seguro.");
        System.out.println("HomeLibraryTest: OK");
    }
}

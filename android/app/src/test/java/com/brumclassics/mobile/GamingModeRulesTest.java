package com.brumclassics.mobile;

import com.brumclassics.mobile.model.Game;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class GamingModeRulesTest {
    private static Game game(String id, String title, String platform, String category, boolean installed) {
        return new Game(id, title, "", platform, "Jogo", Game.Status.PLAYING, 0, 0, false,
                0, 0, "", installed, null, true, false, "", "", "", "", 0, "",
                false, false, 0, "", "", category);
    }

    public static void main(String[] args) {
        for (String category : Arrays.asList("modern", "steam", "pc", "", null)) {
            if (GamingModeRules.includes(category, true)) throw new AssertionError("Non-Classic installed entry shown: " + category);
        }
        if (GamingModeRules.includes("classic", false)) throw new AssertionError("Unavailable desktop Classic shown");
        if (!GamingModeRules.includes("classic", true)) throw new AssertionError("Installed Classic missing");

        Game modern = game("steam:1", "Adventure", "GBA", "modern", true);
        Game installed = game("classic:1", "Adventure", "GBA", "classic", true);
        Game unavailable = game("classic:2", "Adventure", "GBA", "classic", false);
        List<Game> cached = new ArrayList<>(Arrays.asList(modern, unavailable, installed));
        List<Game> original = new ArrayList<>(cached);
        for (int refresh = 0; refresh < 3; refresh++) {
            Game linked = GamingModeRules.launcherGameFor("Adventure", "gba", modern.id, cached);
            if (linked != installed) throw new AssertionError("Stale non-Classic link must fall back to installed Classic");
            if (!cached.equals(original)) throw new AssertionError("Desktop cache changed during selection");
        }
        if (GamingModeRules.launcherGameFor("Adventure", "gba", modern.id, Arrays.asList(modern)) != null)
            throw new AssertionError("Stale non-Classic ID linked");
        if (GamingModeRules.launcherGameFor("Adventure", "gba", "", Arrays.asList(modern)) != null)
            throw new AssertionError("Matching platform bypassed Classic category");
        if (GamingModeRules.launcherGameFor("Adventure", "gba", unavailable.id, cached) != unavailable)
            throw new AssertionError("Existing Classic link changed");
        if (GamingModeRules.launcherGameFor("Adventure", "gba", "", Arrays.asList(unavailable, installed)) != installed)
            throw new AssertionError("Installed Classic preference lost");
        Game otherPlatform = game("classic:3", "Adventure", "SNES", "classic", true);
        if (GamingModeRules.launcherGameFor("Adventure", "gba", "", Arrays.asList(otherPlatform)) != otherPlatform)
            throw new AssertionError("Unique Classic title fallback lost");
        if (GamingModeRules.launcherGameFor("Adventure", "nes", "", Arrays.asList(otherPlatform, installed)) != null)
            throw new AssertionError("Ambiguous Classic titles linked");
        if (GamingModeRules.launcherGameFor("", "gba", "", cached) != null)
            throw new AssertionError("Empty title linked");

        for (String desktopPlatform : Arrays.asList("PC", "Windows", "Steam", "Epic Games", "PlayStation 5", "Switch")) {
            Game mislabeled = game("pc:" + desktopPlatform, "Jogo PC", desktopPlatform, "classic", true);
            if (GamingModeRules.includes(mislabeled)) {
                throw new AssertionError("Desktop/modern platform shown in Gaming Mode: " + desktopPlatform);
            }
        }
        Game exeClassic = game("pc:exe", "Setup.exe", "GBA", "classic", true);
        if (GamingModeRules.includes(exeClassic)) throw new AssertionError("Windows executable shown in Gaming Mode");
        Game pspClassic = game("pc:psp", "God of War", "PSP", "classic", true);
        if (!GamingModeRules.includes(pspClassic)) throw new AssertionError("PC Classic PSP missing");
        if (!"Disponível".equals(GamingModeRules.availabilityLabel(true))) throw new AssertionError("Wrong local label");
        if (!"No computador".equals(GamingModeRules.availabilityLabel(false))) throw new AssertionError("Wrong PC label");
        System.out.println("GamingModeRulesTest: OK (Classics-only cache, stale links, platform matching and existing fallbacks)");
    }
}

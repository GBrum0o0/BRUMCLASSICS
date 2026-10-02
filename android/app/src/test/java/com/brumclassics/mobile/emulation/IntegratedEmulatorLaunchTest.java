package com.brumclassics.mobile.emulation;

import java.io.File;

public final class IntegratedEmulatorLaunchTest {
    public static void main(String[] args) {
        File directory = new File("saves");
        IntegratedEmulatorLaunch launch = new IntegratedEmulatorLaunch(
            "game-1", "Jogo", "gba:abc123", "gba", "abc123", "mgba", "mGBA",
            "7a12d6d4b9acb14c0ae62c9166b6a2f3d08007f6", "libmgba_libretro.so", 1234,
            new File("roms/game.gba"), "", new File(directory, "abc123.srm"),
            new File(directory, "abc123.save.json"), new File("system"));

        assertEquals(new File(directory, "abc123.slot1.state"), launch.quickStateFile(1));
        assertEquals(new File(directory, "abc123.slot2.state"), launch.quickStateFile(2));
        assertEquals(new File(directory, "abc123.slot3.state"), launch.quickStateFile(3));
        if (launch.retroAchievementsGameId != 1234) throw new AssertionError("ID RetroAchievements não foi preservado.");
        if (RetroAchievementsConsole.idForSystem("gba") != 5) throw new AssertionError("Console GBA incorreto.");
        if (RetroAchievementsConsole.idForSystem("neogeo") != 27) throw new AssertionError("Console Arcade/Neo Geo incorreto.");
        System.out.println("IntegratedEmulatorLaunchTest: OK");
    }

    private static void assertEquals(File expected, File actual) {
        if (!expected.equals(actual)) throw new AssertionError("Esperado " + expected + ", recebido " + actual);
    }
}

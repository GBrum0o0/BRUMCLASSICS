package com.brumclassics.mobile.emulation;

import java.io.File;

public final class IntegratedEmulatorLaunchTest {
    public static void main(String[] args) {
        File directory = new File("saves");
        IntegratedEmulatorLaunch launch = new IntegratedEmulatorLaunch(
            "game-1", "Jogo", "gba:abc123", "gba", "abc123", "mgba",
            new File("roms/game.gba"), new File(directory, "abc123.srm"),
            new File(directory, "abc123.save.json"), new File("system"));

        assertEquals(new File(directory, "abc123.slot1.state"), launch.quickStateFile(1));
        assertEquals(new File(directory, "abc123.slot2.state"), launch.quickStateFile(2));
        assertEquals(new File(directory, "abc123.slot3.state"), launch.quickStateFile(3));
        System.out.println("IntegratedEmulatorLaunchTest: OK");
    }

    private static void assertEquals(File expected, File actual) {
        if (!expected.equals(actual)) throw new AssertionError("Esperado " + expected + ", recebido " + actual);
    }
}

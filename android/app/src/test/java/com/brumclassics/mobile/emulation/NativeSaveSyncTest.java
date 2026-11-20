package com.brumclassics.mobile.emulation;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class NativeSaveSyncTest {
    public static void main(String[] args) throws Exception {
        // Cross-platform vector matching PC (native-save-revision.js) and iOS (NativeSaveTransfer.revision)
        String expectedVectorRev = "native:v2:f6a38b604731f64c1f5648b461fb78aafe65139426cab5e9d682d920e371d149";
        String saveASha256 = "ecb10d6167fd4cca49af084b27578db864c7c995068f558f785225f289d6f1ec";
        assertEquals(expectedVectorRev, NativeSaveSync.revisionForBatterySave("game.srm", saveASha256, 6));
        assertEquals(expectedVectorRev, NativeSaveSync.revisionForBatterySave(saveASha256 + ".srm", saveASha256, 6));

        // Classification matrix
        assertAction(NativeSaveSync.Action.IN_SYNC, NativeSaveSync.classifySync("", "", ""));
        assertAction(NativeSaveSync.Action.IN_SYNC, NativeSaveSync.classifySync("rev-1", "rev-1", ""));
        assertAction(NativeSaveSync.Action.DOWNLOAD, NativeSaveSync.classifySync("", "rev-2", ""));
        assertAction(NativeSaveSync.Action.UPLOAD, NativeSaveSync.classifySync("rev-1", "", ""));
        assertAction(NativeSaveSync.Action.DOWNLOAD, NativeSaveSync.classifySync("rev-1", "rev-2", "rev-1"));
        assertAction(NativeSaveSync.Action.UPLOAD, NativeSaveSync.classifySync("rev-2", "rev-1", "rev-1"));
        assertAction(NativeSaveSync.Action.CONFLICT, NativeSaveSync.classifySync("rev-2", "rev-3", "rev-1"));
        assertAction(NativeSaveSync.Action.CONFLICT, NativeSaveSync.classifySync("rev-a", "rev-b", ""));

        // Atomic installation + previous save backup preservation + hash mismatch protection
        File dir = Files.createTempDirectory("brum-android-save-sync-").toFile();
        try {
            File target = new File(dir, "test.srm");
            File inA = new File(dir, "inA.bin");
            try (FileOutputStream out = new FileOutputStream(inA)) {
                out.write("SAVE-A".getBytes(StandardCharsets.UTF_8));
            }
            if (!NativeSaveSync.installBatterySaveAtomically(inA, saveASha256, target)) {
                throw new AssertionError("Esperado retorno true ao instalar save inicial.");
            }
            assertEquals("SAVE-A", new String(Files.readAllBytes(target.toPath()), StandardCharsets.UTF_8));
            if (NativeSaveSync.installBatterySaveAtomically(inA, saveASha256, target)) {
                throw new AssertionError("Esperado retorno false para instalação idempotente.");
            }

            File inB = new File(dir, "inB.bin");
            try (FileOutputStream out = new FileOutputStream(inB)) {
                out.write("SAVE-B-NEXT".getBytes(StandardCharsets.UTF_8));
            }
            String hashB = NativeSaveSync.sha256Hex(inB);
            if (!NativeSaveSync.installBatterySaveAtomically(inB, hashB, target)) {
                throw new AssertionError("Esperado retorno true ao atualizar save.");
            }
            assertEquals("SAVE-B-NEXT", new String(Files.readAllBytes(target.toPath()), StandardCharsets.UTF_8));
            File backup = new File(dir, "test.srm.previous");
            if (!backup.isFile()) throw new AssertionError("Backup anterior não foi preservado.");
            assertEquals("SAVE-A", new String(Files.readAllBytes(backup.toPath()), StandardCharsets.UTF_8));

            boolean failed = false;
            try {
                NativeSaveSync.installBatterySaveAtomically(inA, "0".repeat(64), target);
            } catch (IllegalStateException expected) {
                failed = true;
            }
            if (!failed) throw new AssertionError("Hash divergente deveria ter falhado.");
            assertEquals("SAVE-B-NEXT", new String(Files.readAllBytes(target.toPath()), StandardCharsets.UTF_8));
        } finally {
            File[] children = dir.listFiles();
            if (children != null) for (File child : children) child.delete();
            dir.delete();
        }
        System.out.println("NativeSaveSyncTest: OK");
    }

    private static void assertEquals(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("Esperado [" + expected + "], recebido [" + actual + "]");
        }
    }

    private static void assertAction(NativeSaveSync.Action expected, NativeSaveSync.Action actual) {
        if (expected != actual) {
            throw new AssertionError("Esperado " + expected + ", recebido " + actual);
        }
    }
}

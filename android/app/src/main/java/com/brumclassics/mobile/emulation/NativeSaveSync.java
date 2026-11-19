package com.brumclassics.mobile.emulation;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.text.Normalizer;
import java.util.Locale;

public final class NativeSaveSync {
    public enum Action {
        IN_SYNC,
        UPLOAD,
        DOWNLOAD,
        CONFLICT
    }

    private NativeSaveSync() {}

    public static Action classifySync(String localRevision, String remoteRevision, String baseRevision) {
        String local = localRevision == null ? "" : localRevision.trim();
        String remote = remoteRevision == null ? "" : remoteRevision.trim();
        String base = baseRevision == null ? "" : baseRevision.trim();
        if (local.isEmpty() && remote.isEmpty()) return Action.IN_SYNC;
        if (local.equals(remote)) return Action.IN_SYNC;
        if (local.isEmpty()) return Action.DOWNLOAD;
        if (remote.isEmpty()) return Action.UPLOAD;
        if (!base.isEmpty()) {
            if (local.equals(base)) return Action.DOWNLOAD;
            if (remote.equals(base)) return Action.UPLOAD;
        }
        return Action.CONFLICT;
    }

    public static String sha256Hex(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                if (read > 0) digest.update(buffer, 0, read);
            }
        }
        StringBuilder result = new StringBuilder(64);
        for (byte value : digest.digest()) {
            result.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        }
        return result.toString();
    }

    public static String revisionForBatterySave(String name, String sha256Hex, long sizeBytes) throws Exception {
        if (name == null || name.isEmpty() || sha256Hex == null || !sha256Hex.matches("(?i)[0-9a-f]{64}") || sizeBytes <= 0) {
            throw new IllegalArgumentException("Metadados de save nativo inválidos para revisão.");
        }
        String normalized = Normalizer.normalize(name, Normalizer.Form.NFC);
        String lower = normalized.toLowerCase(Locale.ROOT);
        String role = lower.endsWith(".srm") ? "battery.srm"
                : (lower.endsWith(".rtc") ? "clock.rtc" : normalized);
        byte[] roleBytes = role.getBytes(StandardCharsets.UTF_8);

        ByteArrayOutputStream frame = new ByteArrayOutputStream(20 + 8 + roleBytes.length + 32 + 8);
        frame.write("BRUM-NATIVE-SAVE-V2".getBytes(StandardCharsets.US_ASCII));
        frame.write(0);
        writeUInt32BE(frame, 1);
        writeUInt32BE(frame, roleBytes.length);
        frame.write(roleBytes);
        String lowerHex = sha256Hex.toLowerCase(Locale.ROOT);
        for (int i = 0; i < 64; i += 2) {
            int high = Character.digit(lowerHex.charAt(i), 16);
            int low = Character.digit(lowerHex.charAt(i + 1), 16);
            frame.write((high << 4) | low);
        }
        writeUInt64BE(frame, sizeBytes);

        byte[] digest = MessageDigest.getInstance("SHA-256").digest(frame.toByteArray());
        StringBuilder rev = new StringBuilder("native:v2:");
        for (byte b : digest) {
            rev.append(String.format(Locale.ROOT, "%02x", b & 0xff));
        }
        return rev.toString();
    }

    public static boolean installBatterySaveAtomically(File incomingBytes, String expectedSha256, File targetSaveFile) throws Exception {
        if (incomingBytes == null || !incomingBytes.isFile() || incomingBytes.length() <= 0) {
            throw new IllegalArgumentException("Arquivo de save recebido inválido ou vazio.");
        }
        if (expectedSha256 == null || !expectedSha256.matches("(?i)[0-9a-f]{64}")) {
            throw new IllegalArgumentException("Checksum SHA-256 esperado inválido.");
        }
        String normalizedExpected = expectedSha256.toLowerCase(Locale.ROOT);
        String incomingHash = sha256Hex(incomingBytes);
        if (!normalizedExpected.equals(incomingHash)) {
            throw new IllegalStateException("O save recebido falhou na verificação de integridade SHA-256.");
        }
        File parent = targetSaveFile.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
            throw new IllegalStateException("Não foi possível preparar a pasta de saves.");
        }
        if (targetSaveFile.isFile() && normalizedExpected.equals(sha256Hex(targetSaveFile))) {
            return false;
        }

        File stagedTemp = new File(parent, targetSaveFile.getName() + ".incoming.tmp");
        try {
            try (FileInputStream input = new FileInputStream(incomingBytes);
                 FileOutputStream output = new FileOutputStream(stagedTemp)) {
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = input.read(buffer)) >= 0) {
                    if (read > 0) output.write(buffer, 0, read);
                }
                output.getFD().sync();
            }
            if (!normalizedExpected.equals(sha256Hex(stagedTemp))) {
                throw new IllegalStateException("Cópia temporária do save corrompida antes da aplicação.");
            }
            if (targetSaveFile.isFile()) {
                File backup = new File(parent, targetSaveFile.getName() + ".previous");
                moveReplacing(targetSaveFile, backup);
            }
            moveReplacing(stagedTemp, targetSaveFile);
            return true;
        } finally {
            if (stagedTemp.exists()) stagedTemp.delete();
        }
    }

    private static void moveReplacing(File source, File destination) throws Exception {
        try {
            Files.move(source.toPath(), destination.toPath(),
                    StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (AtomicMoveNotSupportedException ignored) {
            Files.move(source.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static void writeUInt32BE(ByteArrayOutputStream out, long value) {
        out.write((int) ((value >> 24) & 0xff));
        out.write((int) ((value >> 16) & 0xff));
        out.write((int) ((value >> 8) & 0xff));
        out.write((int) (value & 0xff));
    }

    private static void writeUInt64BE(ByteArrayOutputStream out, long value) {
        for (int shift = 56; shift >= 0; shift -= 8) {
            out.write((int) ((value >> shift) & 0xff));
        }
    }
}

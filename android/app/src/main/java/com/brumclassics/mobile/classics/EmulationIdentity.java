package com.brumclassics.mobile.classics;

import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Locale;

public final class EmulationIdentity {
    public static final int SCHEMA_VERSION = 1;
    public final String systemId;
    public final String contentSha256;
    public final String detectionSource;

    public EmulationIdentity(String systemId, String contentSha256, String detectionSource) {
        this.systemId = systemId;
        this.contentSha256 = contentSha256;
        this.detectionSource = detectionSource;
    }

    public String canonicalGameId() {
        return "classic:" + systemId + ":sha256:" + contentSha256;
    }

    public static EmulationIdentity inspect(InputStream input, String filename) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[1024 * 1024];
        byte[] header = new byte[4 * 1024 * 1024];
        int headerSize = 0;
        int read;
        while ((read = input.read(buffer)) != -1) {
            if (read == 0) continue;
            digest.update(buffer, 0, read);
            int copy = Math.min(read, header.length - headerSize);
            if (copy > 0) { System.arraycopy(buffer, 0, header, headerSize, copy); headerSize += copy; }
        }
        if (headerSize == 0) throw new IllegalArgumentException("A ROM está vazia e não pode ser identificada.");
        DetectedSystem detected = detectSystem(header, headerSize, filename);
        if (detected == null) throw new IllegalArgumentException("O formato desta ROM ainda não é reconhecido.");
        return new EmulationIdentity(detected.systemId, hex(digest.digest()), detected.source);
    }

    static DetectedSystem detectSystem(byte[] header, int length, String filename) {
        byte[] logo = {
            (byte)0xCE, (byte)0xED, 0x66, 0x66, (byte)0xCC, 0x0D, 0x00, 0x0B,
            0x03, 0x73, 0x00, (byte)0x83, 0x00, 0x0C, 0x00, 0x0D,
            0x00, 0x08, 0x11, 0x1F, (byte)0x88, (byte)0x89, 0x00, 0x0E,
            (byte)0xDC, (byte)0xCC, 0x6E, (byte)0xE6, (byte)0xDD, (byte)0xDD, (byte)0xD9, (byte)0x99,
            (byte)0xBB, (byte)0xBB, 0x67, 0x63, 0x6E, 0x0E, (byte)0xEC, (byte)0xCC,
            (byte)0xDD, (byte)0xDC, (byte)0x99, (byte)0x9F, (byte)0xBB, (byte)0xB9, 0x33, 0x3E
        };
        if (length > 0x143) {
            boolean matches = true;
            for (int i = 0; i < logo.length; i++) if (header[0x104 + i] != logo[i]) { matches = false; break; }
            if (matches) {
                int flag = header[0x143] & 0xff;
                return new DetectedSystem(flag == 0x80 || flag == 0xC0 ? "gbc" : "gb", "header");
            }
        }
        if (length > 0xB2 && (header[0xB2] & 0xff) == 0x96) return new DetectedSystem("gba", "header");
        if (containsAscii(header, length, "BOOT2")) return new DetectedSystem("ps2", "header");
        String extension = ClassicsRules.extension(filename).toLowerCase(Locale.ROOT);
        switch (extension) {
            case "gb": case "gbc": case "gba": case "nes": case "sfc": case "smc":
            case "n64": case "z64": case "v64": case "nds": case "sms": case "gg":
            case "md": case "gen": case "pce":
                return new DetectedSystem(extension, "extension");
            case "elf": case "isz":
                return new DetectedSystem("ps2", "extension");
            case "neo":
                return new DetectedSystem("neogeo", "extension");
            default:
                break;
        }
        return null;
    }

    private static boolean containsAscii(byte[] bytes, int length, String value) {
        byte[] wanted = value.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        int limit = Math.min(length, bytes.length) - wanted.length;
        for (int offset = 0; offset <= limit; offset++) {
            int index = 0;
            while (index < wanted.length && bytes[offset + index] == wanted[index]) index++;
            if (index == wanted.length) return true;
        }
        return false;
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) result.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        return result.toString();
    }

    static final class DetectedSystem {
        final String systemId;
        final String source;
        DetectedSystem(String systemId, String source) { this.systemId = systemId; this.source = source; }
    }
}

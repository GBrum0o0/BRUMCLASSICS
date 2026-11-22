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

    // Keep canonicalGameId() stable for existing local save manifests. The
    // normalized transport ID is used only when comparing devices.
    public String portableGameId() {
        return portableGameId(systemId, contentSha256);
    }

    public static String portableGameId(String storedSystemId, String sha256) {
        String system = storedSystemId == null ? "" : storedSystemId.toLowerCase(Locale.ROOT);
        switch (system) {
            case "smc": system = "sfc"; break;
            case "gen": case "smd": system = "md"; break;
            case "z64": case "v64": system = "n64"; break;
            default: break;
        }
        if (!system.matches("[a-z0-9]+") || sha256 == null || !sha256.matches("[a-fA-F0-9]{64}")) {
            throw new IllegalArgumentException("Identidade portátil inválida.");
        }
        return "classic:" + system + ":sha256:" + sha256.toLowerCase(Locale.ROOT);
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

    public static String detectSystemFromStream(InputStream input, String pathHint) throws Exception {
        byte[] buffer = new byte[64 * 1024];
        byte[] header = new byte[4 * 1024 * 1024];
        int headerSize = 0;
        int read;
        boolean checkedInitialWindow = false;
        while (headerSize < header.length && (read = input.read(buffer, 0, Math.min(buffer.length, header.length - headerSize))) != -1) {
            if (read == 0) continue;
            System.arraycopy(buffer, 0, header, headerSize, read);
            headerSize += read;
            if (!checkedInitialWindow && headerSize >= 64 * 1024) {
                checkedInitialWindow = true;
                DetectedSystem fast = detectSystem(header, headerSize, pathHint);
                if (fast != null) return fast.systemId;
            }
        }
        if (headerSize == 0) return "";
        DetectedSystem detected = detectSystem(header, headerSize, pathHint);
        return detected != null ? detected.systemId : "";
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
        if (length >= 4 && header[0] == '3' && header[1] == 'D' && header[2] == 'S' && header[3] == 'X') return new DetectedSystem("3ds", "header");
        if (length >= 0x104 && header[0x100] == 'N' && header[0x101] == 'C' && (header[0x102] == 'S' || header[0x102] == 'C') && (header[0x103] == 'D' || header[0x103] == 'H')) {
            return new DetectedSystem("3ds", "header");
        }
        String extension = ClassicsRules.extension(filename).toLowerCase(Locale.ROOT);
        if ("iso".equals(extension) && containsAscii(header, length, "PSP GAME")) return new DetectedSystem("psp", "header");
        if (containsAscii(header, length, "BOOT2")) return new DetectedSystem("ps2", "header");
        if ("iso".equals(extension) && containsAscii(header, length, "PSP_GAME")) return new DetectedSystem("psp", "header");
        if ("cso".equals(extension) && length >= 4 && header[0] == 'C' && header[1] == 'I' && header[2] == 'S' && header[3] == 'O') return new DetectedSystem("psp", "header");
        if ("pbp".equals(extension) && length >= 40 && header[0] == 0x00 && header[1] == 'P' && header[2] == 'B' && header[3] == 'P') {
            long dataPspOffset = readUInt32LE(header, 0x20);
            long dataPsarOffset = readUInt32LE(header, 0x24);
            boolean isPs1Classic = dataPsarOffset >= 40 && dataPsarOffset + 10 <= length
                && (matchesAsciiAt(header, (int) dataPsarOffset, "PSISOIMG")
                    || matchesAsciiAt(header, (int) dataPsarOffset, "PSTITLEIMG"));
            if (!isPs1Classic && dataPspOffset >= 40 && dataPspOffset + 4 <= length) {
                int o = (int) dataPspOffset;
                boolean isPspElf = header[o] == 0x7E && header[o + 1] == 'P' && header[o + 2] == 'S' && header[o + 3] == 'P';
                boolean isElf = header[o] == 0x7F && header[o + 1] == 'E' && header[o + 2] == 'L' && header[o + 3] == 'F';
                if (isPspElf || isElf) return new DetectedSystem("psp", "header");
            }
        }
        // ISO and PBP are shared with other PlayStation systems. A PSP folder
        // disambiguates them without changing existing PS2 content detection.
        String path = "/" + (filename == null ? "" : filename.replace('\\', '/').toLowerCase(Locale.ROOT));
        if (("iso".equals(extension) || "pbp".equals(extension) || "prx".equals(extension)) &&
            (path.contains("/psp/") || path.contains("/playstation portable/") || path.contains("/sony psp/"))) return new DetectedSystem("psp", "folder");
        switch (extension) {
            case "gb": case "gbc": case "gba": case "nes": case "sfc": case "smc":
            case "n64": case "z64": case "v64": case "nds": case "sms": case "gg":
            case "md": case "gen": case "pce": case "ws": case "wsc":
                return new DetectedSystem(extension, "extension");
            case "elf": case "isz":
                return new DetectedSystem("ps2", "extension");
            case "neo":
                return new DetectedSystem("neogeo", "extension");
            case "3ds": case "cci": case "cxi": case "app": case "3dsx":
                return new DetectedSystem("3ds", "extension");
            default:
                break;
        }
        return null;
    }

    private static boolean matchesAsciiAt(byte[] bytes, int offset, String value) {
        byte[] wanted = value.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        if (offset < 0 || offset + wanted.length > bytes.length) return false;
        for (int i = 0; i < wanted.length; i++) {
            if (bytes[offset + i] != wanted[i]) return false;
        }
        return true;
    }

    private static long readUInt32LE(byte[] bytes, int offset) {
        return (bytes[offset] & 0xffL)
            | ((bytes[offset + 1] & 0xffL) << 8)
            | ((bytes[offset + 2] & 0xffL) << 16)
            | ((bytes[offset + 3] & 0xffL) << 24);
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

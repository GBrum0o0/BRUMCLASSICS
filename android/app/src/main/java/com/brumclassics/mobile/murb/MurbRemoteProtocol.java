package com.brumclassics.mobile.murb;

import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public final class MurbRemoteProtocol {
    public static final int MAGIC = 0x4D555242;
    private static final String CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    public static final class PairingPayload {
        public final String host;
        public final int port;
        public final String token;
        public final String system;
        public final String session;
        public final String pcName;

        public PairingPayload(String host, int port, String token, String system, String session, String pcName) {
            this.host = host;
            this.port = port;
            this.token = token;
            this.system = system;
            this.session = session == null ? "" : session;
            this.pcName = pcName == null ? "" : pcName;
        }
    }

    public static final class FrameHeader {
        public final int sequence;
        public final int width;
        public final int height;
        public final int pixelBytes;

        FrameHeader(int sequence, int width, int height, int pixelBytes) {
            this.sequence = sequence;
            this.width = width;
            this.height = height;
            this.pixelBytes = pixelBytes;
        }
    }

    private MurbRemoteProtocol() {}

    public static String normalizeSystem(String raw) {
        if (raw == null) return "gamepad";
        String value = raw.trim().toLowerCase(Locale.ROOT);
        switch (value) {
            case "nds": case "ds": case "nintendo_ds": return "ds";
            case "n3ds": case "3ds": case "azahar": case "citra": return "3ds";
            case "wiiu": case "cemu": return "wiiu";
            case "gc": case "gamecube": return "gamecube";
            case "sfc": case "snes": return "snes";
            case "psx": case "ps1": return "ps1";
            case "": return "gamepad";
            default: return value;
        }
    }

    public static boolean supportsDualScreen(String system) {
        String s = normalizeSystem(system);
        return "ds".equals(s) || "3ds".equals(s) || "wiiu".equals(s);
    }

    public static boolean hasAnalogStick(String system) {
        String s = normalizeSystem(system);
        return "3ds".equals(s) || "n64".equals(s) || "gamecube".equals(s) || "wii".equals(s)
            || "wiiu".equals(s) || "ps1".equals(s) || "ps2".equals(s) || "psp".equals(s)
            || "dreamcast".equals(s) || "gamepad".equals(s);
    }

    public static FrameHeader parseFrameHeader(byte[] payload) {
        if (payload == null || payload.length < 16) return null;
        ByteBuffer bb = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
        int magic = bb.getInt(0);
        int seq = bb.getInt(4);
        int w = bb.getShort(8) & 0xFFFF;
        int h = bb.getShort(10) & 0xFFFF;
        if (magic != MAGIC || w <= 0 || h <= 0 || w > 1024 || h > 1024) return null;
        int expected = w * h * 2;
        if (payload.length < 16 + expected) return null;
        return new FrameHeader(seq, w, h, expected);
    }

    public static int crc8(byte[] data, int len) {
        int crc = 0;
        for (int i = 0; i < len; i++) {
            crc ^= (data[i] & 0xFF);
            for (int bit = 0; bit < 8; bit++) {
                crc = ((crc & 0x80) != 0) ? (((crc << 1) ^ 0x07) & 0xFF) : ((crc << 1) & 0xFF);
            }
        }
        return crc & 0xFF;
    }

    public static int[] parseIpv4(String host, boolean allowLoopback) {
        if (host == null) return null;
        String trimmed = host.trim();
        String[] parts = trimmed.split("\\.", -1);
        if (parts.length != 4) return null;
        int[] octets = new int[4];
        boolean allZero = true;
        for (int i = 0; i < 4; i++) {
            if (parts[i].isEmpty() || parts[i].length() > 3) return null;
            for (int j = 0; j < parts[i].length(); j++) {
                if (!Character.isDigit(parts[i].charAt(j))) return null;
            }
            int v = Integer.parseInt(parts[i]);
            if (v < 0 || v > 255) return null;
            if (v != 0) allZero = false;
            octets[i] = v;
        }
        if (allZero) return null;
        if (octets[0] == 127 && !(allowLoopback && "127.0.0.1".equals(trimmed))) return null;
        return octets;
    }

    public static boolean isValidHost(String host, boolean allowLoopback) {
        if (host == null) return false;
        String cleaned = host.trim();
        if (cleaned.isEmpty() || cleaned.length() > 253) return false;
        for (int i = 0; i < cleaned.length(); i++) {
            char ch = cleaned.charAt(i);
            if (ch <= ' ') return false;
        }
        if (parseIpv4(cleaned, allowLoopback) != null) return true;
        // Reject raw IPv4-looking strings that failed parseIpv4 (like 0.0.0.0 or 127.0.0.1)
        String[] dots = cleaned.split("\\.", -1);
        boolean allDigits = dots.length == 4;
        if (allDigits) {
            for (String p : dots) {
                if (p.isEmpty()) { allDigits = false; break; }
                for (int i = 0; i < p.length(); i++) if (!Character.isDigit(p.charAt(i))) { allDigits = false; break; }
            }
            if (allDigits) return false;
        }
        if (!allowLoopback && "localhost".equalsIgnoreCase(cleaned)) return false;
        for (int i = 0; i < cleaned.length(); i++) {
            char ch = cleaned.charAt(i);
            if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '.' || ch == '-')) {
                return false;
            }
        }
        return true;
    }

    public static boolean isValidToken(String token) {
        if (token == null) return false;
        String t = token.trim().toUpperCase(Locale.ROOT);
        if (t.length() < 4 || t.length() > 32) return false;
        for (int i = 0; i < t.length(); i++) {
            char ch = t.charAt(i);
            if (!((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z'))) return false;
        }
        return true;
    }

    public static String encodePairingCode(String host, int port, String token) {
        int[] octets = parseIpv4(host, false);
        if (octets == null || port < 1 || port > 65535 || token == null) return null;
        String cleanToken = token.trim().toUpperCase(Locale.ROOT);
        if (cleanToken.length() != 6 || !isValidToken(cleanToken)) return null;
        byte[] payload = new byte[14];
        payload[0] = 1;
        payload[1] = (byte) octets[0];
        payload[2] = (byte) octets[1];
        payload[3] = (byte) octets[2];
        payload[4] = (byte) octets[3];
        payload[5] = (byte) ((port >> 8) & 0xFF);
        payload[6] = (byte) (port & 0xFF);
        byte[] tokBytes = cleanToken.getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(tokBytes, 0, payload, 7, 6);
        payload[13] = (byte) crc8(payload, 13);

        int buffer = 0;
        int bitsLeft = 0;
        StringBuilder sb = new StringBuilder(23);
        for (byte b : payload) {
            buffer = (buffer << 8) | (b & 0xFF);
            bitsLeft += 8;
            while (bitsLeft >= 5) {
                sb.append(CROCKFORD.charAt((buffer >> (bitsLeft - 5)) & 0x1F));
                bitsLeft -= 5;
            }
        }
        if (bitsLeft > 0) sb.append(CROCKFORD.charAt((buffer << (5 - bitsLeft)) & 0x1F));
        if (sb.length() != 23) return null;
        return "MBC-" + sb.substring(0, 4) + "-" + sb.substring(4, 8) + "-" + sb.substring(8, 12)
            + "-" + sb.substring(12, 16) + "-" + sb.substring(16, 20) + "-" + sb.substring(20, 23);
    }

    public static PairingPayload decodePairingCode(String raw) {
        if (raw == null) return null;
        String upper = raw.trim().toUpperCase(Locale.ROOT);
        if (upper.isEmpty() || upper.contains("://")) return null;
        String stripped = upper.startsWith("MBC") ? upper.substring(3) : upper;
        StringBuilder body = new StringBuilder(23);
        for (int i = 0; i < stripped.length(); i++) {
            char ch = stripped.charAt(i);
            if (!Character.isWhitespace(ch) && ch != '-') body.append(ch);
        }
        if (body.length() != 23) return null;

        int buffer = 0;
        int bitsLeft = 0;
        byte[] bytes = new byte[14];
        int outIdx = 0;
        for (int i = 0; i < body.length(); i++) {
            char ch = body.charAt(i);
            if (ch == 'O') ch = '0';
            else if (ch == 'I' || ch == 'L') ch = '1';
            int val = CROCKFORD.indexOf(ch);
            if (val < 0) return null;
            buffer = (buffer << 5) | val;
            bitsLeft += 5;
            if (bitsLeft >= 8) {
                bytes[outIdx++] = (byte) ((buffer >> (bitsLeft - 8)) & 0xFF);
                bitsLeft -= 8;
            }
        }
        if (outIdx != 14 || bytes[0] != 1) return null;
        if (crc8(bytes, 13) != (bytes[13] & 0xFF)) return null;
        String host = (bytes[1] & 0xFF) + "." + (bytes[2] & 0xFF) + "." + (bytes[3] & 0xFF) + "." + (bytes[4] & 0xFF);
        int port = ((bytes[5] & 0xFF) << 8) | (bytes[6] & 0xFF);
        if (parseIpv4(host, false) == null || port < 1 || port > 65535) return null;
        String token = new String(bytes, 7, 6, StandardCharsets.US_ASCII);
        if (!isValidToken(token)) return null;
        return new PairingPayload(host, port, token, "gamepad", "", "");
    }

    public static PairingPayload validateMurbUri(String raw) {
        return validateMurbUri(raw, false);
    }

    public static PairingPayload validateMurbUri(String raw, boolean allowLoopback) {
        if (raw == null) return null;
        String trimmed = raw.trim();
        if (!trimmed.toLowerCase(Locale.ROOT).startsWith("murb://")) return null;
        try {
            URI uri = URI.create(trimmed);
            if (!"murb".equalsIgnoreCase(uri.getScheme())) return null;
            String rawQuery = uri.getRawQuery();
            String ip = "";
            String hostQ = "";
            String token = "";
            String portStr = "";
            String sysQ = "";
            String session = "";
            String pcName = "";
            if (rawQuery != null) {
                for (String pair : rawQuery.split("&")) {
                    int eq = pair.indexOf('=');
                    String k = java.net.URLDecoder.decode(eq >= 0 ? pair.substring(0, eq) : pair, "UTF-8");
                    String v = java.net.URLDecoder.decode(eq >= 0 ? pair.substring(eq + 1) : "", "UTF-8").trim();
                    if ("ip".equalsIgnoreCase(k)) ip = v;
                    else if ("host".equalsIgnoreCase(k)) hostQ = v;
                    else if ("token".equalsIgnoreCase(k)) token = v.toUpperCase(Locale.ROOT);
                    else if ("port".equalsIgnoreCase(k)) portStr = v;
                    else if ("sys".equalsIgnoreCase(k)) sysQ = v;
                    else if ("session".equalsIgnoreCase(k)) session = v;
                    else if ("pc".equalsIgnoreCase(k)) pcName = v;
                }
            }
            String targetHost = ip.isEmpty() ? hostQ : ip;
            int port = portStr.isEmpty() ? 8089 : Integer.parseInt(portStr);
            if (!isValidHost(targetHost, allowLoopback) || !isValidToken(token) || port < 1 || port > 65535) return null;
            String sys = sysQ.isEmpty() ? (uri.getHost() == null ? "ds" : uri.getHost()) : sysQ;
            return new PairingPayload(targetHost, port, token, normalizeSystem(sys), session, pcName);
        } catch (Exception ignored) {
            return null;
        }
    }

    public static PairingPayload parseUserInput(String raw) {
        if (raw == null) return null;
        PairingPayload byCode = decodePairingCode(raw);
        if (byCode != null) return byCode;
        return validateMurbUri(raw, false);
    }
}

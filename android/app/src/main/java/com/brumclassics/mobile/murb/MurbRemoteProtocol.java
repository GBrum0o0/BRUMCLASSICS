package com.brumclassics.mobile.murb;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Locale;

public final class MurbRemoteProtocol {
    public static final int MAGIC = 0x4D555242;

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
}

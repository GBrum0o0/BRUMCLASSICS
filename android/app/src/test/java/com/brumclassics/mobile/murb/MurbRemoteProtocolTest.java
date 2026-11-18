package com.brumclassics.mobile.murb;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class MurbRemoteProtocolTest {
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    public static void main(String[] args) {
        check("ds".equals(MurbRemoteProtocol.normalizeSystem("nds")), "nds -> ds");
        check("3ds".equals(MurbRemoteProtocol.normalizeSystem("n3ds")), "n3ds -> 3ds");
        check("wiiu".equals(MurbRemoteProtocol.normalizeSystem("Cemu")), "Cemu -> wiiu");
        check(MurbRemoteProtocol.supportsDualScreen("ds"), "DS supports dual screen");
        check(MurbRemoteProtocol.supportsDualScreen("3ds"), "3DS supports dual screen");
        check(!MurbRemoteProtocol.supportsDualScreen("snes"), "SNES does not support dual screen");
        check(MurbRemoteProtocol.hasAnalogStick("3ds"), "3DS has analog stick");
        check(MurbRemoteProtocol.hasAnalogStick("ps2"), "PS2 has analog stick");
        check(!MurbRemoteProtocol.hasAnalogStick("nes"), "NES does not have analog stick");

        byte[] valid = new byte[16 + 4 * 2 * 2];
        ByteBuffer.wrap(valid).order(ByteOrder.LITTLE_ENDIAN)
            .putInt(0, MurbRemoteProtocol.MAGIC)
            .putInt(4, 12)
            .putShort(8, (short) 4)
            .putShort(10, (short) 2);
        MurbRemoteProtocol.FrameHeader header = MurbRemoteProtocol.parseFrameHeader(valid);
        check(header != null, "Valid frame header parsed");
        check(header.sequence == 12, "Sequence matches");
        check(header.width == 4 && header.height == 2 && header.pixelBytes == 16, "Geometry matches");

        byte[] truncated = new byte[20];
        ByteBuffer.wrap(truncated).order(ByteOrder.LITTLE_ENDIAN)
            .putInt(0, MurbRemoteProtocol.MAGIC)
            .putShort(8, (short) 4)
            .putShort(10, (short) 2);
        check(MurbRemoteProtocol.parseFrameHeader(truncated) == null, "Truncated frame rejected");
        check(MurbRemoteProtocol.parseFrameHeader(new byte[16]) == null, "Invalid magic rejected");
        System.out.println("MurbRemoteProtocolTest: OK");
    }
}

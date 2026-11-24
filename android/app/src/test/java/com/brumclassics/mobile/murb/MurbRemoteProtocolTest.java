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

        String code = MurbRemoteProtocol.encodePairingCode("192.168.1.42", 8089, "AB12CD");
        check(code != null && code.startsWith("MBC-") && code.length() == 32, "Encoded MBC pairing code format");
        MurbRemoteProtocol.PairingPayload decoded = MurbRemoteProtocol.decodePairingCode(code);
        check(decoded != null && "192.168.1.42".equals(decoded.host) && decoded.port == 8089 && "AB12CD".equals(decoded.token), "Decoded MBC round-trip");
        // Crockford ambiguous letter tolerance (O->0, I/L->1) if code contains 0 or 1
        String ambiguous = code.replace('0', 'O').replace('1', 'l').toLowerCase(java.util.Locale.ROOT);
        MurbRemoteProtocol.PairingPayload decodedAmb = MurbRemoteProtocol.decodePairingCode(ambiguous);
        check(decodedAmb != null && "192.168.1.42".equals(decodedAmb.host) && "AB12CD".equals(decodedAmb.token), "Crockford O/I/L tolerance");
        // Flip last CRC char to guarantee checksum mismatch rejection
        char last = code.charAt(code.length() - 1);
        char tamperedChar = (last == '0') ? '2' : '0';
        String tampered = code.substring(0, code.length() - 1) + tamperedChar;
        check(MurbRemoteProtocol.decodePairingCode(tampered) == null, "Tampered CRC-8 rejected");
        check(MurbRemoteProtocol.encodePairingCode("127.0.0.1", 8089, "AB12CD") == null, "Loopback rejected from code encode");
        check(MurbRemoteProtocol.encodePairingCode("0.0.0.0", 8089, "AB12CD") == null, "Zero IP rejected from code encode");

        MurbRemoteProtocol.PairingPayload uri = MurbRemoteProtocol.validateMurbUri("murb://psp?ip=192.168.1.42&port=8091&token=AB12CD&pc=SalaPC");
        check(uri != null && "192.168.1.42".equals(uri.host) && uri.port == 8091 && "psp".equals(uri.system) && "SalaPC".equals(uri.pcName), "Valid murb:// URI parsed");
        check(MurbRemoteProtocol.validateMurbUri("murb://gamepad?ip=127.0.0.1&port=8089&token=AB12CD") == null, "Loopback URI rejected");
        check(MurbRemoteProtocol.validateMurbUri("https://example.com?ip=192.168.1.42&token=AB12CD") == null, "Non-murb scheme rejected");
        check(MurbRemoteProtocol.parseUserInput(code) != null, "parseUserInput accepts MBC code");
        check(MurbRemoteProtocol.parseUserInput("murb://gamepad?ip=192.168.1.42&port=8089&token=AB12CD") != null, "parseUserInput accepts murb URI");

        System.out.println("MurbRemoteProtocolTest: OK (vector=" + code + ")");
    }
}

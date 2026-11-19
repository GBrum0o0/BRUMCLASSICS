package com.brumclassics.mobile.murb;

import android.net.Uri;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Base64;

import org.json.JSONObject;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

public final class MurbRemoteClient {
    public static final int MAGIC = MurbRemoteProtocol.MAGIC;
    public static final int BTN_A = 0x0001;
    public static final int BTN_B = 0x0002;
    public static final int BTN_SELECT = 0x0004;
    public static final int BTN_START = 0x0008;
    public static final int BTN_RIGHT = 0x0010;
    public static final int BTN_LEFT = 0x0020;
    public static final int BTN_UP = 0x0040;
    public static final int BTN_DOWN = 0x0080;
    public static final int BTN_R = 0x0100;
    public static final int BTN_L = 0x0200;
    public static final int BTN_X = 0x0400;
    public static final int BTN_Y = 0x0800;
    public static final int BTN_L2 = 0x1000;
    public static final int BTN_R2 = 0x2000;
    public static final int BTN_L3 = 0x4000;
    public static final int BTN_R3 = 0x8000;

    public static final class PairingTarget {
        public final String host;
        public final int port;
        public final String token;
        public final String system;

        public PairingTarget(String host, int port, String token, String system) {
            this.host = host;
            this.port = port;
            this.token = token;
            this.system = system;
        }
    }

    public interface Listener {
        void onConnected();

        void onDisconnected();

        void onVideoFrame(byte[] rgb565Pixels, int width, int height, int sequence);

        void onPingRtt(int rttMs);

        void onSystemIdentified(String system);

        void onError(String message);
    }

    public static String normalizeSystem(String raw) {
        return MurbRemoteProtocol.normalizeSystem(raw);
    }

    public static boolean supportsDualScreen(String system) {
        return MurbRemoteProtocol.supportsDualScreen(system);
    }

    public static boolean hasAnalogStick(String system) {
        return MurbRemoteProtocol.hasAnalogStick(system);
    }

    public static PairingTarget parseUri(String raw) {
        if (raw == null || !raw.trim().toLowerCase(Locale.ROOT).startsWith("murb://"))
            return null;
        try {
            Uri uri = Uri.parse(raw.trim());
            String ip = uri.getQueryParameter("ip");
            if (ip == null || ip.trim().isEmpty())
                ip = uri.getQueryParameter("host");
            String token = uri.getQueryParameter("token");
            String portStr = uri.getQueryParameter("port");
            int port = (portStr == null || portStr.trim().isEmpty()) ? 8089 : Integer.parseInt(portStr.trim());
            if (ip == null || ip.trim().isEmpty() || token == null || token.trim().isEmpty() || port < 1
                    || port > 65535) {
                return null;
            }
            String sys = uri.getQueryParameter("sys");
            if (sys == null || sys.trim().isEmpty())
                sys = uri.getHost();
            return new PairingTarget(ip.trim(), port, token.trim().toUpperCase(Locale.ROOT),
                    MurbRemoteProtocol.normalizeSystem(sys));
        } catch (Exception ignored) {
            return null;
        }
    }

    public static MurbRemoteProtocol.FrameHeader parseFrameHeader(byte[] payload) {
        return MurbRemoteProtocol.parseFrameHeader(payload);
    }

    private final String host;
    private final int port;
    private final String token;
    private final Listener listener;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean connected = new AtomicBoolean(false);
    private final SecureRandom random = new SecureRandom();

    private Socket socket;
    private InputStream input;
    private OutputStream output;
    private static final class PendingFrame {
        final byte[] pixels;
        final int width;
        final int height;
        final int sequence;

        PendingFrame(byte[] pixels, int width, int height, int sequence) {
            this.pixels = pixels;
            this.width = width;
            this.height = height;
            this.sequence = sequence;
        }
    }

    private Thread receiveThread;
    private Thread pingThread;
    private HandlerThread sendThread;
    private Handler sendHandler;
    private final AtomicReference<String> pendingInputJson = new AtomicReference<>(null);
    private final AtomicBoolean inputFlushScheduled = new AtomicBoolean(false);
    private final AtomicReference<PendingFrame> pendingFrame = new AtomicReference<>(null);
    private final AtomicBoolean framePostScheduled = new AtomicBoolean(false);

    private final Runnable flushInputTask = new Runnable() {
        @Override public void run() {
            while (running.get() && connected.get()) {
                String next = pendingInputJson.getAndSet(null);
                if (next != null) {
                    try {
                        sendText(next);
                    } catch (Exception ignored) {
                    }
                }
                inputFlushScheduled.set(false);
                if (pendingInputJson.get() == null || !inputFlushScheduled.compareAndSet(false, true)) {
                    break;
                }
            }
        }
    };

    private final Runnable flushFrameTask = new Runnable() {
        @Override public void run() {
            while (running.get()) {
                PendingFrame frame = pendingFrame.getAndSet(null);
                if (frame != null) {
                    listener.onVideoFrame(frame.pixels, frame.width, frame.height, frame.sequence);
                }
                framePostScheduled.set(false);
                if (pendingFrame.get() == null || !framePostScheduled.compareAndSet(false, true)) {
                    break;
                }
            }
        }
    };

    public MurbRemoteClient(String host, int port, String token, Listener listener) {
        this.host = host;
        this.port = port;
        this.token = token;
        this.listener = listener;
    }

    public boolean isConnected() {
        return connected.get();
    }

    public void connect() {
        if (running.getAndSet(true))
            return;
        sendThread = new HandlerThread("MurbWsSender");
        sendThread.start();
        sendHandler = new Handler(sendThread.getLooper());
        receiveThread = new Thread(this::runConnection, "MurbWsRecv");
        receiveThread.start();
    }

    public void disconnect() {
        running.set(false);
        connected.set(false);
        pendingInputJson.set(null);
        pendingFrame.set(null);
        inputFlushScheduled.set(false);
        framePostScheduled.set(false);
        if (sendThread != null) {
            sendThread.quitSafely();
            sendThread = null;
            sendHandler = null;
        }
        try {
            if (socket != null && !socket.isClosed())
                socket.close();
        } catch (Exception ignored) {
        }
        if (receiveThread != null)
            receiveThread.interrupt();
        if (pingThread != null)
            pingThread.interrupt();
    }

    public void sendInput(int buttons, boolean touching, int touchX, int touchY, int stickX, int stickY) {
        sendInput(buttons, touching, touchX, touchY, stickX, stickY, 0, 0);
    }

    public void sendInput(int buttons, boolean touching, int touchX, int touchY, int stickX, int stickY, int rStickX, int rStickY) {
        if (!connected.get())
            return;
        final String json = "{\"type\":\"input\",\"buttons\":" + buttons
                + ",\"touching\":" + touching
                + ",\"x\":" + touchX
                + ",\"y\":" + touchY
                + ",\"stickX\":" + stickX
                + ",\"stickY\":" + stickY
                + ",\"rStickX\":" + rStickX
                + ",\"rStickY\":" + rStickY + "}";
        Handler handler = sendHandler;
        if (handler != null) {
            pendingInputJson.set(json);
            if (inputFlushScheduled.compareAndSet(false, true)) {
                handler.post(flushInputTask);
            }
        }
    }

    private void runConnection() {
        try {
            socket = new Socket();
            socket.setTcpNoDelay(true);
            socket.connect(new InetSocketAddress(host, port), 4000);
            input = socket.getInputStream();
            output = socket.getOutputStream();

            byte[] keyBytes = new byte[16];
            random.nextBytes(keyBytes);
            String wsKey = Base64.encodeToString(keyBytes, Base64.NO_WRAP);
            String handshake = "GET /stream?token=" + token + " HTTP/1.1\r\n"
                    + "Host: " + host + ":" + port + "\r\n"
                    + "Upgrade: websocket\r\n"
                    + "Connection: Upgrade\r\n"
                    + "Sec-WebSocket-Key: " + wsKey + "\r\n"
                    + "Sec-WebSocket-Version: 13\r\n\r\n";
            output.write(handshake.getBytes(StandardCharsets.UTF_8));
            output.flush();

            byte[] buf = new byte[2048];
            int read = input.read(buf);
            if (read <= 0)
                throw new IllegalStateException("Resposta vazia do PC.");
            String response = new String(buf, 0, read, StandardCharsets.UTF_8);
            if (!response.contains("101 Switching Protocols")) {
                mainHandler.post(() -> listener.onError(response.contains("403")
                        ? "Token de sessão inválido ou expirado."
                        : "Falha ao conectar com o PC."));
                socket.close();
                return;
            }

            connected.set(true);
            mainHandler.post(listener::onConnected);

            pingThread = new Thread(this::runPingLoop, "MurbWsPing");
            pingThread.start();
            runReceiveLoop();
        } catch (Exception e) {
            if (running.get()) {
                String msg = e.getMessage() == null ? "PC inacessível na rede local." : e.getMessage();
                mainHandler.post(() -> listener.onError(msg));
            }
        } finally {
            connected.set(false);
            mainHandler.post(listener::onDisconnected);
        }
    }

    private void runReceiveLoop() throws Exception {
        byte[] hdr = new byte[10];
        while (running.get() && connected.get()) {
            readFully(input, hdr, 0, 2);
            int opcode = hdr[0] & 0x0F;
            int payloadLen = hdr[1] & 0x7F;
            long len = payloadLen;
            if (payloadLen == 126) {
                readFully(input, hdr, 2, 2);
                len = ((hdr[2] & 0xFF) << 8) | (hdr[3] & 0xFF);
            } else if (payloadLen == 127) {
                readFully(input, hdr, 2, 8);
                len = 0;
                for (int i = 0; i < 8; i++)
                    len = (len << 8) | (hdr[2 + i] & 0xFF);
            }
            if (len < 0 || len > 8L * 1024L * 1024L)
                break;
            byte[] payload = new byte[(int) len];
            if (len > 0)
                readFully(input, payload, 0, (int) len);

            if (opcode == 2) {
                MurbRemoteProtocol.FrameHeader frame = MurbRemoteProtocol.parseFrameHeader(payload);
                if (frame != null) {
                    byte[] pixels = new byte[frame.pixelBytes];
                    System.arraycopy(payload, 16, pixels, 0, frame.pixelBytes);
                    pendingFrame.set(new PendingFrame(pixels, frame.width, frame.height, frame.sequence));
                    if (framePostScheduled.compareAndSet(false, true)) {
                        mainHandler.post(flushFrameTask);
                    }
                }
            } else if (opcode == 1) {
                try {
                    JSONObject obj = new JSONObject(new String(payload, StandardCharsets.UTF_8));
                    if (obj.has("sys")) {
                        String sys = normalizeSystem(obj.optString("sys"));
                        mainHandler.post(() -> listener.onSystemIdentified(sys));
                    }
                    if (obj.has("pong") || "pong".equals(obj.optString("type"))) {
                        long sent = obj.optLong("ts", 0);
                        if (sent > 0) {
                            int rtt = (int) Math.max(0, System.currentTimeMillis() - sent);
                            mainHandler.post(() -> listener.onPingRtt(rtt));
                        }
                    }
                } catch (Exception ignored) {
                }
            } else if (opcode == 8) {
                break;
            }
        }
    }

    private void runPingLoop() {
        while (running.get() && connected.get()) {
            try {
                if (connected.get()) {
                    sendText("{\"type\":\"ping\",\"ts\":" + System.currentTimeMillis() + "}");
                }
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                break;
            } catch (Exception ignored) {
            }
        }
    }

    private synchronized void sendText(String text) throws Exception {
        if (output == null || !connected.get())
            return;
        byte[] payload = text.getBytes(StandardCharsets.UTF_8);
        byte[] mask = new byte[4];
        random.nextBytes(mask);
        int len = payload.length;
        byte[] header;
        if (len < 126) {
            header = new byte[6];
            header[0] = (byte) 0x81;
            header[1] = (byte) (0x80 | len);
            System.arraycopy(mask, 0, header, 2, 4);
        } else {
            header = new byte[8];
            header[0] = (byte) 0x81;
            header[1] = (byte) (0x80 | 126);
            header[2] = (byte) ((len >> 8) & 0xFF);
            header[3] = (byte) (len & 0xFF);
            System.arraycopy(mask, 0, header, 4, 4);
        }
        output.write(header);
        byte[] masked = new byte[len];
        for (int i = 0; i < len; i++)
            masked[i] = (byte) (payload[i] ^ mask[i % 4]);
        output.write(masked);
        output.flush();
    }

    private static void readFully(InputStream in, byte[] buf, int off, int len) throws Exception {
        int n = 0;
        while (n < len) {
            int count = in.read(buf, off + n, len - n);
            if (count < 0)
                throw new IllegalStateException("Conexão encerrada.");
            n += count;
        }
    }
}

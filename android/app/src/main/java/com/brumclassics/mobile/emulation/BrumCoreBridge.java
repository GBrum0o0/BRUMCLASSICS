package com.brumclassics.mobile.emulation;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class BrumCoreBridge implements AutoCloseable {
    public interface RetroAchievementsListener {
        void onAchievementConfirmed(String eventId, int gameId, int achievementId, String title, String description, int points, String badgeUrl);
        void onStatusChanged(String state, String message);
    }

    static {
        System.loadLibrary("brumcore");
    }

    private volatile long handle;
    private final ExecutorService raHttpExecutor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "brum-ra-http");
        t.setDaemon(true);
        return t;
    });
    private volatile RetroAchievementsListener raListener;

    public BrumCoreBridge(String corePath, String romPath, IntegratedEmulatorLaunch launch) {
        handle = nativeCreate(corePath, romPath, launch.systemDirectory.getAbsolutePath(),
            launch.saveFile.getParentFile().getAbsolutePath(), launch.saveFile.getAbsolutePath());
        if (handle == 0) throw new IllegalStateException("O BRUM Core não pôde iniciar esta ROM.");
    }

    public void configureRetroAchievements(int consoleId, String username, String runtimeToken, RetroAchievementsListener listener) {
        if (handle == 0) return;
        this.raListener = listener;
        nativeConfigureRetroAchievements(handle, consoleId, username == null ? "" : username, runtimeToken == null ? "" : runtimeToken, this);
    }

    @SuppressWarnings("unused")
    private void onNativeHttpRequest(long requestId, String urlString, String postData, String contentType) {
        if (handle == 0 || raHttpExecutor.isShutdown()) {
            nativeCompleteHttp(requestId, -1, "");
            return;
        }
        try {
            raHttpExecutor.execute(() -> {
                if (handle == 0) {
                    nativeCompleteHttp(requestId, -1, "");
                    return;
                }
                int status = -1;
                String body = "";
                HttpURLConnection conn = null;
                try {
                    URL url = new URL(urlString);
                    String host = url.getHost() == null ? "" : url.getHost().toLowerCase(java.util.Locale.ROOT);
                    if (!"https".equalsIgnoreCase(url.getProtocol())
                        || (!"retroachievements.org".equals(host) && !host.endsWith(".retroachievements.org"))) {
                        nativeCompleteHttp(requestId, -3, "");
                        return;
                    }
                    conn = (HttpURLConnection) url.openConnection();
                    conn.setConnectTimeout(15000);
                    conn.setReadTimeout(15000);
                    conn.setRequestProperty("User-Agent", "BRUMCLASSICSAndroid/0.34.0");
                    if (postData != null && !postData.isEmpty()) {
                        conn.setRequestMethod("POST");
                        conn.setDoOutput(true);
                        conn.setRequestProperty("Content-Type", contentType == null || contentType.isEmpty()
                            ? "application/x-www-form-urlencoded" : contentType);
                        byte[] payload = postData.getBytes(StandardCharsets.UTF_8);
                        try (OutputStream out = conn.getOutputStream()) {
                            out.write(payload);
                        }
                    } else {
                        conn.setRequestMethod("GET");
                    }
                    status = conn.getResponseCode();
                    InputStream stream = status >= 200 && status < 400 ? conn.getInputStream() : conn.getErrorStream();
                    if (stream != null) {
                        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
                        byte[] chunk = new byte[8192];
                        int read;
                        int total = 0;
                        while ((read = stream.read(chunk)) >= 0) {
                            total += read;
                            if (total > 4 * 1024 * 1024) break;
                            buffer.write(chunk, 0, read);
                        }
                        body = new String(buffer.toByteArray(), StandardCharsets.UTF_8);
                    }
                } catch (Exception ignored) {
                    status = -1;
                    body = "";
                } finally {
                    if (conn != null) conn.disconnect();
                }
                nativeCompleteHttp(requestId, status, body);
            });
        } catch (java.util.concurrent.RejectedExecutionException ignored) {
            nativeCompleteHttp(requestId, -1, "");
        }
    }

    @SuppressWarnings("unused")
    private void onNativeAchievementConfirmed(String eventId, int gameId, int achievementId, String title, String description, int points, String badgeUrl) {
        RetroAchievementsListener listener = this.raListener;
        if (listener != null) {
            listener.onAchievementConfirmed(eventId, gameId, achievementId, title, description, points, badgeUrl);
        }
    }

    @SuppressWarnings("unused")
    private void onNativeRetroAchievementsStatus(String state, String message) {
        RetroAchievementsListener listener = this.raListener;
        if (listener != null) {
            listener.onStatusChanged(state, message);
        }
    }

    public void runFrames(int count, int inputMask) { ensureOpen(); nativeRunFrames(handle, Math.max(1, count), inputMask); }
    public void setPortMask(int port, int mask) { if (handle != 0 && port >= 0 && port < 4) nativeSetPortMask(handle, port, mask); }
    public void setPointer(float normalizedX, float normalizedY, boolean pressed) {
        ensureOpen();
        int x = Math.round(Math.max(-1f, Math.min(1f, normalizedX)) * 32767f);
        int y = Math.round(Math.max(-1f, Math.min(1f, normalizedY)) * 32767f);
        if (pressed && y == 0) y = 1;
        nativeSetPointer(handle, x, y, pressed);
    }
    public void setAnalog(int port, int stick, int axis, float normalized) {
        if (handle == 0 || port < 0 || port >= 4) return;
        int scaled = Math.round(Math.max(-1f, Math.min(1f, normalized)) * 32767f);
        nativeSetAnalog(handle, port, stick, axis, scaled);
    }
    public long copyFrame(int[] target) { ensureOpen(); return nativeCopyFrame(handle, target); }
    public int drainAudio(short[] target) { ensureOpen(); return nativeDrainAudio(handle, target); }
    public void clearAudio() { if (handle != 0) nativeClearAudio(handle); }
    public int sampleRate() { ensureOpen(); return nativeSampleRate(handle); }
    public double frameRate() { ensureOpen(); return nativeFrameRate(handle); }
    public void persist() { if (handle != 0) nativePersist(handle); }
    public boolean saveState(String path) { ensureOpen(); return nativeSaveState(handle, path); }
    public boolean loadState(String path) { ensureOpen(); return nativeLoadState(handle, path); }

    @Override public void close() {
        long h = handle;
        handle = 0;
        raListener = null;
        if (h != 0) nativeDestroy(h);
        for (Runnable pending : raHttpExecutor.shutdownNow()) {
            pending.run();
        }
    }

    private void ensureOpen() { if (handle == 0) throw new IllegalStateException("A sessão de emulação já foi encerrada."); }

    private static native long nativeCreate(String corePath, String romPath, String systemDirectory, String saveDirectory, String savePath);
    private static native void nativeRunFrames(long handle, int count, int inputMask);
    private static native void nativeSetPortMask(long handle, int port, int mask);
    private static native void nativeSetPointer(long handle, int x, int y, boolean pressed);
    private static native void nativeSetAnalog(long handle, int port, int stick, int axis, int value);
    private static native long nativeCopyFrame(long handle, int[] target);
    private static native int nativeDrainAudio(long handle, short[] target);
    private static native void nativeClearAudio(long handle);
    private static native int nativeSampleRate(long handle);
    private static native double nativeFrameRate(long handle);
    private static native void nativePersist(long handle);
    private static native boolean nativeSaveState(long handle, String path);
    private static native boolean nativeLoadState(long handle, String path);
    private static native void nativeConfigureRetroAchievements(long handle, int consoleId, String username, String token, Object callbackTarget);
    private static native void nativeCompleteHttp(long requestId, int httpStatus, String responseBody);
    private static native void nativeDestroy(long handle);
}

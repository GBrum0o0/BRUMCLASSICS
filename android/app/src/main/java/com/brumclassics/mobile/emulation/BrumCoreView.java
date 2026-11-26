package com.brumclassics.mobile.emulation;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.view.View;
import android.view.MotionEvent;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.LockSupport;

final class BrumCoreView extends View implements Runnable {
    interface RuntimeErrorListener { void onRuntimeError(String message); }
    interface PokedexCaptureListener { void onPokedexCaptureJson(String json); }

    private final BrumCoreBridge core;
    private final RuntimeErrorListener errorListener;
    private volatile PokedexCaptureListener pokedexListener;
    private final AtomicInteger[] portMasks = {
        new AtomicInteger(), new AtomicInteger(), new AtomicInteger(), new AtomicInteger()
    };
    private int virtualPadPort = 0;
    private final int[] pixels = new int[2048 * 2048];
    private int[] shaderScratch;
    private int shaderOutWidth;
    private int shaderOutHeight;
    private final short[] audioSamples = new short[16 * 1024];
    private final Object bitmapLock = new Object();
    private final Paint paint = new Paint();
    private Bitmap bitmap;
    private Thread emulationThread;
    private volatile boolean running;
    private volatile boolean fastForward;
    private volatile boolean fillDisplay;
    private AudioTrack audioTrack;
    private long playedNanos;
    private final Rect sourceRect = new Rect();
    private final RectF targetRect = new RectF();
    private final RectF touchTarget = new RectF();
    private final RectF displayTarget = new RectF();
    private final Paint reticlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint overlayEffectPaint = new Paint();
    private volatile boolean integerScaling;
    private volatile String videoFilterMode = "none";
    private float touchScreenX;
    private float touchScreenY;
    private boolean touchActive;
    private String systemId = "";
    private String coreName = "";

    void setSystemContext(String systemId, String coreName) {
        this.systemId = systemId == null ? "" : systemId.toLowerCase(java.util.Locale.ROOT);
        this.coreName = coreName == null ? "" : coreName.toLowerCase(java.util.Locale.ROOT);
    }

    void setGraphicsPresentation(boolean integerScaling, String filterMode) {
        this.integerScaling = integerScaling;
        this.videoFilterMode = filterMode == null ? "none" : filterMode;
        boolean linear = "bilinear_subtle".equals(this.videoFilterMode) || "sharp_bilinear".equals(this.videoFilterMode);
        paint.setFilterBitmap(linear);
        postInvalidateOnAnimation();
    }

    private int[] ensureShaderScratch() {
        if (shaderScratch == null) {
            shaderScratch = new int[2048 * 2048];
        }
        return shaderScratch;
    }

    private int[] prepareFilteredFrame(int[] src, int width, int height) {
        shaderOutWidth = width;
        shaderOutHeight = height;
        String mode = videoFilterMode;
        if ("cas_sharpen".equals(mode)) {
            int[] dst = ensureShaderScratch();
            applyCasSharpenJava(src, dst, width, height, 70);
            return dst;
        }
        if ("edge_upscale_2x".equals(mode)) {
            if (width > 2 && height > 2 && width <= 640 && height <= 480 && (long) (width * 2) * (height * 2) <= 2048L * 2048L) {
                int[] dst = ensureShaderScratch();
                applyEdgeUpscale2xJava(src, dst, width, height);
                shaderOutWidth = width * 2;
                shaderOutHeight = height * 2;
                return dst;
            }
            int[] dst = ensureShaderScratch();
            applyCasSharpenJava(src, dst, width, height, 65);
            return dst;
        }
        if ("sharp_bilinear".equals(mode)) {
            if (width <= 640 && height <= 480 && (long) (width * 2) * (height * 2) <= 2048L * 2048L) {
                int[] dst = ensureShaderScratch();
                applySharpBilinearPrescaleJava(src, dst, width, height);
                shaderOutWidth = width * 2;
                shaderOutHeight = height * 2;
                return dst;
            }
            int[] dst = ensureShaderScratch();
            applyCasSharpenJava(src, dst, width, height, 35);
            return dst;
        }
        return src;
    }

    private static int channelDiffSum(int a, int b) {
        int dr = ((a >> 16) & 0xff) - ((b >> 16) & 0xff);
        int dg = ((a >> 8) & 0xff) - ((b >> 8) & 0xff);
        int db = (a & 0xff) - (b & 0xff);
        return (dr < 0 ? -dr : dr) + (dg < 0 ? -dg : dg) + (db < 0 ? -db : db);
    }

    private static int blend50(int a, int b) {
        int r = (((a >> 16) & 0xff) + ((b >> 16) & 0xff) + 1) >>> 1;
        int g = (((a >> 8) & 0xff) + ((b >> 8) & 0xff) + 1) >>> 1;
        int bl = ((a & 0xff) + (b & 0xff) + 1) >>> 1;
        return 0xff000000 | (r << 16) | (g << 8) | bl;
    }

    private static void applyCasSharpenJava(int[] src, int[] dst, int width, int height, int strengthPct) {
        if (width <= 2 || height <= 2) {
            System.arraycopy(src, 0, dst, 0, width * height);
            return;
        }
        int strength = Math.max(0, Math.min(120, strengthPct));
        for (int y = 0; y < height; y++) {
            int yUp = y > 0 ? y - 1 : 0;
            int yDn = y + 1 < height ? y + 1 : height - 1;
            int row = y * width;
            int rowUp = yUp * width;
            int rowDn = yDn * width;
            for (int x = 0; x < width; x++) {
                int xLt = x > 0 ? x - 1 : 0;
                int xRt = x + 1 < width ? x + 1 : width - 1;
                int c = src[row + x];
                int n = src[rowUp + x];
                int s = src[rowDn + x];
                int w = src[row + xLt];
                int e = src[row + xRt];
                if (c == n && c == s && c == w && c == e) {
                    dst[row + x] = 0xff000000 | (c & 0x00ffffff);
                    continue;
                }
                int out = 0xff000000;
                for (int shift = 16; shift >= 0; shift -= 8) {
                    int vc = (c >> shift) & 0xff;
                    int vn = (n >> shift) & 0xff;
                    int vs = (s >> shift) & 0xff;
                    int vw = (w >> shift) & 0xff;
                    int ve = (e >> shift) & 0xff;
                    int mn = Math.min(vc, Math.min(Math.min(vn, vs), Math.min(vw, ve)));
                    int mx = Math.max(vc, Math.max(Math.max(vn, vs), Math.max(vw, ve)));
                    int avg = (vn + vs + vw + ve) >> 2;
                    int cand = vc + (((vc - avg) * strength) / 100);
                    if (cand < mn) cand = mn;
                    else if (cand > mx) cand = mx;
                    out |= (cand << shift);
                }
                dst[row + x] = out;
            }
        }
    }

    private static void applyEdgeUpscale2xJava(int[] src, int[] dst, int width, int height) {
        int dstW = width * 2;
        final int tol = 12;
        for (int y = 0; y < height; y++) {
            int yUp = y > 0 ? y - 1 : 0;
            int yDn = y + 1 < height ? y + 1 : height - 1;
            int row = y * width;
            int rowUp = yUp * width;
            int rowDn = yDn * width;
            int outTop = (y * 2) * dstW;
            int outBot = outTop + dstW;
            for (int x = 0; x < width; x++) {
                int xLt = x > 0 ? x - 1 : 0;
                int xRt = x + 1 < width ? x + 1 : width - 1;
                int p = src[row + x] | 0xff000000;
                int a = src[rowUp + x] | 0xff000000;
                int d = src[rowDn + x] | 0xff000000;
                int c = src[row + xLt] | 0xff000000;
                int b = src[row + xRt] | 0xff000000;
                int p0 = p, p1 = p, p2 = p, p3 = p;
                boolean diffAB = channelDiffSum(a, b) > tol;
                boolean diffCD = channelDiffSum(c, d) > tol;
                if (channelDiffSum(a, d) > tol && channelDiffSum(c, b) > tol) {
                    if (channelDiffSum(c, a) <= tol && channelDiffSum(c, d) > tol && diffAB) {
                        p0 = (c == a) ? a : blend50(c, a);
                    }
                    if (channelDiffSum(a, b) <= tol && channelDiffSum(a, c) > tol && channelDiffSum(b, d) > tol) {
                        p1 = (a == b) ? b : blend50(a, b);
                    }
                    if (channelDiffSum(d, c) <= tol && channelDiffSum(d, b) > tol && channelDiffSum(c, a) > tol) {
                        p2 = (d == c) ? c : blend50(d, c);
                    }
                    if (channelDiffSum(b, d) <= tol && diffAB && diffCD) {
                        p3 = (b == d) ? d : blend50(b, d);
                    }
                }
                int ox = x * 2;
                dst[outTop + ox] = p0;
                dst[outTop + ox + 1] = p1;
                dst[outBot + ox] = p2;
                dst[outBot + ox + 1] = p3;
            }
        }
    }

    private static void applySharpBilinearPrescaleJava(int[] src, int[] dst, int width, int height) {
        int dstW = width * 2;
        for (int y = 0; y < height; y++) {
            int sRow = y * width;
            int dTop = (y * 2) * dstW;
            int dBot = dTop + dstW;
            for (int x = 0; x < width; x++) {
                int px = src[sRow + x] | 0xff000000;
                int ox = x * 2;
                dst[dTop + ox] = px;
                dst[dTop + ox + 1] = px;
                dst[dBot + ox] = px;
                dst[dBot + ox + 1] = px;
            }
        }
    }

    private void clearTouchPointer() {
        if (touchActive) {
            touchActive = false;
            core.setPointer(0f, 0f, false);
            postInvalidateOnAnimation();
        }
    }

    BrumCoreView(Context context, BrumCoreBridge core, RuntimeErrorListener errorListener) {
        super(context);
        this.core = core;
        this.errorListener = errorListener;
        setBackgroundColor(Color.BLACK);
        paint.setAntiAlias(false);
        paint.setFilterBitmap(false);
        reticlePaint.setStyle(Paint.Style.STROKE);
        reticlePaint.setStrokeWidth(4f);
        reticlePaint.setColor(Color.rgb(157, 255, 59));
        prepareAudio();
    }

    void resumeEmulation() {
        if (running) return;
        running = true;
        if (audioTrack != null && !fastForward) audioTrack.play();
        emulationThread = new Thread(this, "brum-core-loop");
        emulationThread.start();
    }

    void pauseEmulation() {
        running = false;
        for (int p = 0; p < 4; p++) {
            portMasks[p].set(0);
            core.setPortMask(p, 0);
            core.setAnalog(p, 0, 0, 0f);
            core.setAnalog(p, 0, 1, 0f);
            core.setAnalog(p, 1, 0, 0f);
            core.setAnalog(p, 1, 1, 0f);
        }
        clearTouchPointer();
        touchActive = false;
        core.setPointer(0, 0, false);
        if (audioTrack != null) { audioTrack.pause(); audioTrack.flush(); }
        Thread thread = emulationThread;
        if (thread != null && thread != Thread.currentThread()) {
            try { thread.join(3000); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
        }
        emulationThread = null;
        core.clearAudio();
        core.persist();
    }

    void destroy() {
        pauseEmulation();
        if (audioTrack != null) { audioTrack.release(); audioTrack = null; }
        core.close();
    }

    void setVirtualPadPort(int port) {
        virtualPadPort = (port >= 0 && port < 4) ? port : 0;
    }

    void setPokedexCaptureListener(PokedexCaptureListener listener) {
        this.pokedexListener = listener;
    }

    void setButton(int id, boolean pressed) {
        setPortButton(virtualPadPort, id, pressed);
    }

    void setPortButton(int port, int id, boolean pressed) {
        if (port < 0 || port >= 4 || id < 0 || id >= 16) return;
        int bit = 1 << id;
        AtomicInteger target = portMasks[port];
        while (true) {
            int current = target.get();
            int next = pressed ? current | bit : current & ~bit;
            if (target.compareAndSet(current, next)) {
                core.setPortMask(port, next);
                return;
            }
        }
    }

    void setAnalog(int stick, int axis, float value) {
        core.setAnalog(virtualPadPort, stick, axis, value);
    }

    void setPortAnalog(int port, int stick, int axis, float value) {
        core.setAnalog(port, stick, axis, value);
    }

    void setFastForward(boolean enabled) {
        fastForward = enabled;
        if (audioTrack == null) return;
        if (enabled) { audioTrack.pause(); audioTrack.flush(); core.clearAudio(); }
        else if (running) audioTrack.play();
    }

    boolean isFastForward() { return fastForward; }
    void toggleFillDisplay() { fillDisplay = !fillDisplay; clearTouchPointer(); postInvalidateOnAnimation(); }
    @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        clearTouchPointer();
    }
    boolean fillsDisplay() { return fillDisplay; }
    long playedSeconds() { return Math.max(0L, playedNanos / 1_000_000_000L); }

    boolean saveState(String path) {
        boolean wasRunning = running; pauseEmulation();
        boolean saved = core.saveState(path);
        if (wasRunning) resumeEmulation();
        return saved;
    }

    boolean loadState(String path) {
        boolean wasRunning = running; pauseEmulation();
        boolean loaded = core.loadState(path);
        if (audioTrack != null) audioTrack.flush();
        if (wasRunning) resumeEmulation();
        return loaded;
    }

    String diagnosticsJson() {
        try {
            return core.diagnosticsJson();
        } catch (Throwable ignored) {
            return "{}";
        }
    }

    @Override public void run() {
        // Respect the core's declared cadence rather than imposing 60 Hz on
        // 75 Hz and future systems. Rendering remains vsync-driven by Android.
        long nextFrame = System.nanoTime();
        long lastAccounting = System.nanoTime();
        try {
            final long frameDuration = CoreTiming.frameDurationNanos(core.frameRate());
            int pokedexPollCounter = 0;
            int runLoops = 0;
            boolean anyFramePresented = false;
            boolean pspWarned = false;
            while (running) {
                for (int p = 0; p < 4; p++) core.setPortMask(p, portMasks[p].get());
                core.runFrames(fastForward ? 5 : 1, 0);
                ++runLoops;
                if (++pokedexPollCounter >= 15) {
                    pokedexPollCounter = 0;
                    PokedexCaptureListener listener = this.pokedexListener;
                    if (listener != null) {
                        String[] captures = core.drainPokedexCaptures();
                        if (captures != null && captures.length > 0) {
                            for (String cap : captures) {
                                if (cap != null && !cap.isEmpty()) {
                                    final String payload = cap;
                                    post(() -> listener.onPokedexCaptureJson(payload));
                                }
                            }
                        }
                    }
                }
                long dimensions = core.copyFrame(pixels);
                int width = (int) (dimensions >>> 32); int height = (int) dimensions;
                if (width > 0 && height > 0 && (long) width * height <= pixels.length) {
                    anyFramePresented = true;
                    int[] uploadPixels = prepareFilteredFrame(pixels, width, height);
                    int uploadWidth = shaderOutWidth;
                    int uploadHeight = shaderOutHeight;
                    synchronized (bitmapLock) {
                        if (bitmap == null || bitmap.getWidth() != uploadWidth || bitmap.getHeight() != uploadHeight) {
                            if (bitmap != null) bitmap.recycle();
                            bitmap = Bitmap.createBitmap(uploadWidth, uploadHeight, Bitmap.Config.ARGB_8888);
                            bitmap.setHasAlpha(false);
                        }
                        bitmap.setPixels(uploadPixels, 0, uploadWidth, 0, 0, uploadWidth, uploadHeight);
                    }
                    postInvalidateOnAnimation();
                } else if (!anyFramePresented && !pspWarned && runLoops >= 120
                        && ("psp".equals(systemId) || coreName.contains("ppsspp"))) {
                    pspWarned = true;
                    android.util.Log.w("BrumCoreView",
                        "PSP 120 frames sem video visivel: " + diagnosticsJson());
                }
                if (!fastForward && audioTrack != null) {
                    int count;
                    while ((count = core.drainAudio(audioSamples)) > 0) {
                        int written = audioTrack.write(audioSamples, 0, count, AudioTrack.WRITE_BLOCKING);
                        if (written < 0) throw new IllegalStateException("A saída de áudio do Android falhou (código " + written + ").");
                    }
                } else {
                    core.clearAudio();
                }
                long now = System.nanoTime();
                playedNanos += Math.max(0L, Math.min(5_000_000_000L, now - lastAccounting));
                lastAccounting = now;
                if (fastForward) { nextFrame = now; continue; }
                nextFrame += frameDuration;
                if (nextFrame < now - frameDuration * 3) nextFrame = now;
                long remaining;
                while (running && (remaining = nextFrame - System.nanoTime()) > 0) LockSupport.parkNanos(remaining);
            }
        } catch (Throwable error) {
            boolean unexpected = running;
            running = false;
            core.clearAudio();
            String diag = diagnosticsJson();
            android.util.Log.e("BrumCoreView", "Falha em brum-core-loop: " + diag, error);
            String base = error.getMessage() == null ? "O núcleo encontrou uma falha durante a emulação." : error.getMessage();
            String message = (diag != null && diag.length() > 2) ? (base + "\nDiagnóstico: " + diag) : base;
            if (unexpected) post(() -> errorListener.onRuntimeError(message));
        }
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        synchronized (bitmapLock) {
            if (bitmap == null) return;
            int bw = bitmap.getWidth();
            int bh = bitmap.getHeight();
            float scaleX = getWidth() / (float) bw;
            float scaleY = getHeight() / (float) bh;
            float scale = fillDisplay ? Math.max(scaleX, scaleY) : Math.min(scaleX, scaleY);
            if (!fillDisplay && integerScaling && scale >= 1f) {
                scale = (float) Math.floor(scale);
            }
            float width = bw * scale;
            float height = bh * scale;
            sourceRect.set(0, 0, bw, bh);
            targetRect.set((getWidth() - width) / 2f, (getHeight() - height) / 2f,
                (getWidth() + width) / 2f, (getHeight() + height) / 2f);
            displayTarget.set(targetRect);
            canvas.drawBitmap(bitmap, sourceRect, targetRect, paint);
            if ("crt_scanlines".equals(videoFilterMode)) {
                overlayEffectPaint.setColor(Color.argb(48, 0, 0, 0));
                overlayEffectPaint.setStrokeWidth(1.5f);
                for (float y = targetRect.top + 2f; y < targetRect.bottom; y += 4f) {
                    canvas.drawLine(targetRect.left, y, targetRect.right, y, overlayEffectPaint);
                }
            } else if ("lcd_grid".equals(videoFilterMode)) {
                overlayEffectPaint.setColor(Color.argb(34, 0, 0, 0));
                overlayEffectPaint.setStrokeWidth(1f);
                for (float y = targetRect.top + 3f; y < targetRect.bottom; y += 4f) {
                    canvas.drawLine(targetRect.left, y, targetRect.right, y, overlayEffectPaint);
                }
                for (float x = targetRect.left + 3f; x < targetRect.right; x += 4f) {
                    canvas.drawLine(x, targetRect.top, x, targetRect.bottom, overlayEffectPaint);
                }
            }
        }
        if (touchActive) {
            canvas.drawCircle(touchScreenX, touchScreenY, 24f, reticlePaint);
        }
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        if (action != MotionEvent.ACTION_DOWN && action != MotionEvent.ACTION_MOVE && action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL) return true;
        synchronized (bitmapLock) { touchTarget.set(displayTarget); }
        float tw = touchTarget.width();
        float th = touchTarget.height();
        if (tw <= 0f || th <= 0f) {
            clearTouchPointer();
            return true;
        }
        boolean is3ds = "3ds".equals(systemId) || "n3ds".equals(systemId) || coreName.contains("azahar") || coreName.contains("citra");
        boolean isNds = "nds".equals(systemId) || "ds".equals(systemId) || coreName.contains("skyemu") || coreName.contains("desmume") || coreName.contains("melonds");
        float activeLeft = touchTarget.left;
        float activeRight = touchTarget.right;
        float activeTop = touchTarget.top;
        float activeBottom = touchTarget.bottom;
        if (is3ds) {
            activeLeft = touchTarget.left + tw * 0.10f;
            activeRight = touchTarget.left + tw * 0.90f;
            activeTop = touchTarget.top + th * 0.50f;
        } else if (isNds) {
            activeTop = touchTarget.top + th * 0.50f;
        }
        boolean inside = event.getX() >= activeLeft && event.getX() <= activeRight
            && event.getY() >= activeTop && event.getY() <= activeBottom;
        boolean pressed;
        if (action == MotionEvent.ACTION_DOWN) {
            pressed = inside;
        } else if (action == MotionEvent.ACTION_MOVE) {
            pressed = touchActive;
        } else {
            pressed = false;
        }
        if (!pressed) {
            touchActive = false;
            core.setPointer(0f, 0f, false);
            postInvalidateOnAnimation();
            return true;
        }
        float clampedX = Math.max(activeLeft, Math.min(activeRight, event.getX()));
        float clampedY = Math.max(activeTop, Math.min(activeBottom, event.getY()));
        float x = Math.max(-1f, Math.min(1f, ((clampedX - touchTarget.left) / tw) * 2f - 1f));
        float y = Math.max(-1f, Math.min(1f, ((clampedY - touchTarget.top) / th) * 2f - 1f));
        if (isNds || is3ds) {
            // Dual-screen Libretro cores (SkyEmu / Azahar) treat Y == 0 as top-half/pen-up boundary
            y = Math.max(0.002f, y);
        }
        touchActive = true;
        touchScreenX = clampedX;
        touchScreenY = clampedY;
        core.setPointer(x, y, true);
        postInvalidateOnAnimation();
        return true;
    }

    private void prepareAudio() {
        int reportedRate = core.sampleRate();
        int sampleRate = reportedRate >= 8000 && reportedRate <= 192000 ? reportedRate : 48000;
        int minimum = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        if (minimum <= 0) return;
        AudioAttributes attributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build();
        AudioFormat format = new AudioFormat.Builder().setSampleRate(sampleRate).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).build();
        audioTrack = new AudioTrack(attributes, format, minimum * 2, AudioTrack.MODE_STREAM, AudioManager.AUDIO_SESSION_ID_GENERATE);
        if (audioTrack.getState() != AudioTrack.STATE_INITIALIZED) { audioTrack.release(); audioTrack = null; }
    }
}

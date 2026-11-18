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

    private final BrumCoreBridge core;
    private final RuntimeErrorListener errorListener;
    private final AtomicInteger[] portMasks = {
        new AtomicInteger(), new AtomicInteger(), new AtomicInteger(), new AtomicInteger()
    };
    private int virtualPadPort = 0;
    private final int[] pixels = new int[2048 * 2048];
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
    private final RectF displayTarget = new RectF();
    private final Paint reticlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private float touchScreenX;
    private float touchScreenY;
    private boolean touchActive;

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
    void toggleFillDisplay() { fillDisplay = !fillDisplay; postInvalidateOnAnimation(); }
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

    @Override public void run() {
        // Respect the core's declared cadence rather than imposing 60 Hz on
        // 75 Hz and future systems. Rendering remains vsync-driven by Android.
        long nextFrame = System.nanoTime();
        long lastAccounting = System.nanoTime();
        try {
            final long frameDuration = CoreTiming.frameDurationNanos(core.frameRate());
            while (running) {
                for (int p = 0; p < 4; p++) core.setPortMask(p, portMasks[p].get());
                core.runFrames(fastForward ? 5 : 1, 0);
                long dimensions = core.copyFrame(pixels);
                int width = (int) (dimensions >>> 32); int height = (int) dimensions;
                if (width > 0 && height > 0 && (long) width * height <= pixels.length) {
                    synchronized (bitmapLock) {
                        if (bitmap == null || bitmap.getWidth() != width || bitmap.getHeight() != height) {
                            if (bitmap != null) bitmap.recycle();
                            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                            bitmap.setHasAlpha(false);
                        }
                        bitmap.setPixels(pixels, 0, width, 0, 0, width, height);
                    }
                    postInvalidateOnAnimation();
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
            String message = error.getMessage() == null ? "O núcleo encontrou uma falha durante a emulação." : error.getMessage();
            if (unexpected) post(() -> errorListener.onRuntimeError(message));
        }
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        synchronized (bitmapLock) {
            if (bitmap == null) return;
            float scaleX = getWidth() / (float) bitmap.getWidth();
            float scaleY = getHeight() / (float) bitmap.getHeight();
            float scale = fillDisplay ? Math.max(scaleX, scaleY) : Math.min(scaleX, scaleY);
            float width = bitmap.getWidth() * scale; float height = bitmap.getHeight() * scale;
            Rect source = new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight());
            RectF target = new RectF((getWidth() - width) / 2f, (getHeight() - height) / 2f,
                (getWidth() + width) / 2f, (getHeight() + height) / 2f);
            displayTarget.set(target);
            canvas.drawBitmap(bitmap, source, target, paint);
        }
        if (touchActive) {
            canvas.drawCircle(touchScreenX, touchScreenY, 24f, reticlePaint);
        }
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        if (action != MotionEvent.ACTION_DOWN && action != MotionEvent.ACTION_MOVE && action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL) return true;
        RectF target;
        synchronized (bitmapLock) { target = new RectF(displayTarget); }
        boolean inside = target.contains(event.getX(), event.getY());
        boolean pressed = action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL && target.width() > 0 && target.height() > 0 && inside;
        float x = target.width() <= 0 ? 0 : ((event.getX() - target.left) / target.width()) * 2f - 1f;
        float y = target.height() <= 0 ? 0 : ((event.getY() - target.top) / target.height()) * 2f - 1f;
        touchActive = pressed;
        touchScreenX = event.getX();
        touchScreenY = event.getY();
        core.setPointer(x, y, pressed);
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

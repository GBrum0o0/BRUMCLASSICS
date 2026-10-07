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
    private final AtomicInteger inputMask = new AtomicInteger();
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

    BrumCoreView(Context context, BrumCoreBridge core, RuntimeErrorListener errorListener) {
        super(context);
        this.core = core;
        this.errorListener = errorListener;
        setBackgroundColor(Color.BLACK);
        paint.setAntiAlias(false);
        paint.setFilterBitmap(false);
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
        inputMask.set(0);
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

    void setButton(int id, boolean pressed) {
        int bit = 1 << id;
        while (true) {
            int current = inputMask.get();
            int next = pressed ? current | bit : current & ~bit;
            if (inputMask.compareAndSet(current, next)) return;
        }
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
                core.runFrames(fastForward ? 5 : 1, inputMask.get());
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
    }

    @Override public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        if (action != MotionEvent.ACTION_DOWN && action != MotionEvent.ACTION_MOVE && action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL) return true;
        RectF target;
        synchronized (bitmapLock) { target = new RectF(displayTarget); }
        boolean pressed = action != MotionEvent.ACTION_UP && action != MotionEvent.ACTION_CANCEL && target.width() > 0 && target.height() > 0;
        float x = target.width() <= 0 ? 0 : ((event.getX() - target.left) / target.width()) * 2f - 1f;
        float y = target.height() <= 0 ? 0 : ((event.getY() - target.top) / target.height()) * 2f - 1f;
        core.setPointer(x, y, pressed && target.contains(event.getX(), event.getY()));
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

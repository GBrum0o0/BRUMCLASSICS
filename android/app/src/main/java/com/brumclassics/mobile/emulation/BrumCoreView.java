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
import android.os.SystemClock;
import android.view.View;

import java.util.concurrent.atomic.AtomicInteger;

final class BrumCoreView extends View implements Runnable {
    private final BrumCoreBridge core;
    private final AtomicInteger inputMask = new AtomicInteger();
    private final int[] pixels = new int[1024 * 1024];
    private final short[] audioSamples = new short[16 * 1024];
    private final Object bitmapLock = new Object();
    private final Paint paint = new Paint();
    private Bitmap bitmap;
    private Thread emulationThread;
    private volatile boolean running;
    private volatile boolean fastForward;
    private volatile boolean fillDisplay = true;
    private AudioTrack audioTrack;
    private long playedNanos;

    BrumCoreView(Context context, BrumCoreBridge core) {
        super(context);
        this.core = core;
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
        Thread thread = emulationThread;
        if (thread != null && thread != Thread.currentThread()) {
            try { thread.join(1200); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
        }
        emulationThread = null;
        if (audioTrack != null) { audioTrack.pause(); audioTrack.flush(); }
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
        if (enabled) { audioTrack.pause(); audioTrack.flush(); }
        else if (running) audioTrack.play();
    }

    boolean isFastForward() { return fastForward; }
    void toggleFillDisplay() { fillDisplay = !fillDisplay; postInvalidateOnAnimation(); }
    boolean fillsDisplay() { return fillDisplay; }
    long playedSeconds() { return Math.max(0L, playedNanos / 1_000_000_000L); }

    @Override public void run() {
        final long frameDuration = 16_666_667L;
        long lastAccounting = System.nanoTime();
        while (running) {
            long started = System.nanoTime();
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
                while ((count = core.drainAudio(audioSamples)) > 0) audioTrack.write(audioSamples, 0, count, AudioTrack.WRITE_BLOCKING);
            } else {
                core.drainAudio(audioSamples);
            }
            long elapsed = System.nanoTime() - started;
            long now = System.nanoTime();
            playedNanos += Math.max(0L, Math.min(5_000_000_000L, now - lastAccounting));
            lastAccounting = now;
            long remaining = frameDuration - elapsed;
            if (remaining > 0) SystemClock.sleep(Math.max(0L, remaining / 1_000_000L));
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
            canvas.drawBitmap(bitmap, source, target, paint);
        }
    }

    private void prepareAudio() {
        int sampleRate = Math.max(8000, core.sampleRate());
        int minimum = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        if (minimum <= 0) return;
        AudioAttributes attributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build();
        AudioFormat format = new AudioFormat.Builder().setSampleRate(sampleRate).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).build();
        audioTrack = new AudioTrack(attributes, format, minimum * 2, AudioTrack.MODE_STREAM, AudioManager.AUDIO_SESSION_ID_GENERATE);
        if (audioTrack.getState() != AudioTrack.STATE_INITIALIZED) { audioTrack.release(); audioTrack = null; }
    }
}

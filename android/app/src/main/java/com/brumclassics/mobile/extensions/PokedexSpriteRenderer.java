package com.brumclassics.mobile.extensions;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;
import android.util.AtomicFile;
import android.util.LruCache;
import android.view.View;
import android.view.ViewTreeObserver;
import android.widget.ImageView;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.lang.ref.WeakReference;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.PriorityBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/** Actual species sprites, on demand. Hidden silhouettes use the same image alpha. */
public final class PokedexSpriteRenderer {
    public static final int MODE_SILHOUETTE = 0, MODE_NORMAL = 1, MODE_SHINY = 2;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final AtomicLong SEQUENCE = new AtomicLong();
    private static final Map<String, Fetch> IN_FLIGHT = new HashMap<>();
    private static final ThreadPoolExecutor WORK = new ThreadPoolExecutor(3, 3, 0L,
            TimeUnit.MILLISECONDS, new PriorityBlockingQueue<Runnable>());
    private static final LruCache<String, Bitmap> CACHE = new LruCache<String, Bitmap>(8 * 1024 * 1024) {
        @Override protected int sizeOf(String key, Bitmap value) { return value.getByteCount(); }
    };
    private PokedexSpriteRenderer() {}
    public static String spriteUrl(int dex, int mode) {
        return "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
                + (mode == MODE_SHINY ? "shiny/" : "") + Math.max(1, Math.min(802, dex)) + ".png";
    }
    public static void bind(ImageView target, int dex, int mode) { bind(target, dex, mode, false); }
    public static void bind(ImageView target, int dex, int mode, boolean selected) {
        String address = spriteUrl(dex, mode), request = address + ":" + mode;
        target.setTag(request);
        target.setImageDrawable(null);
        if (mode == MODE_SILHOUETTE) target.setColorFilter(Color.BLACK, PorterDuff.Mode.SRC_IN);
        else target.clearColorFilter();
        target.setContentDescription((mode == MODE_SILHOUETTE ? "Silhueta da espécie número " : "Imagem da espécie número ") + dex);
        Bitmap cached = CACHE.get(address);
        if (cached != null) { target.setImageBitmap(cached); return; }
        if (selected) enqueue(target, dex, mode, true);
        else new VisibleLoad(target, dex, mode).attach();
    }
    // Off-screen rows never enqueue downloads or retain Activities in the worker queue.
    private static final class VisibleLoad implements View.OnAttachStateChangeListener,
            ViewTreeObserver.OnScrollChangedListener, View.OnLayoutChangeListener {
        final WeakReference<ImageView> target; final int dex, mode; final Rect visible = new Rect();
        ViewTreeObserver observer;
        VisibleLoad(ImageView view, int dex, int mode) { target = new WeakReference<>(view); this.dex = dex; this.mode = mode; }
        void attach() { ImageView view = target.get(); if (view == null) return; view.addOnAttachStateChangeListener(this); if (view.isAttachedToWindow()) onViewAttachedToWindow(view); }
        void unwatch() { if (observer != null && observer.isAlive()) observer.removeOnScrollChangedListener(this); observer = null; ImageView view = target.get(); if (view != null) view.removeOnLayoutChangeListener(this); }
        void check() {
            ImageView view = target.get();
            if (view == null) { unwatch(); return; }
            if (!(spriteUrl(dex, mode) + ":" + mode).equals(view.getTag())) { unwatch(); view.removeOnAttachStateChangeListener(this); return; }
            if (view.isAttachedToWindow() && view.getGlobalVisibleRect(visible) && !visible.isEmpty()) {
                unwatch(); view.removeOnAttachStateChangeListener(this); enqueue(view, dex, mode, false);
            }
        }
        @Override public void onViewAttachedToWindow(View view) { unwatch(); observer = view.getViewTreeObserver(); observer.addOnScrollChangedListener(this); view.addOnLayoutChangeListener(this); view.post(this::check); }
        @Override public void onViewDetachedFromWindow(View view) { unwatch(); }
        @Override public void onScrollChanged() { check(); }
        @Override public void onLayoutChange(View v, int a, int b, int c, int d, int e, int f, int g, int h) { check(); }
    }
    private static void enqueue(ImageView target, int dex, int mode, boolean selected) {
        String address = spriteUrl(dex, mode);
        Bitmap cached = CACHE.get(address);
        if (cached != null) { target.setImageBitmap(cached); return; }
        synchronized (IN_FLIGHT) {
            Fetch fetch = IN_FLIGHT.get(address);
            if (fetch == null) {
                // A bound also covers rapid page recreation while offline.
                if (IN_FLIGHT.size() >= 64) { unavailable(target); return; }
                File folder = new File(target.getContext().getCacheDir(), "brum-pokedex-images");
                File file = new File(folder, Math.max(1, Math.min(802, dex)) + (mode == MODE_SHINY ? "-shiny.png" : "-normal.png"));
                fetch = new Fetch(address, folder, file, selected ? 0 : 1);
                IN_FLIGHT.put(address, fetch);
                fetch.listeners.add(new Subscriber(target));
                WORK.execute(fetch);
            } else {
                fetch.listeners.add(new Subscriber(target));
                if (selected && fetch.priority != 0 && WORK.getQueue().remove(fetch)) {
                    fetch.priority = 0; WORK.execute(fetch);
                }
            }
        }
    }
    private static void unavailable(ImageView target) {
        target.clearColorFilter(); target.setImageResource(android.R.drawable.ic_menu_report_image);
        target.setContentDescription("Imagem indisponível. Conecte à internet e tente novamente.");
    }
    private static final class Subscriber {
        final WeakReference<ImageView> target; final Object request;
        Subscriber(ImageView view) { target = new WeakReference<>(view); request = view.getTag(); }
    }
    private static final class Fetch implements Runnable, Comparable<Fetch> {
        final String address; final File folder, file; final long sequence = SEQUENCE.incrementAndGet();
        final List<Subscriber> listeners = new ArrayList<>(); int priority;
        Fetch(String address, File folder, File file, int priority) { this.address = address; this.folder = folder; this.file = file; this.priority = priority; }
        @Override public int compareTo(Fetch other) { int p = Integer.compare(priority, other.priority); return p == 0 ? Long.compare(sequence, other.sequence) : p; }
        @Override public void run() {
            Bitmap image = CACHE.get(address);
            if (image == null && file.isFile()) {
                try (InputStream input = new FileInputStream(file)) { image = decode(readLimited(input)); }
                catch (Exception ignored) { /* Corrupt cache falls through to the remote source. */ }
            }
            if (image == null) {
                try {
                    HttpURLConnection connection = (HttpURLConnection) new URL(address).openConnection();
                    connection.setConnectTimeout(10000); connection.setReadTimeout(15000); connection.setInstanceFollowRedirects(false);
                    try {
                        if (connection.getResponseCode() != 200) throw new java.io.IOException("Sprite unavailable");
                        byte[] bytes; try (InputStream input = connection.getInputStream()) { bytes = readLimited(input); }
                        image = decode(bytes); if (image == null) throw new java.io.IOException("Invalid sprite");
                        if (folder.isDirectory() || folder.mkdirs()) {
                            AtomicFile atomic = new AtomicFile(file); FileOutputStream output = null;
                            try { output = atomic.startWrite(); output.write(bytes); atomic.finishWrite(output); }
                            catch (java.io.IOException error) { if (output != null) atomic.failWrite(output); }
                        }
                    } finally { connection.disconnect(); }
                } catch (Exception ignored) { /* Never synthesize an invented species. */ }
            }
            if (image != null) CACHE.put(address, image);
            final Bitmap result = image;
            final List<Subscriber> notify;
            synchronized (IN_FLIGHT) { IN_FLIGHT.remove(address); notify = new ArrayList<>(listeners); }
            MAIN.post(() -> { for (Subscriber subscriber : notify) {
                ImageView view = subscriber.target.get();
                if (view == null || !subscriber.request.equals(view.getTag())) continue;
                if (result != null) view.setImageBitmap(result); else unavailable(view);
            }});
        }
    }
    private static byte[] readLimited(InputStream input) throws java.io.IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int count;
        while ((count = input.read(buffer)) != -1) { if (out.size() + count > 1_048_576) throw new java.io.IOException("Sprite too large"); out.write(buffer, 0, count); }
        return out.toByteArray();
    }
    private static Bitmap decode(byte[] bytes) {
        BitmapFactory.Options bounds = new BitmapFactory.Options(); bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
        if (bounds.outWidth < 1 || bounds.outHeight < 1 || bounds.outWidth > 1024 || bounds.outHeight > 1024) return null;
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    }
}

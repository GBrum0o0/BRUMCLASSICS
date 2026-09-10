package com.brumclassics.mobile.classics;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.util.AtomicFile;
import android.util.LruCache;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class LocalArtworkClient {
    public interface Callback { void onBitmap(Bitmap bitmap); }
    private final File root;
    private final ExecutorService executor = Executors.newFixedThreadPool(3);
    private final Handler main = new Handler(Looper.getMainLooper());
    private final LruCache<String, Bitmap> memory = new LruCache<String, Bitmap>(12 * 1024) {
        @Override protected int sizeOf(String key, Bitmap bitmap) { return Math.max(1, bitmap.getByteCount() / 1024); }
    };
    private final ConcurrentHashMap<String, Boolean> pending = new ConcurrentHashMap<>();

    public LocalArtworkClient(Context context) {
        root = new File(context.getFilesDir(), "classics-local-artwork"); if (!root.exists()) root.mkdirs();
    }

    public void load(LocalClassic game, Callback callback) {
        String repository = ClassicsRules.artworkRepository(game.filename); if (repository == null) return;
        final String key;
        try { key = sha256(repository + ":" + game.filename); } catch (Exception ignored) { return; }
        Bitmap cached = memory.get(key); if (cached != null && !cached.isRecycled()) { callback.onBitmap(cached); return; }
        if (pending.putIfAbsent(key, true) != null) return;
        executor.execute(() -> {
            Bitmap bitmap = null;
            try {
                File image = new File(root, key + ".png");
                if (!image.isFile()) download(repository, game.filename, image);
                bitmap = decode(image); if (bitmap != null) memory.put(key, bitmap);
            } catch (Exception ignored) {
            } finally {
                pending.remove(key); Bitmap result = bitmap; if (result != null) main.post(() -> callback.onBitmap(result));
            }
        });
    }

    public void close() { executor.shutdownNow(); }

    private void download(String repository, String filename, File target) throws Exception {
        List<String> paths = index(repository); String match = ClassicsRules.matchArtwork(filename, paths); if (match == null) return;
        URL url = new URI("https", "raw.githubusercontent.com", "/libretro-thumbnails/" + repository + "/master/" + match, null).toURL();
        HttpURLConnection connection = open(url); byte[] bytes = readResponse(connection, 8 * 1024 * 1024);
        BitmapFactory.Options bounds = new BitmapFactory.Options(); bounds.inJustDecodeBounds = true; BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw new IllegalStateException("Capa inválida.");
        AtomicFile file = new AtomicFile(target); FileOutputStream output = null;
        try { output = file.startWrite(); output.write(bytes); output.getFD().sync(); file.finishWrite(output); }
        catch (Exception error) { if (output != null) file.failWrite(output); throw error; }
    }

    private List<String> index(String repository) throws Exception {
        File cache = new File(root, repository + ".json");
        if (cache.isFile() && System.currentTimeMillis() - cache.lastModified() < 7L * 24L * 60L * 60L * 1000L) return decodeIndex(readFile(cache, 12 * 1024 * 1024));
        try {
            URL url = new URL("https://api.github.com/repos/libretro-thumbnails/" + repository + "/git/trees/master?recursive=1");
            byte[] bytes = readResponse(open(url), 12 * 1024 * 1024); List<String> result = decodeIndex(bytes);
            AtomicFile file = new AtomicFile(cache); FileOutputStream output = null;
            try { output = file.startWrite(); output.write(bytes); output.getFD().sync(); file.finishWrite(output); }
            catch (Exception error) { if (output != null) file.failWrite(output); }
            return result;
        } catch (Exception error) { if (cache.isFile()) return decodeIndex(readFile(cache, 12 * 1024 * 1024)); throw error; }
    }

    private List<String> decodeIndex(byte[] bytes) throws Exception {
        JSONObject root = new JSONObject(new String(bytes, StandardCharsets.UTF_8)); if (root.optBoolean("truncated")) throw new IllegalStateException("Índice de capas incompleto.");
        JSONArray tree = root.optJSONArray("tree"); if (tree == null) throw new IllegalStateException("Índice de capas inválido.");
        List<String> paths = new ArrayList<>();
        for (int index = 0; index < tree.length(); index++) { JSONObject item = tree.optJSONObject(index); if (item == null) continue; String path = item.optString("path"); if ("blob".equals(item.optString("type")) && path.startsWith("Named_Boxarts/") && path.toLowerCase(Locale.ROOT).endsWith(".png")) paths.add(path); }
        return paths;
    }

    private HttpURLConnection open(URL url) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) url.openConnection(); connection.setConnectTimeout(8_000); connection.setReadTimeout(20_000);
        connection.setUseCaches(false); connection.setRequestProperty("Accept", "application/json,image/png,*/*"); connection.setRequestProperty("User-Agent", "BRUMCLASSICS-Android/0.16.0"); return connection;
    }

    private byte[] readResponse(HttpURLConnection connection, int maximum) throws Exception {
        if (connection.getResponseCode() != 200) throw new IllegalStateException("Capa indisponível.");
        try (InputStream input = connection.getInputStream()) { return readAll(input, maximum); }
    }

    private byte[] readFile(File file, int maximum) throws Exception { try (InputStream input = new FileInputStream(file)) { return readAll(input, maximum); } }
    private byte[] readAll(InputStream input, int maximum) throws Exception { ByteArrayOutputStream output = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int read; int total = 0; while ((read = input.read(buffer)) >= 0) { total += read; if (total > maximum) throw new IllegalStateException("Arquivo grande demais."); output.write(buffer, 0, read); } return output.toByteArray(); }
    private Bitmap decode(File file) { BitmapFactory.Options options = new BitmapFactory.Options(); options.inPreferredConfig = Bitmap.Config.RGB_565; return BitmapFactory.decodeFile(file.getAbsolutePath(), options); }
    private String sha256(String value) throws Exception { byte[] bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)); StringBuilder result = new StringBuilder(); for (byte item : bytes) result.append(String.format(Locale.ROOT, "%02x", item)); return result.toString(); }
}

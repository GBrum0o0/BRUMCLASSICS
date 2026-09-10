package com.brumclassics.mobile.data;

import android.content.Context;
import android.util.AtomicFile;

import com.brumclassics.mobile.model.Moment;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

public final class MomentRepository {
    private final File directory;
    private final File indexFile;

    public MomentRepository(Context context) {
        directory = new File(context.getFilesDir(), "brummoments");
        indexFile = new File(directory, "moments.json");
        if (!directory.exists()) directory.mkdirs();
    }

    public synchronized List<Moment> all() {
        List<Moment> result = new ArrayList<>();
        try {
            JSONArray array = readArray();
            for (int index = 0; index < array.length(); index++) {
                JSONObject item = array.optJSONObject(index);
                if (item == null) continue;
                File image = new File(directory, item.optString("file", ""));
                if (!image.isFile()) continue;
                result.add(fromJson(item, image));
            }
        } catch (Exception ignored) { }
        Collections.reverse(result);
        return result;
    }

    public synchronized Moment save(byte[] png, JSONObject metadata, String location, String note, String category) throws Exception {
        if (png == null || png.length < 8 || png.length > 40 * 1024 * 1024) throw new IllegalArgumentException("Imagem inválida.");
        String id = UUID.randomUUID().toString();
        String fileName = id + ".png";
        File image = new File(directory, fileName);
        try (FileOutputStream output = new FileOutputStream(image)) { output.write(png); output.getFD().sync(); }
        JSONObject item = new JSONObject();
        item.put("id", id); item.put("gameId", metadata.optString("gameId", ""));
        item.put("gameTitle", metadata.optString("gameTitle", "Jogo"));
        item.put("capturedAt", metadata.optString("capturedAt", "")); item.put("file", fileName);
        item.put("location", clean(location, 160)); item.put("note", clean(note, 1200));
        item.put("category", clean(category, 40)); item.put("favorite", false);
        JSONArray array = readArray(); array.put(item); writeArray(array);
        return fromJson(item, image);
    }

    public synchronized void update(String id, String location, String note, String category, boolean favorite) throws Exception {
        JSONArray array = readArray();
        for (int index = 0; index < array.length(); index++) {
            JSONObject item = array.optJSONObject(index);
            if (item != null && id.equals(item.optString("id"))) {
                item.put("location", clean(location, 160)); item.put("note", clean(note, 1200));
                item.put("category", clean(category, 40)); item.put("favorite", favorite); break;
            }
        }
        writeArray(array);
    }

    public synchronized void remove(String id) throws Exception {
        JSONArray source = readArray(); JSONArray next = new JSONArray();
        for (int index = 0; index < source.length(); index++) {
            JSONObject item = source.optJSONObject(index);
            if (item == null) continue;
            if (id.equals(item.optString("id"))) { new File(directory, item.optString("file", "")).delete(); continue; }
            next.put(item);
        }
        writeArray(next);
    }

    private Moment fromJson(JSONObject item, File image) {
        return new Moment(item.optString("id"), item.optString("gameId"), item.optString("gameTitle"),
            item.optString("capturedAt"), image.getAbsolutePath(), item.optString("location"),
            item.optString("note"), item.optString("category", "MOMENTO"), item.optBoolean("favorite", false));
    }

    private JSONArray readArray() throws Exception {
        if (!indexFile.isFile()) return new JSONArray();
        try (FileInputStream input = new FileInputStream(indexFile); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192]; int read;
            while ((read = input.read(buffer)) >= 0) { if (output.size() + read > 2 * 1024 * 1024) throw new IllegalStateException("Galeria muito grande."); output.write(buffer, 0, read); }
            return new JSONArray(output.toString("UTF-8"));
        }
    }

    private void writeArray(JSONArray array) throws Exception {
        AtomicFile atomic = new AtomicFile(indexFile); FileOutputStream output = null;
        try { output = atomic.startWrite(); output.write(array.toString().getBytes("UTF-8")); output.getFD().sync(); atomic.finishWrite(output); }
        catch (Exception error) { if (output != null) atomic.failWrite(output); throw error; }
    }

    private String clean(String value, int max) { String result = value == null ? "" : value.trim(); return result.length() > max ? result.substring(0, max) : result; }
}

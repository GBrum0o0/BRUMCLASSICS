package com.brumclassics.mobile.extensions;

import android.content.Context;
import android.util.AtomicFile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class PokedexUniversalStore {
    private final File storageDir;
    private final String ownerProfileId;
    private final PokedexUniversalEngine engine;

    public PokedexUniversalStore(Context context, String ownerProfileId) {
        this(new File(context.getFilesDir(), "extensions/brum.ext.pokedex"), ownerProfileId);
    }

    public PokedexUniversalStore(File baseDir, String ownerProfileId) {
        this.ownerProfileId = (ownerProfileId == null || ownerProfileId.trim().isEmpty()) ? "primary" : ownerProfileId.trim();
        this.storageDir = new File(new File(baseDir, "profiles"), this.ownerProfileId);
        if (!this.storageDir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            this.storageDir.mkdirs();
        }
        this.engine = new PokedexUniversalEngine(this.ownerProfileId);
        loadFromDisk();
    }

    private File collectionFile() {
        return new File(storageDir, "collection-v1.json");
    }

    private synchronized void loadFromDisk() {
        File file = collectionFile();
        if (!file.isFile()) return;
        try {
            AtomicFile atomic = new AtomicFile(file);
            byte[] bytes;
            try (FileInputStream in = atomic.openRead()) {
                bytes = new byte[(int) file.length()];
                int offset = 0;
                int read;
                while (offset < bytes.length && (read = in.read(bytes, offset, bytes.length - offset)) >= 0) {
                    offset += read;
                }
            }
            JSONObject root = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
            JSONArray arr = root.optJSONArray("records");
            if (arr != null) {
                List<PokedexUniversalEngine.CaptureRecord> list = new ArrayList<>();
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject obj = arr.optJSONObject(i);
                    if (obj == null) continue;
                    list.add(recordFromJson(obj, ownerProfileId));
                }
                engine.mergeRecords(list);
            }
        } catch (Exception ignored) {
        }
    }

    private synchronized void saveToDisk() throws Exception {
        JSONObject root = toSyncStateJson();
        AtomicFile atomic = new AtomicFile(collectionFile());
        FileOutputStream out = null;
        try {
            out = atomic.startWrite();
            out.write(root.toString(2).getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
            atomic.finishWrite(out);
        } catch (Exception e) {
            if (out != null) atomic.failWrite(out);
            throw e;
        }
    }

    public static PokedexUniversalEngine.CaptureRecord recordFromJson(JSONObject obj, String fallbackProfileId) {
        int dex = obj.optInt("nationalDexNumber", 0);
        int gen = obj.optInt("generation", 1);
        boolean shiny = obj.optBoolean("isShiny", false) || "shiny".equals(obj.optString("category", ""));
        return new PokedexUniversalEngine.CaptureRecord(
                obj.optString("captureId", null),
                obj.optString("ownerProfileId", fallbackProfileId),
                dex,
                gen,
                obj.optString("speciesName", ""),
                obj.optString("speciesDescription", ""),
                shiny ? PokedexUniversalEngine.CATEGORY_SHINY : PokedexUniversalEngine.CATEGORY_NORMAL,
                obj.optString("firstCapturedGame", obj.optString("gameTitle", "Pokémon FireRed Version")),
                obj.optString("firstCapturedGameId", obj.optString("gameId", "")),
                obj.optString("systemId", "gba"),
                obj.optString("capturedAt", ""),
                obj.optString("captureLocation", PokedexUniversalEngine.UNKNOWN_LOCATION),
                obj.optString("sourceDeviceId", "android-mobile")
        );
    }

    public static JSONObject recordToJson(PokedexUniversalEngine.CaptureRecord r) throws Exception {
        JSONObject obj = new JSONObject();
        obj.put("captureId", r.captureId);
        obj.put("ownerProfileId", r.ownerProfileId);
        obj.put("nationalDexNumber", r.nationalDexNumber);
        obj.put("formattedNumber", r.formattedNumber);
        obj.put("generation", r.generation);
        obj.put("speciesName", r.speciesName);
        obj.put("speciesDescription", r.speciesDescription);
        obj.put("category", r.category);
        obj.put("isShiny", r.isShiny);
        obj.put("firstCapturedGame", r.firstCapturedGame);
        obj.put("firstCapturedGameId", r.firstCapturedGameId);
        obj.put("systemId", r.systemId);
        obj.put("capturedAt", r.capturedAt);
        obj.put("captureLocation", r.captureLocation);
        obj.put("sourceDeviceId", r.sourceDeviceId);
        return obj;
    }

    public synchronized JSONObject toSyncStateJson() throws Exception {
        List<PokedexUniversalEngine.CaptureRecord> records = engine.sortedRecords();
        JSONArray arr = new JSONArray();
        for (PokedexUniversalEngine.CaptureRecord r : records) {
            arr.put(recordToJson(r));
        }
        JSONObject root = new JSONObject();
        root.put("schemaVersion", 1);
        root.put("extensionId", BrumExtensionContract.POKEDEX_EXTENSION_ID);
        root.put("catalogVersion", "1.0.0");
        root.put("ownerProfileId", ownerProfileId);
        root.put("syncRevision", engine.getSyncRevision());
        root.put("contentSha256", engine.contentSha256());
        root.put("records", arr);
        return root;
    }

    public synchronized PokedexUniversalEngine.RecordOutcome recordCapture(
            int nationalDexNumber,
            boolean isShiny,
            String gameTitle,
            String gameId,
            String systemId,
            String capturedAt,
            String captureLocation
    ) throws Exception {
        PokedexUniversalEngine.RecordOutcome out = engine.recordCapture(
                nationalDexNumber, isShiny, gameTitle, gameId, systemId, capturedAt, captureLocation, "android-mobile"
        );
        if (out.recorded) {
            saveToDisk();
        }
        return out;
    }

    public synchronized PokedexUniversalEngine.MergeOutcome mergeSyncPayload(JSONObject incoming) throws Exception {
        JSONArray arr = incoming.optJSONArray("records");
        List<PokedexUniversalEngine.CaptureRecord> list = new ArrayList<>();
        if (arr != null) {
            for (int i = 0; i < arr.length(); i++) {
                JSONObject item = arr.optJSONObject(i);
                if (item != null) {
                    list.add(recordFromJson(item, ownerProfileId));
                }
            }
        }
        PokedexUniversalEngine.MergeOutcome outcome = engine.mergeRecords(list);
        if (outcome.addedCount > 0 || outcome.replacedWithEarlierCount > 0) {
            saveToDisk();
        }
        return outcome;
    }

    public synchronized PokedexUniversalEngine.ProjectedView projectView() {
        return engine.projectView();
    }
}

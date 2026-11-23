package com.brumclassics.mobile.extensions;

import android.content.Context;
import android.util.AtomicFile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class PokedexUniversalStore {
    private final File storageDir;
    private final String ownerProfileId;
    private PokedexUniversalEngine engine;
    private static final java.util.concurrent.ConcurrentHashMap<String, Object> FILE_LOCKS = new java.util.concurrent.ConcurrentHashMap<>();

    private Object fileLock() { return FILE_LOCKS.computeIfAbsent(storageDir.getAbsolutePath(), key -> new Object()); }

    private interface Mutation<T> { T apply(PokedexUniversalEngine candidate) throws Exception; }

    private <T> T transact(Mutation<T> mutation) throws Exception {
        synchronized (fileLock()) {
            loadFromDisk();
            PokedexUniversalEngine candidate = engine.copy();
            T result = mutation.apply(candidate);
            if (candidate.getSyncRevision() != engine.getSyncRevision()) saveToDisk(candidate);
            engine = candidate;
            return result;
        }
    }

    public PokedexUniversalStore(Context context, String ownerProfileId) {
        this(new File(context.getFilesDir(), "extensions/brum.ext.pokedex"), ownerProfileId);
    }

    public PokedexUniversalStore(File baseDir, String ownerProfileId) {
        this.ownerProfileId = PokedexUniversalEngine.validateProfileId(ownerProfileId);
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

    private File enabledFile() {
        return new File(storageDir, "enabled.json");
    }

    public synchronized boolean isExtensionEnabled() {
        File file = enabledFile();
        if (!file.isFile()) return true;
        try {
            AtomicFile atomic = new AtomicFile(file);
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            try (FileInputStream in = atomic.openRead()) {
                byte[] chunk = new byte[1024];
                int read;
                while ((read = in.read(chunk)) >= 0) {
                    buffer.write(chunk, 0, read);
                }
            }
            JSONObject root = new JSONObject(new String(buffer.toByteArray(), StandardCharsets.UTF_8));
            return root.optBoolean("enabled", true);
        } catch (Exception ignored) {
            return true;
        }
    }

    public synchronized void setExtensionEnabled(boolean enabled) {
        try {
            JSONObject root = new JSONObject();
            root.put("extensionId", BrumExtensionContract.POKEDEX_EXTENSION_ID);
            root.put("profileId", ownerProfileId);
            root.put("enabled", enabled);
            AtomicFile atomic = new AtomicFile(enabledFile());
            FileOutputStream out = null;
            try {
                out = atomic.startWrite();
                out.write(root.toString(2).getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
                atomic.finishWrite(out);
            } catch (Exception e) {
                if (out != null) atomic.failWrite(out);
            }
        } catch (Exception ignored) {
        }
    }

    public synchronized void loadFromDisk() {
        File file = collectionFile();
        File bakFile = new File(file.getPath() + ".bak");
        if (!file.isFile() && !bakFile.isFile()) return;
        try {
            AtomicFile atomic = new AtomicFile(file);
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            try (FileInputStream in = atomic.openRead()) {
                byte[] chunk = new byte[8192];
                int read;
                while ((read = in.read(chunk)) >= 0) {
                    buffer.write(chunk, 0, read);
                }
            }
            JSONObject root = new JSONObject(new String(buffer.toByteArray(), StandardCharsets.UTF_8));
            JSONArray arr = root.optJSONArray("records");
            if (arr != null) {
                List<PokedexUniversalEngine.CaptureRecord> list = new ArrayList<>();
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject obj = arr.optJSONObject(i);
                    if (obj == null) continue;
                    list.add(recordFromJson(obj, ownerProfileId));
                }
                engine.mergeRecords(list, ownerProfileId);
            }
        } catch (Exception ignored) {
        }
    }

    private void saveToDisk(PokedexUniversalEngine candidate) throws Exception {
        JSONObject root = toSyncStateJson(candidate);
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
        for (String key : new String[]{"ownerProfileId", "captureId", "speciesName", "firstCapturedGame", "firstCapturedGameId", "systemId", "capturedAt", "captureLocation"}) {
            if (obj.has(key) && !(obj.opt(key) instanceof String)) throw new IllegalArgumentException("Campo de captura deve ser texto: " + key);
        }
        if (!(obj.opt("capturedAt") instanceof String) || obj.optString("capturedAt").trim().isEmpty()) {
            throw new IllegalArgumentException("Data de captura ausente.");
        }
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
        return toSyncStateJson(engine);
    }

    private JSONObject toSyncStateJson(PokedexUniversalEngine source) throws Exception {
        List<PokedexUniversalEngine.CaptureRecord> records = source.sortedRecords();
        JSONArray arr = new JSONArray();
        for (PokedexUniversalEngine.CaptureRecord r : records) {
            arr.put(recordToJson(r));
        }
        JSONObject root = new JSONObject();
        root.put("schemaVersion", 1);
        root.put("extensionId", BrumExtensionContract.POKEDEX_EXTENSION_ID);
        root.put("catalogVersion", "1.0.0");
        root.put("ownerProfileId", ownerProfileId);
        root.put("syncRevision", source.getSyncRevision());
        root.put("contentSha256", source.contentSha256());
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
        return transact(candidate -> candidate.recordCapture(
                nationalDexNumber, isShiny, gameTitle, gameId, systemId, capturedAt, captureLocation, "android-mobile"));
    }

    public synchronized PokedexUniversalEngine.MergeOutcome mergeSyncPayload(JSONObject incoming) throws Exception {
        if (incoming == null) {
            throw new IllegalArgumentException("Payload de sincronização da Pokédex inválido.");
        }
        String incomingProfile = incoming.optString("ownerProfileId", ownerProfileId);
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
        return transact(candidate -> candidate.mergeRecords(list, incomingProfile));
    }

    public synchronized JSONObject exportBackupJson() throws Exception {
        PokedexUniversalEngine.BackupBundle b = engine.exportBackup();
        JSONArray arr = new JSONArray();
        for (PokedexUniversalEngine.CaptureRecord r : b.records) {
            arr.put(recordToJson(r));
        }
        JSONObject out = new JSONObject();
        out.put("schemaVersion", b.schemaVersion);
        out.put("backupType", b.backupType);
        out.put("ownerProfileId", b.ownerProfileId);
        out.put("catalogVersion", "1.0.0");
        out.put("syncRevision", b.syncRevision);
        out.put("recordCount", b.recordCount);
        out.put("contentSha256", b.contentSha256);
        out.put("records", arr);
        return out;
    }

    public synchronized PokedexUniversalEngine.MergeOutcome restoreBackupJson(JSONObject bundleJson) throws Exception {
        if (bundleJson == null) {
            throw new IllegalArgumentException("Arquivo de backup da Pokédex inválido.");
        }
        JSONArray arr = bundleJson.optJSONArray("records");
        List<PokedexUniversalEngine.CaptureRecord> list = new ArrayList<>();
        if (arr != null) {
            for (int i = 0; i < arr.length(); i++) {
                JSONObject item = arr.optJSONObject(i);
                if (item != null) {
                    list.add(recordFromJson(item, ownerProfileId));
                }
            }
        }
        PokedexUniversalEngine.BackupBundle bundle = new PokedexUniversalEngine.BackupBundle(
                bundleJson.optInt("schemaVersion", 0),
                bundleJson.optString("backupType", ""),
                bundleJson.optString("ownerProfileId", ownerProfileId),
                bundleJson.optInt("syncRevision", 1),
                bundleJson.optInt("recordCount", -1),
                bundleJson.optString("contentSha256", ""),
                list
        );
        return transact(candidate -> candidate.restoreBackup(bundle));
    }

    public synchronized PokedexUniversalEngine.ProjectedView projectView() {
        return engine.projectView();
    }
}

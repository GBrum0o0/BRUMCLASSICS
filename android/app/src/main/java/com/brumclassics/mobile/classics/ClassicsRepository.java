package com.brumclassics.mobile.classics;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import android.util.AtomicFile;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class ClassicsRepository {
    private static final int MAX_FILES = 10_000;
    private static final long MAX_ROM_BYTES = 8L * 1024L * 1024L * 1024L;
    private static final long MAX_SESSION_SECONDS = 24L * 60L * 60L;
    private final Context context;
    private final ContentResolver resolver;
    private final SharedPreferences preferences;
    private final AtomicFile catalogFile;
    private final SecureSecretStore secrets;
    private final List<LocalClassic> games = new ArrayList<>();

    public ClassicsRepository(Context context) {
        this.context = context.getApplicationContext(); resolver = context.getContentResolver();
        preferences = context.getSharedPreferences("brum_classics_android", Context.MODE_PRIVATE);
        catalogFile = new AtomicFile(new File(context.getFilesDir(), "classics-everywhere-android.json"));
        secrets = new SecureSecretStore(context);
        load();
    }

    public synchronized List<LocalClassic> all() { return new ArrayList<>(games); }
    public synchronized LocalClassic find(String id) { for (LocalClassic game : games) if (game.id.equals(id)) return game; return null; }
    public boolean romFolderConfigured() { return !preferences.getString("rom_tree", "").isEmpty(); }
    public boolean runtimeFolderConfigured() { return !preferences.getString("runtime_tree", "").isEmpty(); }
    public String romFolderName() { return preferences.getString("rom_tree_name", "ROMs"); }
    public String runtimeFolderName() { return preferences.getString("runtime_tree_name", "Runtime Logs"); }
    public String raUsername() { return secrets.get("ra_username"); }
    public String raKey() { return secrets.get("ra_key"); }

    public void configureRetroAchievements(String username, String key) throws Exception {
        String cleanUser = username == null ? "" : username.trim(); String cleanKey = key == null ? "" : key.trim();
        if (cleanUser.isEmpty() || cleanKey.isEmpty()) throw new IllegalArgumentException("Preencha usuário e Web API Key.");
        secrets.put("ra_username", cleanUser); secrets.put("ra_key", cleanKey);
    }

    public synchronized List<LocalClassic> configureRomTree(Uri tree) throws Exception {
        persistTree(tree); preferences.edit().putString("rom_tree", tree.toString()).putString("rom_tree_name", treeName(tree, "ROMs")).commit();
        return scan();
    }

    public synchronized List<LocalClassic> scan() throws Exception {
        String rawTree = preferences.getString("rom_tree", "");
        if (rawTree.isEmpty()) throw new IllegalStateException("Selecione uma pasta de ROMs em Perfil → CLASSICS no Android.");
        Uri tree = Uri.parse(rawTree);
        Map<String, LocalClassic> previous = new HashMap<>(); for (LocalClassic game : games) previous.put(game.id, game);
        List<LocalClassic> found = scanTree(tree, previous);
        Map<String, Integer> filenameCounts = new HashMap<>();
        for (LocalClassic game : found) { String key = game.filename.toLowerCase(Locale.ROOT); filenameCounts.put(key, filenameCounts.containsKey(key) ? filenameCounts.get(key) + 1 : 1); }
        List<LocalClassic> unique = new ArrayList<>();
        for (LocalClassic game : found) if (filenameCounts.get(game.filename.toLowerCase(Locale.ROOT)) == 1) unique.add(game);
        Collections.sort(unique, Comparator.comparing(item -> item.title.toLowerCase(Locale.ROOT)));
        games.clear(); games.addAll(unique); save(); return all();
    }

    public synchronized int duplicateCount() throws Exception {
        String rawTree = preferences.getString("rom_tree", ""); if (rawTree.isEmpty()) return 0;
        List<LocalClassic> found = scanTree(Uri.parse(rawTree), new HashMap<>());
        Map<String, Integer> counts = new HashMap<>(); for (LocalClassic game : found) { String key = game.filename.toLowerCase(Locale.ROOT); counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1); }
        int duplicates = 0; for (LocalClassic game : found) if (counts.get(game.filename.toLowerCase(Locale.ROOT)) > 1) duplicates++;
        return duplicates;
    }

    public synchronized void configureRuntimeTree(Uri tree) throws Exception {
        persistTree(tree); preferences.edit().putString("runtime_tree", tree.toString()).putString("runtime_tree_name", treeName(tree, "Runtime Logs")).commit();
        for (LocalClassic game : games) game.counterReset = true;
        save();
    }

    public synchronized void updateLinks(String id, int raGameId, String launcherGameId) throws Exception {
        LocalClassic game = find(id); if (game == null) return;
        game.raGameId = Math.max(0, raGameId); game.launcherGameId = launcherGameId == null ? "" : launcherGameId;
        save();
    }

    public synchronized void updateProgress(String id, String username, String title, List<LocalClassic.Achievement> achievements) throws Exception {
        LocalClassic game = find(id); if (game == null) return;
        game.progressUsername = username; game.progressTitle = title; game.progressUpdatedAt = System.currentTimeMillis();
        game.achievements.clear(); game.achievements.addAll(achievements); save();
    }

    public synchronized void prepareLaunch(LocalClassic game) throws Exception {
        LocalClassic stored = find(game.id); if (stored == null) throw new IllegalStateException("Atualize a pasta de ROMs antes de jogar.");
        ensureUniqueLogName(stored);
        if (stored.streamId == null || stored.streamId.isEmpty()) stored.streamId = java.util.UUID.randomUUID().toString();
        if (runtimeFolderConfigured() && stored.lastObservedSeconds == 0 && stored.creditedSeconds == 0 && !stored.counterReset) {
            Long observed = observedRuntime(stored.filename); if (observed != null) stored.lastObservedSeconds = observed;
        }
        stored.lastPlayedAt = System.currentTimeMillis(); save();
        preferences.edit().putString("active_game", stored.id).putLong("active_launched", stored.lastPlayedAt).putLong("active_backgrounded", 0).commit();
    }

    public void markSessionBackgrounded() {
        if (preferences.getString("active_game", "").isEmpty() || preferences.getLong("active_backgrounded", 0) != 0) return;
        preferences.edit().putLong("active_backgrounded", System.currentTimeMillis()).commit();
    }

    public void cancelSession() {
        preferences.edit().remove("active_game").remove("active_launched").remove("active_backgrounded").commit();
    }

    public synchronized SessionResult finishReturnedSession() throws Exception {
        String id = preferences.getString("active_game", ""); long backgrounded = preferences.getLong("active_backgrounded", 0);
        if (id.isEmpty() || backgrounded == 0) return null;
        preferences.edit().remove("active_game").remove("active_launched").remove("active_backgrounded").commit();
        LocalClassic game = find(id); if (game == null) return null;
        long added = 0; String source;
        if (runtimeFolderConfigured()) {
            Long observed = observedRuntime(game.filename); source = "log do RetroArch";
            if (observed != null) {
                if (game.counterReset || observed < game.lastObservedSeconds) { game.counterReset = true; save(); throw new IllegalStateException("O contador diminuiu ou a pasta mudou. Reestabeleça o ponto de partida; as horas anteriores foram preservadas."); }
                added = observed - game.lastObservedSeconds; game.lastObservedSeconds = observed; game.creditedSeconds += added;
            }
        } else {
            long elapsed = Math.max(0L, (System.currentTimeMillis() - backgrounded) / 1000L); source = "cronômetro de contingência";
            if (elapsed > 0 && elapsed <= MAX_SESSION_SECONDS) { added = elapsed; game.creditedSeconds += elapsed; }
        }
        save(); return new SessionResult(game.id, added, source);
    }

    public synchronized void rebaseline(String id) throws Exception {
        LocalClassic game = find(id); if (game == null) return;
        Long observed = observedRuntime(game.filename); if (observed == null) throw new IllegalStateException("Feche o conteúdo no RetroArch para criar o log e tente novamente.");
        game.lastObservedSeconds = observed; game.counterReset = false; save();
    }

    public synchronized void bindForServer(LocalClassic game, String fingerprint) throws Exception {
        if (game.launcherGameId.isEmpty()) throw new IllegalStateException("Vincule o mesmo jogo do launcher antes de enviar horas.");
        if ((!game.serverFingerprint.isEmpty() && !game.serverFingerprint.equals(fingerprint))) throw new IllegalStateException("Estas horas estão vinculadas a outro computador.");
        game.serverFingerprint = fingerprint; save();
    }

    public synchronized void acknowledge(String id, long sentSeconds, long acceptedSeconds, String resolvedGameId) throws Exception {
        LocalClassic game = find(id); if (game == null) return;
        if (acceptedSeconds != sentSeconds) throw new IllegalStateException("O PC confirmou um contador diferente; as horas foram preservadas sem duplicação.");
        game.acknowledgedSeconds = Math.max(game.acknowledgedSeconds, sentSeconds);
        if (game.launcherGameId.isEmpty() && resolvedGameId != null) game.launcherGameId = resolvedGameId;
        save();
    }

    private List<LocalClassic> scanTree(Uri tree, Map<String, LocalClassic> previous) throws Exception {
        List<LocalClassic> result = new ArrayList<>(); Set<String> visited = new HashSet<>();
        String rootId = DocumentsContract.getTreeDocumentId(tree);
        ArrayDeque<Node> queue = new ArrayDeque<>(); queue.add(new Node(rootId, ""));
        String[] projection = {DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE};
        while (!queue.isEmpty() && result.size() < MAX_FILES) {
            Node parent = queue.removeFirst(); if (!visited.add(parent.documentId)) continue;
            Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent.documentId);
            try (Cursor cursor = resolver.query(children, projection, null, null, null)) {
                if (cursor == null) throw new IllegalStateException("A pasta de ROMs não pode ser lida.");
                while (cursor.moveToNext() && result.size() < MAX_FILES) {
                    String documentId = cursor.getString(0); String name = cursor.getString(1); String mime = cursor.getString(2);
                    long size = cursor.isNull(3) ? 0L : cursor.getLong(3); String relative = parent.relative.isEmpty() ? name : parent.relative + "/" + name;
                    if (DocumentsContract.Document.MIME_TYPE_DIR.equals(mime)) { queue.addLast(new Node(documentId, relative)); continue; }
                    if (name == null || !ClassicsRules.accepts(name) || size <= 0 || size > MAX_ROM_BYTES) continue;
                    Uri document = DocumentsContract.buildDocumentUriUsingTree(tree, documentId); String id = sha256(document.toString());
                    LocalClassic game = previous.get(id);
                    if (game == null) game = new LocalClassic(id, document.toString(), relative, name, ClassicsRules.cleanTitle(name), size);
                    else { game.uri = document.toString(); game.relativePath = relative; game.filename = name; game.title = ClassicsRules.cleanTitle(name); game.fileSize = size; }
                    result.add(game);
                }
            }
        }
        return result;
    }

    private Long observedRuntime(String filename) throws Exception {
        String raw = preferences.getString("runtime_tree", ""); if (raw.isEmpty()) return null;
        Uri tree = Uri.parse(raw); String rootId = DocumentsContract.getTreeDocumentId(tree); String wanted = ClassicsRules.runtimeLogName(filename);
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, rootId);
        String[] projection = {DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_SIZE};
        try (Cursor cursor = resolver.query(children, projection, null, null, null)) {
            if (cursor == null) throw new IllegalStateException("A pasta de logs não pode ser lida.");
            while (cursor.moveToNext()) {
                if (!wanted.equalsIgnoreCase(cursor.getString(1))) continue;
                long size = cursor.isNull(2) ? 0 : cursor.getLong(2); if (size <= 0 || size > 65_536) throw new IllegalStateException("Log inválido ou grande demais.");
                Uri file = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(0));
                try (InputStream input = resolver.openInputStream(file)) { return ClassicsRules.parseRuntimeSeconds(new String(readAll(input, 65_536), StandardCharsets.UTF_8)); }
            }
        }
        return null;
    }

    private void ensureUniqueLogName(LocalClassic selected) {
        String wanted = ClassicsRules.runtimeLogName(selected.filename);
        int matches = 0; for (LocalClassic game : games) if (wanted.equalsIgnoreCase(ClassicsRules.runtimeLogName(game.filename))) matches++;
        if (matches != 1) throw new IllegalStateException("Duas ROMs usam o mesmo nome de log. Renomeie os arquivos para distinguir as horas.");
    }

    private void persistTree(Uri tree) throws Exception {
        if (tree == null || !DocumentsContract.isTreeUri(tree)) throw new IllegalArgumentException("Selecione uma pasta, não um arquivo.");
        resolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION);
    }

    private String treeName(Uri tree, String fallback) {
        Uri root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
        try (Cursor cursor = resolver.query(root, new String[]{DocumentsContract.Document.COLUMN_DISPLAY_NAME}, null, null, null)) {
            return cursor != null && cursor.moveToFirst() ? cursor.getString(0) : fallback;
        } catch (Exception ignored) { return fallback; }
    }

    private synchronized void load() {
        games.clear(); if (!catalogFile.getBaseFile().isFile()) return;
        try (FileInputStream input = catalogFile.openRead()) {
            JSONArray rows = new JSONArray(new String(readAll(input, 8 * 1024 * 1024), StandardCharsets.UTF_8));
            for (int index = 0; index < rows.length(); index++) { JSONObject row = rows.optJSONObject(index); if (row != null) games.add(LocalClassic.fromJson(row)); }
        } catch (Exception ignored) { games.clear(); }
    }

    private synchronized void save() throws Exception {
        JSONArray rows = new JSONArray(); for (LocalClassic game : games) rows.put(game.toJson());
        FileOutputStream output = null;
        try { output = catalogFile.startWrite(); output.write(rows.toString().getBytes(StandardCharsets.UTF_8)); output.getFD().sync(); catalogFile.finishWrite(output); }
        catch (Exception error) { if (output != null) catalogFile.failWrite(output); throw error; }
    }

    private byte[] readAll(InputStream input, int maximum) throws Exception {
        if (input == null) throw new IllegalStateException("Arquivo indisponível.");
        ByteArrayOutputStream output = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int read; int total = 0;
        while ((read = input.read(buffer)) >= 0) { total += read; if (total > maximum) throw new IllegalStateException("Arquivo grande demais."); output.write(buffer, 0, read); }
        return output.toByteArray();
    }

    private String sha256(String value) throws Exception {
        byte[] bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder(); for (byte item : bytes) result.append(String.format(Locale.ROOT, "%02x", item)); return result.toString();
    }

    private static final class Node { final String documentId, relative; Node(String documentId, String relative) { this.documentId = documentId; this.relative = relative; } }
    public static final class SessionResult { public final String gameId, source; public final long addedSeconds; SessionResult(String gameId, long addedSeconds, String source) { this.gameId = gameId; this.addedSeconds = addedSeconds; this.source = source; } }
}

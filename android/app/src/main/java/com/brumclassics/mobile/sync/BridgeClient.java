package com.brumclassics.mobile.sync;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.LruCache;
import android.util.AtomicFile;

import com.brumclassics.mobile.model.Game;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

public final class BridgeClient {
    public interface Listener {
        void onStatus(String state, String detail);
        void onSnapshot(String rawJson);
        void onEvent(String type, JSONObject payload);
        void onError(String safeMessage);
    }

    public interface PairCallback {
        void onSuccess();
        void onError(String safeMessage);
    }

    public interface NotificationCallback {
        void onSuccess(int unread);
        void onError(String safeMessage);
    }

    public interface BitmapCallback { void onBitmap(Bitmap bitmap); }

    public interface CompanionCallback {
        void onResult(String state, String message);
    }

    public interface MomentCallback {
        void onCaptured(byte[] png, JSONObject metadata);
        void onError(String safeMessage);
    }

    public interface BCardCallback {
        void onResult(JSONObject result);
        void onError(String safeMessage);
    }

    public interface ClassicsCallback {
        void onResult(JSONObject result);
        void onError(String safeMessage);
    }

    public String serverFingerprint() { return preferences.getString("tls_pin", ""); }

    public void syncClassicAchievements(String gameId, int raGameId, String username, ClassicsCallback callback) {
        if (!isConfigured()) { callback.onError("Conecte este celular ao launcher primeiro."); return; }
        JSONObject body = new JSONObject();
        try { body.put("gameId", gameId); body.put("raGameId", raGameId); body.put("username", username); }
        catch (Exception error) { callback.onError("Dados de conquistas inválidos."); return; }
        postClassic("/v1/classics/achievements/sync", body, callback);
    }

    public void syncClassicTime(String gameId, String streamId, String filename, String title, long totalSeconds, long playedAt, ClassicsCallback callback) {
        if (!isConfigured()) { callback.onError("Conecte este celular ao launcher primeiro."); return; }
        JSONObject body = new JSONObject();
        try {
            body.put("gameId", gameId); body.put("streamId", streamId); body.put("filename", filename);
            body.put("title", title); body.put("totalSeconds", totalSeconds);
            if (playedAt > 0) body.put("playedAt", new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.ROOT).format(new java.util.Date(playedAt)));
        } catch (Exception error) { callback.onError("Dados de horas inválidos."); return; }
        postClassic("/v1/classics/playtime", body, callback);
    }

    private void postClassic(String path, JSONObject body, ClassicsCallback callback) {
        executor.execute(() -> {
            try {
                HttpURLConnection connection = open(baseUrl() + path, "POST", true); connection.setDoOutput(true);
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8); connection.setFixedLengthStreamingMode(bytes.length);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
                String raw = readResponse(connection, 256 * 1024); JSONObject root = raw.isEmpty() ? new JSONObject() : new JSONObject(raw);
                if (connection.getResponseCode() == 401) { clearPairing(); throw new IllegalStateException("A autorização foi revogada no launcher."); }
                if (connection.getResponseCode() != 200 || root.optBoolean("ok", true) == false) throw new IllegalStateException(root.optString("message", "O launcher recusou a sincronização."));
                JSONObject result = root.optJSONObject("result"); post(() -> callback.onResult(result == null ? root : result));
            } catch (Exception error) { post(() -> callback.onError(safeMessage(error))); }
        });
    }

    public void launchBCard(Game game, String mode, BCardCallback callback) {
        if (!isConfigured()) { callback.onError("Conecte este celular ao launcher primeiro."); return; }
        if (game == null || game.id.isEmpty() || !game.installed) { callback.onError("Este jogo não está confirmado como instalado."); return; }
        executor.execute(() -> {
            try {
                JSONObject payload = new JSONObject();
                payload.put("gameId", game.id);
                payload.put("mode", "continue-auto".equals(mode) || "continue-manual".equals(mode) ? mode : "new");
                JSONObject body = new JSONObject();
                body.put("command", "bcard_launch");
                body.put("requestId", UUID.randomUUID().toString());
                body.put("issuedAt", System.currentTimeMillis());
                body.put("payload", payload);
                HttpURLConnection connection = open(baseUrl() + "/v1/remote", "POST", true);
                connection.setDoOutput(true);
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(bytes.length);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
                String response = readResponse(connection, 256 * 1024);
                JSONObject root = response.isEmpty() ? new JSONObject() : new JSONObject(response);
                if (connection.getResponseCode() != 200 || !root.optBoolean("ok", false)) {
                    throw new IllegalStateException(root.optString("message", "O launcher recusou o B-CARD."));
                }
                JSONObject result = root.optJSONObject("result");
                if (result == null || !result.optBoolean("ok", false)) {
                    throw new IllegalStateException(result == null ? "O launcher não confirmou a abertura." : result.optString("message", "Não foi possível iniciar o jogo."));
                }
                post(() -> callback.onResult(result));
            } catch (Exception error) { post(() -> callback.onError(safeMessage(error))); }
        });
    }

    public void sendRemote(String command, JSONObject payload, PairCallback callback) {
        if (!isConfigured()) { callback.onError("Conecte este celular ao launcher primeiro."); return; }
        executor.execute(() -> {
            try {
                JSONObject body = new JSONObject();
                body.put("command", command);
                body.put("payload", payload == null ? new JSONObject() : payload);
                HttpURLConnection connection = open(baseUrl() + "/v1/remote", "POST", true);
                connection.setDoOutput(true);
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(bytes.length);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
                String response = readResponse(connection, 256 * 1024);
                if (connection.getResponseCode() != 200) throw new IllegalStateException("Comando remoto recusado pelo launcher.");
                if (!new JSONObject(response).optBoolean("ok", false)) throw new IllegalStateException("O launcher não confirmou o comando.");
                post(callback::onSuccess);
            } catch (Exception error) { post(() -> callback.onError(safeMessage(error))); }
        });
    }

    private final Context context;
    private final SharedPreferences preferences;
    private final ExecutorService executor = Executors.newFixedThreadPool(5);
    private final ExecutorService companionExecutor = Executors.newSingleThreadExecutor();
    private final ConcurrentHashMap<String, CopyOnWriteArrayList<BitmapCallback>> pendingArtwork = new ConcurrentHashMap<>();
    private final LruCache<String, Bitmap> memoryArtwork = new LruCache<String, Bitmap>(16 * 1024) {
        @Override protected int sizeOf(String key, Bitmap bitmap) { return Math.max(1, bitmap.getByteCount() / 1024); }
    };
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AtomicBoolean realtimeActive = new AtomicBoolean(false);
    private final AtomicBoolean snapshotFetchActive = new AtomicBoolean(false);
    private final AtomicBoolean snapshotFetchPending = new AtomicBoolean(false);
    private final AtomicInteger artworkSyncGeneration = new AtomicInteger(0);
    private final File snapshotFile;
    private final File artworkDirectory;
    private final File companionOutboxFile;
    private final File libraryStateOutboxFile;
    private volatile Listener listener;
    private volatile HttpURLConnection eventConnection;

    public BridgeClient(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        preferences = context.getSharedPreferences("brum_bridge", Context.MODE_PRIVATE);
        snapshotFile = new File(context.getFilesDir(), "launcher-library-cache.json");
        artworkDirectory = new File(context.getFilesDir(), "launcher-artwork");
        companionOutboxFile = new File(context.getFilesDir(), "companion-note-outbox.json");
        libraryStateOutboxFile = new File(context.getFilesDir(), "companion-library-outbox.json");
        if (!artworkDirectory.exists()) artworkDirectory.mkdirs();
        executor.execute(() -> migrateLegacyArtworkCache(new File(context.getCacheDir(), "launcher-artwork")));
    }

    public boolean isConfigured() {
        return !preferences.getString("host", "").isEmpty()
            && !preferences.getString("token", "").isEmpty()
            && !preferences.getString("tls_pin", "").isEmpty();
    }

    public String endpointLabel() {
        String host = preferences.getString("host", "");
        return host.isEmpty() ? "Nenhum launcher conectado" : host + ":" + preferences.getInt("port", 46991);
    }

    public String cachedSnapshot() {
        if (!snapshotFile.isFile()) return "";
        try (FileInputStream input = new FileInputStream(snapshotFile)) {
            return new String(readAll(input, 24 * 1024 * 1024), StandardCharsets.UTF_8);
        } catch (Exception ignored) { return ""; }
    }

    public JSONObject companionNotes(Game game) {
        JSONObject fallback = noteObject(game);
        if (game == null) return fallback;
        try {
            JSONObject entry = readCompanionOutbox().optJSONObject(game.id);
            JSONObject pending = entry == null ? null : entry.optJSONObject("notes");
            if (pending == null) return fallback;
            JSONObject result = new JSONObject(pending.toString());
            result.put("revision", entry.optInt("revision", game.notesRevision));
            result.put("pending", true);
            result.put("conflict", entry.optBoolean("conflict", false));
            return result;
        } catch (Exception ignored) { return fallback; }
    }

    public boolean hasCompanionNotes(Game game) {
        JSONObject notes = companionNotes(game);
        return !notes.optString("whereStopped", "").trim().isEmpty()
            || !notes.optString("objectives", "").trim().isEmpty()
            || !notes.optString("tips", "").trim().isEmpty()
            || !notes.optString("commands", "").trim().isEmpty();
    }

    public void saveCompanionNotes(Game game, JSONObject notes, boolean force, CompanionCallback callback) {
        if (game == null || game.id.isEmpty()) { callback.onResult("error", "Jogo inválido."); return; }
        companionExecutor.execute(() -> {
            try {
                JSONObject outbox = readCompanionOutbox();
                JSONObject previous = outbox.optJSONObject(game.id);
                JSONObject entry = new JSONObject();
                entry.put("gameId", game.id);
                entry.put("revision", previous == null ? game.notesRevision : previous.optInt("revision", game.notesRevision));
                entry.put("base", previous == null ? noteObject(game) : previous.optJSONObject("base"));
                entry.put("notes", sanitizeNoteObject(notes));
                entry.put("force", force);
                entry.put("conflict", false);
                entry.put("queuedAt", System.currentTimeMillis());
                outbox.put(game.id, entry);
                writeCompanionOutbox(outbox);
                if (!isConfigured()) { post(() -> callback.onResult("queued", "Salvo no celular; será sincronizado ao reencontrar o launcher.")); return; }
                CompanionResult result = sendCompanionEntry(entry);
                if ("saved".equals(result.state)) {
                    removeCompanionEntry(game.id);
                    fetchSnapshot();
                } else if ("conflict".equals(result.state)) markCompanionConflict(game.id, result.latest);
                post(() -> callback.onResult(result.state, result.message));
            } catch (Exception error) {
                post(() -> callback.onResult("queued", "Rascunho preservado no celular. " + safeMessage(error)));
            }
        });
    }

    public void discardCompanionDraft(String gameId) {
        companionExecutor.execute(() -> {
            try { removeCompanionEntry(gameId); fetchSnapshot(); } catch (Exception ignored) {}
        });
    }

    public int pendingCompanionNotes() {
        try { return readCompanionOutbox().length(); } catch (Exception ignored) { return 0; }
    }

    public boolean wantToPlay(Game game) {
        if (game == null) return false;
        try {
            JSONObject pending = readLibraryStateOutbox().optJSONObject(game.id);
            return pending == null ? game.wantToPlay : pending.optBoolean("wantToPlay", game.wantToPlay);
        } catch (Exception ignored) { return game.wantToPlay; }
    }

    public boolean favorite(Game game) {
        if (game == null) return false;
        try {
            JSONObject pending = readLibraryStateOutbox().optJSONObject(game.id);
            return pending == null ? game.favorite : pending.optBoolean("favorite", game.favorite);
        } catch (Exception ignored) { return game.favorite; }
    }

    public int pendingLibraryChanges() {
        try { return readLibraryStateOutbox().length(); } catch (Exception ignored) { return 0; }
    }

    public void discardLibraryState(String gameId) {
        companionExecutor.execute(() -> {
            try { JSONObject outbox = readLibraryStateOutbox(); outbox.remove(String.valueOf(gameId)); writeLibraryStateOutbox(outbox); fetchSnapshot(); }
            catch (Exception ignored) { }
        });
    }

    public void saveWantToPlay(Game game, boolean value, boolean force, CompanionCallback callback) {
        saveLibraryPreference(game, value, favorite(game), force, callback);
    }

    public void saveFavorite(Game game, boolean value, boolean force, CompanionCallback callback) {
        saveLibraryPreference(game, wantToPlay(game), value, force, callback);
    }

    private void saveLibraryPreference(Game game, boolean wantToPlay, boolean favorite, boolean force, CompanionCallback callback) {
        if (game == null || game.id.isEmpty()) { callback.onResult("error", "Jogo inválido."); return; }
        companionExecutor.execute(() -> {
            try {
                JSONObject outbox = readLibraryStateOutbox(); JSONObject previous = outbox.optJSONObject(game.id);
                JSONObject entry = new JSONObject(); entry.put("gameId", game.id); entry.put("wantToPlay", wantToPlay); entry.put("favorite", favorite);
                entry.put("revision", previous == null ? game.libraryStateRevision : previous.optInt("revision", game.libraryStateRevision));
                entry.put("force", force); entry.put("conflict", false); entry.put("queuedAt", System.currentTimeMillis());
                outbox.put(game.id, entry); writeLibraryStateOutbox(outbox);
                if (!isConfigured()) { post(() -> callback.onResult("queued", "Alteração salva no celular; será sincronizada na rede local.")); return; }
                CompanionResult result = sendLibraryStateEntry(entry);
                if ("saved".equals(result.state)) { outbox.remove(game.id); writeLibraryStateOutbox(outbox); fetchSnapshot(); }
                else if ("conflict".equals(result.state)) { entry.put("conflict", true); entry.put("latest", result.latest); writeLibraryStateOutbox(outbox); }
                post(() -> callback.onResult(result.state, result.message));
            } catch (Exception error) { post(() -> callback.onResult("queued", "Preferência preservada no celular. " + safeMessage(error))); }
        });
    }

    public void captureMoment(Game game, MomentCallback callback) {
        if (!isConfigured()) { callback.onError("A captura exige conexão local com o launcher."); return; }
        executor.execute(() -> {
            try {
                JSONObject request = new JSONObject(); request.put("gameId", game == null ? "" : game.id);
                HttpURLConnection create = open(baseUrl() + "/v1/companion/capture", "POST", true);
                create.setDoOutput(true); byte[] payload = request.toString().getBytes(StandardCharsets.UTF_8);
                create.setFixedLengthStreamingMode(payload.length); create.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = create.getOutputStream()) { output.write(payload); }
                String raw = readResponse(create, 128 * 1024); JSONObject metadata = raw.isEmpty() ? new JSONObject() : new JSONObject(raw);
                if (create.getResponseCode() != 201) throw new IllegalStateException(metadata.optString("message", "O launcher não conseguiu capturar a tela."));
                String imagePath = metadata.optString("imagePath", "");
                if (!imagePath.startsWith("/v1/moments/")) throw new IllegalStateException("Resposta de captura inválida.");
                HttpURLConnection image = open(baseUrl() + imagePath, "GET", true);
                if (image.getResponseCode() != 200 || !"image/png".equalsIgnoreCase(image.getContentType())) throw new IllegalStateException("Imagem da captura indisponível.");
                byte[] png = readAll(image.getInputStream(), 40 * 1024 * 1024);
                post(() -> callback.onCaptured(png, metadata));
            } catch (Exception error) { post(() -> callback.onError(safeMessage(error))); }
        });
    }

    public void pair(String inputHost, int port, String code, String fingerprint, PairCallback callback) {
        executor.execute(() -> {
            try {
                String host = normalizeHost(inputHost);
                String pin = PinnedTls.normalize(fingerprint);
                if (pin.isEmpty()) throw new IllegalArgumentException("Leia novamente o QR Code seguro exibido no launcher.");
                if (!code.matches("\\d{6}")) throw new IllegalArgumentException("Digite o código de seis números exibido no launcher.");
                JSONObject body = new JSONObject();
                body.put("code", code);
                body.put("deviceName", Build.MANUFACTURER + " " + Build.MODEL);
                HttpURLConnection connection = PinnedTls.open("https://" + host + ":" + port + "/v1/pair", pin);
                configure(connection, "POST", false);
                connection.setDoOutput(true);
                byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(payload.length);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = connection.getOutputStream()) { output.write(payload); }
                String response = readResponse(connection, 128 * 1024);
                if (connection.getResponseCode() != 201) throw new IllegalStateException(pairingError(response, connection.getResponseCode()));
                JSONObject result = new JSONObject(response);
                String token = result.optString("token", "");
                if (token.length() < 32) throw new IllegalStateException("O launcher retornou uma autorização inválida.");
                preferences.edit().putString("host", host).putInt("port", port).putString("token", token).putString("tls_pin", pin).apply();
                post(callback::onSuccess);
                fetchSnapshot();
                startRealtime();
            } catch (Exception error) {
                post(() -> callback.onError(safeMessage(error)));
            }
        });
    }

    public void fetchSnapshot() {
        if (!isConfigured()) return;
        if (!snapshotFetchActive.compareAndSet(false, true)) {
            snapshotFetchPending.set(true);
            return;
        }
        executor.execute(() -> {
            try {
                postStatus("syncing", "Sincronizando biblioteca...");
                HttpURLConnection connection = open(baseUrl() + "/v1/snapshot", "GET", true);
                String raw = readResponse(connection, 24 * 1024 * 1024);
                if (connection.getResponseCode() == 401) { clearPairing(); throw new IllegalStateException("A autorização foi revogada no launcher."); }
                if (connection.getResponseCode() != 200) throw new IllegalStateException("O launcher respondeu com erro " + connection.getResponseCode() + ".");
                new JSONObject(raw).getJSONArray("games");
                writeSnapshotAtomically(raw);
                post(() -> { if (listener != null) listener.onSnapshot(raw); });
                postStatus("connected", endpointLabel());
                flushCompanionNotes();
                flushLibraryState();
            } catch (Exception error) {
                postError(safeMessage(error));
                postStatus("offline", "Cache local disponível");
            } finally {
                snapshotFetchActive.set(false);
                if (snapshotFetchPending.getAndSet(false) && isConfigured()) fetchSnapshot();
            }
        });
    }

    public void markNotificationRead(String id, boolean all, NotificationCallback callback) {
        if (!isConfigured()) { callback.onError("Conecte este celular ao launcher primeiro."); return; }
        String safeId = id == null ? "" : id.trim();
        if (!all && (safeId.isEmpty() || safeId.length() > 100)) { callback.onError("Notificação inválida."); return; }
        executor.execute(() -> {
            try {
                String path = all ? "/v1/notifications/read-all" : "/v1/notifications/read";
                JSONObject body = new JSONObject();
                if (!all) body.put("id", safeId);
                HttpURLConnection connection = open(baseUrl() + path, "POST", true);
                connection.setDoOutput(true);
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(bytes.length);
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
                String raw = readResponse(connection, 128 * 1024);
                JSONObject result = raw.isEmpty() ? new JSONObject() : new JSONObject(raw);
                if (connection.getResponseCode() == 401) { clearPairing(); throw new IllegalStateException("A autorização foi revogada no launcher."); }
                if (connection.getResponseCode() != 200 || !result.optBoolean("ok", false)) throw new IllegalStateException(result.optString("message", "O launcher recusou a alteração."));
                int unread = Math.max(0, result.optInt("unread", 0));
                post(() -> callback.onSuccess(unread));
                fetchSnapshot();
            } catch (Exception error) { post(() -> callback.onError(safeMessage(error))); }
        });
    }

    private void flushCompanionNotes() {
        if (!isConfigured()) return;
        companionExecutor.execute(() -> {
            try {
                JSONObject outbox = readCompanionOutbox();
                java.util.Iterator<String> keys = outbox.keys();
                java.util.List<String> gameIds = new java.util.ArrayList<>();
                while (keys.hasNext()) gameIds.add(keys.next());
                boolean changed = false;
                for (String gameId : gameIds) {
                    JSONObject entry = outbox.optJSONObject(gameId);
                    if (entry == null || entry.optBoolean("conflict", false)) continue;
                    CompanionResult result = sendCompanionEntry(entry);
                    if ("saved".equals(result.state)) { outbox.remove(gameId); changed = true; }
                    else if ("conflict".equals(result.state)) { entry.put("conflict", true); entry.put("latest", result.latest); changed = true; }
                }
                if (changed) { writeCompanionOutbox(outbox); fetchSnapshot(); }
            } catch (Exception ignored) {}
        });
    }

    private void flushLibraryState() {
        if (!isConfigured()) return;
        companionExecutor.execute(() -> {
            try {
                JSONObject outbox = readLibraryStateOutbox(); java.util.Iterator<String> keys = outbox.keys();
                java.util.List<String> gameIds = new java.util.ArrayList<>(); while (keys.hasNext()) gameIds.add(keys.next());
                boolean changed = false;
                for (String gameId : gameIds) {
                    JSONObject entry = outbox.optJSONObject(gameId);
                    if (entry == null || entry.optBoolean("conflict", false)) continue;
                    CompanionResult result = sendLibraryStateEntry(entry);
                    if ("saved".equals(result.state)) { outbox.remove(gameId); changed = true; }
                    else if ("conflict".equals(result.state)) { entry.put("conflict", true); entry.put("latest", result.latest); changed = true; }
                }
                if (changed) { writeLibraryStateOutbox(outbox); fetchSnapshot(); }
            } catch (Exception ignored) { }
        });
    }

    private CompanionResult sendLibraryStateEntry(JSONObject entry) throws Exception {
        HttpURLConnection connection = open(baseUrl() + "/v1/companion/library-state", "POST", true);
        connection.setDoOutput(true); byte[] bytes = entry.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(bytes.length); connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
        String raw = readResponse(connection, 128 * 1024); JSONObject response = raw.isEmpty() ? new JSONObject() : new JSONObject(raw);
        if (connection.getResponseCode() == 200 && response.optBoolean("ok", false)) return new CompanionResult("saved", "Preferências sincronizadas com o launcher.", null);
        if (connection.getResponseCode() == 409) return new CompanionResult("conflict", response.optString("message", "As preferências mudaram nos dois dispositivos."), response.optJSONObject("latest"));
        if (connection.getResponseCode() == 401) { clearPairing(); throw new IllegalStateException("A autorização foi revogada no launcher."); }
        throw new IllegalStateException(response.optString("message", "O launcher recusou a alteração."));
    }

    private CompanionResult sendCompanionEntry(JSONObject entry) throws Exception {
        HttpURLConnection connection = open(baseUrl() + "/v1/companion/notes", "POST", true);
        connection.setDoOutput(true);
        byte[] bytes = entry.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(bytes.length);
        connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        try (OutputStream output = connection.getOutputStream()) { output.write(bytes); }
        String raw = readResponse(connection, 128 * 1024);
        JSONObject response = raw.isEmpty() ? new JSONObject() : new JSONObject(raw);
        if (connection.getResponseCode() == 200 && response.optBoolean("ok", false)) return new CompanionResult("saved", "Anotações sincronizadas com o launcher.", null);
        if (connection.getResponseCode() == 409) return new CompanionResult("conflict", response.optString("message", "As anotações foram alteradas nos dois dispositivos."), response.optJSONObject("latest"));
        if (connection.getResponseCode() == 401) { clearPairing(); throw new IllegalStateException("A autorização foi revogada no launcher."); }
        throw new IllegalStateException(response.optString("message", "O launcher recusou as anotações."));
    }

    private synchronized JSONObject readCompanionOutbox() throws Exception {
        if (!companionOutboxFile.isFile()) return new JSONObject();
        try (FileInputStream input = new FileInputStream(companionOutboxFile)) {
            return new JSONObject(new String(readAll(input, 256 * 1024), StandardCharsets.UTF_8));
        }
    }

    private synchronized void writeCompanionOutbox(JSONObject outbox) throws Exception {
        AtomicFile atomicFile = new AtomicFile(companionOutboxFile);
        FileOutputStream output = null;
        try {
            output = atomicFile.startWrite();
            output.write(outbox.toString().getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
            atomicFile.finishWrite(output);
        } catch (Exception error) {
            if (output != null) atomicFile.failWrite(output);
            throw error;
        }
    }

    private synchronized JSONObject readLibraryStateOutbox() throws Exception {
        if (!libraryStateOutboxFile.isFile()) return new JSONObject();
        try (FileInputStream input = new FileInputStream(libraryStateOutboxFile)) {
            return new JSONObject(new String(readAll(input, 256 * 1024), StandardCharsets.UTF_8));
        }
    }

    private synchronized void writeLibraryStateOutbox(JSONObject outbox) throws Exception {
        AtomicFile atomicFile = new AtomicFile(libraryStateOutboxFile); FileOutputStream output = null;
        try { output = atomicFile.startWrite(); output.write(outbox.toString().getBytes(StandardCharsets.UTF_8)); output.getFD().sync(); atomicFile.finishWrite(output); }
        catch (Exception error) { if (output != null) atomicFile.failWrite(output); throw error; }
    }

    private void removeCompanionEntry(String gameId) throws Exception {
        JSONObject outbox = readCompanionOutbox();
        outbox.remove(String.valueOf(gameId));
        writeCompanionOutbox(outbox);
    }

    private void markCompanionConflict(String gameId, JSONObject latest) throws Exception {
        JSONObject outbox = readCompanionOutbox();
        JSONObject entry = outbox.optJSONObject(gameId);
        if (entry != null) { entry.put("conflict", true); entry.put("latest", latest == null ? new JSONObject() : latest); }
        writeCompanionOutbox(outbox);
    }

    private JSONObject noteObject(Game game) {
        JSONObject notes = new JSONObject();
        if (game == null) return notes;
        try {
            notes.put("whereStopped", game.whereStopped); notes.put("objectives", game.objectives);
            notes.put("tips", game.tips); notes.put("commands", game.commands);
            notes.put("revision", game.notesRevision); notes.put("updatedAt", game.notesUpdatedAt);
        } catch (Exception ignored) {}
        return notes;
    }

    private JSONObject sanitizeNoteObject(JSONObject input) throws Exception {
        JSONObject result = new JSONObject();
        for (String field : new String[]{"whereStopped", "objectives", "tips", "commands"}) {
            String value = input == null ? "" : input.optString(field, "");
            if (value.length() > 6000) throw new IllegalArgumentException("Cada campo aceita até 6.000 caracteres.");
            result.put(field, value);
        }
        return result;
    }

    private static final class CompanionResult {
        final String state; final String message; final JSONObject latest;
        CompanionResult(String state, String message, JSONObject latest) { this.state = state; this.message = message; this.latest = latest; }
    }

    public void startRealtime() {
        if (!isConfigured() || !realtimeActive.compareAndSet(false, true)) return;
        executor.execute(() -> {
            long retry = 1500;
            while (realtimeActive.get() && isConfigured()) {
                try {
                    postStatus("connecting", "Conectando ao launcher...");
                    eventConnection = open(baseUrl() + "/v1/events", "GET", true);
                    eventConnection.setReadTimeout(35_000);
                    if (eventConnection.getResponseCode() != 200) throw new IllegalStateException("Canal em tempo real indisponível.");
                    postStatus("connected", endpointLabel());
                    retry = 1500;
                    try (BufferedReader reader = new BufferedReader(new InputStreamReader(eventConnection.getInputStream(), StandardCharsets.UTF_8))) {
                        String eventType = "message";
                        String data = "";
                        String line;
                        while (realtimeActive.get() && (line = reader.readLine()) != null) {
                            if (line.startsWith("event:")) eventType = line.substring(6).trim();
                            else if (line.startsWith("data:")) data += line.substring(5).trim();
                            else if (line.isEmpty() && !data.isEmpty()) {
                                dispatchEvent(eventType, data);
                                eventType = "message"; data = "";
                            }
                        }
                    }
                } catch (Exception error) {
                    if (realtimeActive.get()) postStatus("offline", "Reconectando automaticamente...");
                } finally {
                    if (eventConnection != null) eventConnection.disconnect();
                    eventConnection = null;
                }
                if (!realtimeActive.get()) break;
                try { Thread.sleep(retry); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); break; }
                retry = Math.min(30_000, retry * 2);
            }
        });
    }

    private void dispatchEvent(String eventType, String raw) {
        try {
            JSONObject payload = new JSONObject(raw);
            String type = payload.optString("type", eventType);
            post(() -> { if (listener != null) listener.onEvent(type, payload); });
            boolean libraryEvent = "library_changed".equals(type) || "achievement_unlocked".equals(type)
                || "collections_changed".equals(type) || "session_completed".equals(type) || "activity_changed".equals(type)
                || "notes_changed".equals(type) || "profile_changed".equals(type) || "companion_changed".equals(type)
                || "notifications_changed".equals(type);
            boolean terminalInstall = false;
            if ("install_changed".equals(type)) {
                JSONObject update = payload.optJSONObject("update");
                String state = update == null ? "" : update.optString("state", "");
                terminalInstall = "installed".equals(state) || "installation_error".equals(state)
                    || "canceled".equals(state) || "client_not_found".equals(state)
                    || "authentication_required".equals(state);
            }
            if (libraryEvent || terminalInstall) fetchSnapshot();
        } catch (Exception ignored) {}
    }

    public void loadArtwork(Game game, BitmapCallback callback) {
        if (game == null || game.artworkPath.isEmpty()) return;
        final String requestKey;
        try { requestKey = artworkKey(game); } catch (Exception ignored) { return; }
        Bitmap remembered = memoryArtwork.get(requestKey);
        if (remembered != null && !remembered.isRecycled()) { post(() -> callback.onBitmap(remembered)); return; }
        CopyOnWriteArrayList<BitmapCallback> callbacks = new CopyOnWriteArrayList<>();
        callbacks.add(callback);
        CopyOnWriteArrayList<BitmapCallback> existing = pendingArtwork.putIfAbsent(requestKey, callbacks);
        if (existing != null) { existing.add(callback); return; }
        executor.execute(() -> {
            Bitmap bitmap = null;
            try {
                File cache = new File(artworkDirectory, requestKey + ".img");
                if (cache.isFile()) bitmap = decodeArtwork(cache);
                if (bitmap == null) {
                    if (!isConfigured()) throw new IllegalStateException("Capa ainda não armazenada offline.");
                    downloadArtwork(game, cache);
                    bitmap = decodeArtwork(cache);
                    if (bitmap == null) throw new IllegalStateException("Imagem inválida.");
                }
                memoryArtwork.put(requestKey, bitmap);
            } catch (Exception ignored) {
            } finally {
                Bitmap finalBitmap = bitmap;
                CopyOnWriteArrayList<BitmapCallback> waiting = pendingArtwork.remove(requestKey);
                if (finalBitmap != null && waiting != null) post(() -> { for (BitmapCallback item : waiting) item.onBitmap(finalBitmap); });
            }
        });
    }

    public void warmArtwork(java.util.List<Game> games, int maximum, Runnable callback) {
        if (games == null || games.isEmpty() || maximum <= 0) { post(callback); return; }
        executor.execute(() -> {
            int warmed = 0;
            java.util.Set<String> visited = new java.util.HashSet<>();
            for (Game game : games) {
                if (warmed >= maximum) break;
                if (game == null || game.artworkPath.isEmpty()) continue;
                try {
                    String key = artworkKey(game);
                    if (!visited.add(key) || memoryArtwork.get(key) != null) continue;
                    File cache = new File(artworkDirectory, key + ".img");
                    if (!cache.isFile()) continue;
                    Bitmap bitmap = decodeArtwork(cache);
                    if (bitmap != null) { memoryArtwork.put(key, bitmap); warmed += 1; }
                } catch (Exception ignored) {}
            }
            post(callback);
        });
    }

    public void prefetchArtwork(java.util.List<Game> games) {
        if (!isConfigured() || games == null || games.isEmpty()) return;
        int generation = artworkSyncGeneration.incrementAndGet();
        java.util.List<Game> downloadable = new java.util.ArrayList<>();
        java.util.Set<String> retainedKeys = new java.util.HashSet<>();
        for (Game game : games) {
            if (game == null || game.artworkPath.isEmpty()) continue;
            try {
                String key = artworkKey(game);
                retainedKeys.add(key);
                if (!new File(artworkDirectory, key + ".img").isFile()) downloadable.add(game);
            } catch (Exception ignored) {}
        }
        if (downloadable.isEmpty()) {
            postStatus("connected", endpointLabel() + " · biblioteca offline completa");
            return;
        }
        postStatus("caching", "Salvando " + downloadable.size() + " capas para uso offline...");
        int total = downloadable.size();
        executor.execute(() -> {
            int failed = 0;
            int done = 0;
            for (Game game : downloadable) {
                if (generation != artworkSyncGeneration.get()) return;
                try {
                    String key = artworkKey(game);
                    File cache = new File(artworkDirectory, key + ".img");
                    if (!cache.isFile()) downloadArtwork(game, cache);
                } catch (Exception error) {
                    failed += 1;
                }
                done += 1;
                if (done % 20 == 0 && generation == artworkSyncGeneration.get()) {
                    postStatus("caching", "Capas offline " + done + "/" + total);
                }
            }
            if (generation != artworkSyncGeneration.get()) return;
            int pending = failed;
            postStatus("connected", pending == 0
                ? endpointLabel() + " · biblioteca offline completa"
                : endpointLabel() + " · " + pending + " capas pendentes");
        });
    }

    public String offlineSummary() {
        File[] files = artworkDirectory.listFiles((directory, name) -> name.endsWith(".img"));
        long bytes = snapshotFile.isFile() ? snapshotFile.length() : 0;
        int count = files == null ? 0 : files.length;
        if (files != null) for (File file : files) bytes += file.length();
        double megabytes = bytes / (1024d * 1024d);
        return String.format(Locale.ROOT, "Offline: %d capas · %.1f MB · jogos, conquistas e estatísticas salvos", count, megabytes);
    }

    public void disconnect(PairCallback callback) {
        executor.execute(() -> {
            try {
                if (isConfigured()) {
                    HttpURLConnection connection = open(baseUrl() + "/v1/unpair", "POST", true);
                    connection.setDoOutput(true);
                    connection.setFixedLengthStreamingMode(0);
                    connection.getResponseCode();
                }
            } catch (Exception ignored) {
            } finally {
                clearPairing();
                post(callback::onSuccess);
            }
        });
    }

    public void clearPairing() {
        realtimeActive.set(false);
        artworkSyncGeneration.incrementAndGet();
        if (eventConnection != null) eventConnection.disconnect();
        preferences.edit().clear().apply();
    }

    public void close() {
        realtimeActive.set(false);
        if (eventConnection != null) eventConnection.disconnect();
        executor.shutdownNow();
        companionExecutor.shutdownNow();
    }

    private HttpURLConnection open(String url, String method, boolean authenticated) throws Exception {
        HttpURLConnection connection = PinnedTls.open(url, preferences.getString("tls_pin", ""));
        configure(connection, method, authenticated);
        return connection;
    }

    private void configure(HttpURLConnection connection, String method, boolean authenticated) throws Exception {
        connection.setRequestMethod(method);
        connection.setConnectTimeout(6000);
        connection.setReadTimeout(12000);
        connection.setUseCaches(false);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("User-Agent", "BRUMCLASSICS-MOVEL/0.17.0 Android");
        if (authenticated) connection.setRequestProperty("Authorization", "Bearer " + preferences.getString("token", ""));
    }

    private String baseUrl() { return "https://" + preferences.getString("host", "") + ":" + preferences.getInt("port", 46991); }

    private String normalizeHost(String value) {
        String host = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
        host = host.replaceFirst("^https?://", "");
        int slash = host.indexOf('/'); if (slash >= 0) host = host.substring(0, slash);
        int colon = host.lastIndexOf(':'); if (colon > 0 && host.indexOf(':') == colon) host = host.substring(0, colon);
        if (!host.matches("[a-z0-9.-]{1,253}")) throw new IllegalArgumentException("Informe o endereço local exibido no launcher.");
        return host;
    }

    private String readResponse(HttpURLConnection connection, int maxBytes) throws Exception {
        InputStream stream = connection.getResponseCode() >= 400 ? connection.getErrorStream() : connection.getInputStream();
        return stream == null ? "" : new String(readAll(stream, maxBytes), StandardCharsets.UTF_8);
    }

    private byte[] readAll(InputStream input, int maxBytes) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192]; int read; int total = 0;
        while ((read = input.read(buffer)) >= 0) {
            total += read; if (total > maxBytes) throw new IllegalStateException("Resposta muito grande.");
            output.write(buffer, 0, read);
        }
        return output.toByteArray();
    }

    private String artworkKey(Game game) throws Exception {
        return sha256(game.id + "|" + game.artworkPath);
    }

    private void downloadArtwork(Game game, File cache) throws Exception {
        if (cache.isFile()) return;
        HttpURLConnection connection = open(baseUrl() + game.artworkPath, "GET", true);
        if (connection.getResponseCode() == 401) throw new IllegalStateException("A autorização foi revogada no launcher.");
        if (connection.getResponseCode() != 200) throw new IllegalStateException("Capa indisponível.");
        byte[] bytes = readAll(connection.getInputStream(), 20 * 1024 * 1024);
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw new IllegalStateException("Imagem inválida.");
        File temporary = new File(cache.getAbsolutePath() + ".tmp-" + Thread.currentThread().getId() + "-" + System.nanoTime());
        try (FileOutputStream output = new FileOutputStream(temporary)) { output.write(bytes); output.getFD().sync(); }
        if (cache.isFile()) { temporary.delete(); return; }
        if (!temporary.renameTo(cache)) { temporary.delete(); if (!cache.isFile()) throw new IllegalStateException("Não foi possível salvar a capa."); }
    }

    private void pruneArtwork(java.util.Set<String> retainedKeys) {
        File[] files = artworkDirectory.listFiles();
        if (files == null) return;
        for (File file : files) {
            String name = file.getName();
            if (!name.endsWith(".img")) continue;
            String key = name.substring(0, name.length() - 4);
            if (!retainedKeys.contains(key)) file.delete();
        }
    }

    private void migrateLegacyArtworkCache(File legacyDirectory) {
        if (legacyDirectory == null || !legacyDirectory.isDirectory() || legacyDirectory.equals(artworkDirectory)) return;
        File[] files = legacyDirectory.listFiles((directory, name) -> name.endsWith(".img"));
        if (files == null) return;
        for (File source : files) {
            File destination = new File(artworkDirectory, source.getName());
            if (destination.isFile()) continue;
            try (FileInputStream input = new FileInputStream(source); FileOutputStream output = new FileOutputStream(destination)) {
                byte[] buffer = new byte[8192]; int read;
                while ((read = input.read(buffer)) >= 0) output.write(buffer, 0, read);
                output.getFD().sync();
            } catch (Exception ignored) { destination.delete(); }
        }
    }

    private Bitmap decodeArtwork(File file) {
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = artworkSampleSize(bounds.outWidth, bounds.outHeight);
        options.inPreferredConfig = Bitmap.Config.RGB_565;
        return BitmapFactory.decodeFile(file.getAbsolutePath(), options);
    }

    private Bitmap decodeArtwork(byte[] bytes) {
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeByteArray(bytes, 0, bytes.length, bounds);
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = artworkSampleSize(bounds.outWidth, bounds.outHeight);
        options.inPreferredConfig = Bitmap.Config.RGB_565;
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.length, options);
    }

    private int artworkSampleSize(int width, int height) {
        int sample = 1;
        while (width / sample > 640 || height / sample > 960) sample *= 2;
        return sample;
    }

    private void writeSnapshotAtomically(String raw) throws Exception {
        AtomicFile atomicFile = new AtomicFile(snapshotFile);
        FileOutputStream output = null;
        try {
            output = atomicFile.startWrite();
            output.write(raw.getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
            atomicFile.finishWrite(output);
        } catch (Exception error) {
            if (output != null) atomicFile.failWrite(output);
            throw error;
        }
    }

    private String pairingError(String raw, int code) {
        try {
            String error = new JSONObject(raw).optString("error", "");
            if ("PAIRING_CODE_INVALID".equals(error)) return "Código incorreto. Gere um novo código no launcher.";
            if ("PAIRING_EXPIRED".equals(error)) return "O código expirou. Gere outro no launcher.";
            if ("PAIRING_RATE_LIMIT".equals(error)) return "Muitas tentativas. Aguarde alguns minutos.";
        } catch (Exception ignored) {}
        return "Não foi possível parear com o launcher (" + code + ").";
    }

    private String safeMessage(Exception error) {
        if (error instanceof java.net.SocketTimeoutException) return "O computador não respondeu. No launcher, abra Configurações → MOVEL e use REPARAR CONEXÃO.";
        if (error instanceof java.net.ConnectException || error instanceof java.net.NoRouteToHostException) return "Launcher não alcançável. Gere um novo QR Code e confirme REPARAR CONEXÃO no computador.";
        String message = error.getMessage();
        if (message == null || message.isEmpty()) return "Não foi possível comunicar com o launcher.";
        if (message.contains("failed to connect") || message.contains("Connection refused") || message.contains("timed out")) return "Launcher não encontrado. Confirme o Wi-Fi e o endereço.";
        return message.length() > 180 ? message.substring(0, 180) : message;
    }

    private String sha256(String value) throws Exception {
        byte[] bytes = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        StringBuilder result = new StringBuilder(); for (byte item : bytes) result.append(String.format(Locale.ROOT, "%02x", item)); return result.toString();
    }

    private void postStatus(String state, String detail) { post(() -> { if (listener != null) listener.onStatus(state, detail); }); }
    private void postError(String message) { post(() -> { if (listener != null) listener.onError(message); }); }
    private void post(Runnable runnable) { main.post(runnable); }
}

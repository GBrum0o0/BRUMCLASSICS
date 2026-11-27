package com.brumclassics.mobile.classics;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.StatFs;
import android.util.AtomicFile;

import com.brumclassics.mobile.classics.ClassicDriveCloudRules.CloudGameEntry;
import com.brumclassics.mobile.classics.ClassicDriveCloudRules.FetchResult;
import com.brumclassics.mobile.classics.ClassicDriveCloudRules.FolderTask;
import com.brumclassics.mobile.classics.ClassicDriveCloudRules.ScanCheckpoint;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicBoolean;

public final class ClassicDriveCloudService {
    public interface DownloadProgressListener {
        void onProgress(String fileId, long downloadedBytes, long totalBytes, String status);
    }

    private final Context context;
    private final SharedPreferences prefs;
    private final AtomicFile checkpointFile;
    private final SecureSecretStore secrets;
    private final ClassicsRepository repository;
    private final ExecutorService downloadExecutor = Executors.newFixedThreadPool(2);
    private final Map<String, Future<File>> activeDownloads = new ConcurrentHashMap<>();
    private final Map<String, AtomicBoolean> cancelFlags = new ConcurrentHashMap<>();
    private ScanCheckpoint checkpoint;

    public ClassicDriveCloudService(Context context, ClassicsRepository repository) {
        this.context = context.getApplicationContext();
        this.repository = repository;
        this.prefs = this.context.getSharedPreferences("brum_drive_cloud_v1", Context.MODE_PRIVATE);
        this.checkpointFile = new AtomicFile(new File(this.context.getFilesDir(), "classics-drive-checkpoint.json"));
        this.secrets = new SecureSecretStore(this.context);
        this.checkpoint = loadCheckpoint();
    }

    public synchronized ScanCheckpoint getCheckpoint() {
        return checkpoint;
    }

    public void setBearerToken(String token) throws Exception {
        secrets.put("google_drive_token", token == null ? "" : token.trim());
    }

    public String getBearerToken() {
        return secrets.get("google_drive_token");
    }

    public boolean hasBearerToken() {
        String t = getBearerToken();
        return t != null && !t.isEmpty();
    }

    public File getStorageDirectory() {
        String custom = prefs.getString("storage_dir", "");
        if (!custom.isEmpty()) {
            File dir = new File(custom);
            if (dir.isDirectory() || dir.mkdirs()) return dir;
        }
        File fallback = new File(context.getFilesDir(), "drive-roms");
        if (!fallback.isDirectory()) fallback.mkdirs();
        return fallback;
    }

    public void setStorageDirectory(File dir) {
        if (dir == null || (!dir.isDirectory() && !dir.mkdirs())) {
            throw new IllegalArgumentException("Pasta de armazenamento inválida para downloads.");
        }
        prefs.edit().putString("storage_dir", dir.getAbsolutePath()).apply();
    }

    public long getAvailableFreeSpaceBytes() {
        File dir = getStorageDirectory();
        try {
            StatFs statFs = new StatFs(dir.getAbsolutePath());
            return statFs.getAvailableBytes();
        } catch (Throwable ignored) {
            return dir.getUsableSpace();
        }
    }

    public synchronized ScanCheckpoint startOrRefreshScan(String folderUrl) throws Exception {
        ScanCheckpoint next = ClassicDriveCloudRules.runScanBatch(checkpoint, new AndroidHttpFetcher(), getBearerToken(), true, folderUrl);
        saveCheckpoint(next);
        return next;
    }

    public synchronized ScanCheckpoint continueScan() throws Exception {
        ScanCheckpoint next = ClassicDriveCloudRules.runScanBatch(checkpoint, new AndroidHttpFetcher(), getBearerToken(), false, "");
        saveCheckpoint(next);
        return next;
    }

    public File downloadGameSync(String fileId, DownloadProgressListener listener) throws Exception {
        Future<File> existing = activeDownloads.get(fileId);
        if (existing != null) return existing.get();

        CloudGameEntry target;
        synchronized (this) {
            target = checkpoint.itemsById.get(fileId);
        }
        if (target == null) throw new IllegalArgumentException("Jogo não encontrado na pasta configurada.");
        if (ClassicDriveCloudRules.isAvailabilityPlayableLocally(target.downloadedLocalPath)) {
            return new File(target.downloadedLocalPath);
        }
        if (!ClassicDriveCloudRules.isAllowedUrl(target.downloadUrl)) {
            throw new SecurityException("URL de download do Drive inválida.");
        }
        long freeBytes = getAvailableFreeSpaceBytes();
        if (target.sizeBytes > 0 && freeBytes > 0 && freeBytes < target.sizeBytes) {
            throw new IllegalStateException("Espaço insuficiente no dispositivo para baixar este jogo.");
        }

        AtomicBoolean cancelled = new AtomicBoolean(false);
        cancelFlags.put(fileId, cancelled);
        synchronized (this) {
            target.downloadStatus = "downloading";
            target.downloadError = "";
            saveCheckpointQuietly();
        }

        Future<File> future = downloadExecutor.submit(() -> executeDownload(target, cancelled, listener));
        activeDownloads.put(fileId, future);
        try {
            return future.get();
        } finally {
            activeDownloads.remove(fileId);
            cancelFlags.remove(fileId);
        }
    }

    public void cancelDownload(String fileId) {
        AtomicBoolean flag = cancelFlags.get(fileId);
        if (flag != null) flag.set(true);
        Future<File> f = activeDownloads.remove(fileId);
        if (f != null) f.cancel(true);
        synchronized (this) {
            CloudGameEntry entry = checkpoint.itemsById.get(fileId);
            if (entry != null) {
                entry.downloadStatus = ClassicDriveCloudRules.isAvailabilityPlayableLocally(entry.downloadedLocalPath) ? "available" : "cloud";
                saveCheckpointQuietly();
            }
        }
    }

    private File executeDownload(CloudGameEntry target, AtomicBoolean cancelled, DownloadProgressListener listener) throws Exception {
        File dir = getStorageDirectory();
        String safeName = new File(target.name).getName();
        File finalFile = new File(dir, target.id + "_" + safeName);
        File tempFile = new File(dir, target.id + "_" + safeName + ".part");
        try {
            long received = executeDownloadAttempt(target, target.downloadUrl, tempFile, cancelled, listener, true);
            if (finalFile.exists() && !finalFile.delete()) {
                throw new IOException("Não foi possível atualizar o arquivo local.");
            }
            if (!tempFile.renameTo(finalFile)) {
                throw new IOException("Não foi possível finalizar o arquivo baixado.");
            }

            if (repository != null) {
                repository.registerDownloadedClassic(finalFile, target.relativePath, target.systemHint, target.id);
            }
            synchronized (this) {
                target.downloadedLocalPath = finalFile.getAbsolutePath();
                target.downloadedBytes = received;
                target.downloadStatus = "available";
                target.downloadError = "";
                saveCheckpointQuietly();
            }
            if (listener != null) listener.onProgress(target.id, received, received, "available");
            return finalFile;
        } catch (Exception err) {
            tempFile.delete();
            synchronized (this) {
                target.downloadStatus = "cloud";
                target.downloadError = err.getMessage() == null ? "Falha no download" : err.getMessage();
                saveCheckpointQuietly();
            }
            throw err;
        }
    }

    private long executeDownloadAttempt(CloudGameEntry target, String requestUrl, File tempFile,
                                        AtomicBoolean cancelled, DownloadProgressListener listener,
                                        boolean allowConfirmRetry) throws Exception {
        if (!ClassicDriveCloudRules.isAllowedUrl(requestUrl)) {
            throw new SecurityException("Origem de download não permitida.");
        }
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection) new URL(requestUrl).openConnection();
            conn.setConnectTimeout(20000);
            conn.setReadTimeout(60000);
            conn.setRequestProperty("User-Agent", "BRUMCLASSICS");
            String token = getBearerToken();
            if (token != null && !token.isEmpty()) conn.setRequestProperty("Authorization", "Bearer " + token);

            int code = conn.getResponseCode();
            if (code < 200 || code >= 300) {
                throw new IOException("Download recusado (HTTP " + code + ")");
            }
            String contentType = conn.getContentType();
            boolean mimeIsHtml = contentType != null && contentType.toLowerCase(Locale.ROOT).contains("text/html");
            long total = conn.getContentLengthLong();

            if (mimeIsHtml) {
                String html = readSmallHtml(conn.getInputStream());
                if (allowConfirmRetry) {
                    String confirmed = extractConfirmDownloadUrl(html, requestUrl);
                    if (confirmed != null) {
                        return executeDownloadAttempt(target, confirmed, tempFile, cancelled, listener, false);
                    }
                }
                throw new IllegalStateException("O Google Drive não liberou o arquivo. Confira o compartilhamento ou a cota.");
            }

            long freeBytes = getAvailableFreeSpaceBytes();
            if (total > 0 && freeBytes > 0 && freeBytes < total) {
                throw new IllegalStateException("Espaço livre insuficiente no armazenamento escolhido.");
            }

            byte[] buf = new byte[64 * 1024];
            long received = 0L;
            boolean checkedHeader = false;
            try (InputStream in = conn.getInputStream(); FileOutputStream out = new FileOutputStream(tempFile)) {
                int read;
                while ((read = in.read(buf)) >= 0) {
                    if (cancelled.get() || Thread.currentThread().isInterrupted()) {
                        throw new InterruptedException("Download cancelado pelo usuário.");
                    }
                    if (read == 0) continue;
                    if (!checkedHeader) {
                        checkedHeader = true;
                        if (ClassicDriveCloudRules.looksLikeHtmlPayload(buf, read)) {
                            throw new IllegalStateException("O arquivo recebido parece ser uma página HTML de erro/permissão.");
                        }
                    }
                    out.write(buf, 0, read);
                    received += read;
                    if (listener != null) listener.onProgress(target.id, received, total, "downloading");
                }
                out.getFD().sync();
            }
            if (received <= 0 || (total > 0 && received < total)) {
                throw new IOException("Download incompleto (" + received + "/" + total + " bytes).");
            }
            return received;
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static String readSmallHtml(InputStream in) throws IOException {
        if (in == null) return "";
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        int total = 0;
        while ((n = in.read(buf)) >= 0 && total < 512 * 1024) {
            total += n;
            out.write(buf, 0, n);
        }
        return out.toString(StandardCharsets.UTF_8.name());
    }

    private static String extractConfirmDownloadUrl(String html, String baseUrl) {
        if (html == null || html.isEmpty()) return null;
        java.util.regex.Matcher form = java.util.regex.Pattern.compile(
            "<form[^>]*action=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</form>",
            java.util.regex.Pattern.CASE_INSENSITIVE | java.util.regex.Pattern.DOTALL
        ).matcher(html);
        if (!form.find()) return null;
        String action = ClassicDriveCloudRules.unescapeHtml(form.group(1));
        String body = form.group(2);
        StringBuilder url = new StringBuilder(action.startsWith("https://") ? action : baseUrl);
        java.util.regex.Matcher inputs = java.util.regex.Pattern.compile(
            "<input[^>]*name=[\"']([^\"']+)[\"'][^>]*value=[\"']([^\"']*)[\"']",
            java.util.regex.Pattern.CASE_INSENSITIVE
        ).matcher(body);
        char sep = url.indexOf("?") >= 0 ? '&' : '?';
        while (inputs.find()) {
            try {
                url.append(sep)
                   .append(java.net.URLEncoder.encode(inputs.group(1), "UTF-8"))
                   .append('=')
                   .append(java.net.URLEncoder.encode(ClassicDriveCloudRules.unescapeHtml(inputs.group(2)), "UTF-8"));
                sep = '&';
            } catch (Exception ignored) {}
        }
        String candidate = url.toString();
        return ClassicDriveCloudRules.isAllowedUrl(candidate) ? candidate : null;
    }

    public static JSONObject serializeCheckpoint(ScanCheckpoint state) throws Exception {
        JSONObject root = new JSONObject();
        root.put("rootUrl", state.rootUrl);
        root.put("rootFolderId", state.rootFolderId);
        root.put("completed", state.completed);
        root.put("totalFoldersRead", state.totalFoldersRead);
        root.put("lastError", state.lastError);
        root.put("updatedAtMs", state.updatedAtMs);

        JSONArray pending = new JSONArray();
        for (FolderTask t : state.pendingFolders) {
            JSONObject obj = new JSONObject();
            obj.put("id", t.id);
            obj.put("relativePath", t.relativePath);
            obj.put("depth", t.depth);
            obj.put("resourceKey", t.resourceKey);
            pending.put(obj);
        }
        root.put("pendingFolders", pending);

        JSONArray visited = new JSONArray();
        for (String id : state.visitedFolderIds) visited.put(id);
        root.put("visitedFolderIds", visited);

        JSONArray seen = new JSONArray();
        for (String id : state.seenFileIds) seen.put(id);
        root.put("seenFileIds", seen);

        JSONArray items = new JSONArray();
        for (CloudGameEntry e : state.itemsById.values()) {
            JSONObject obj = new JSONObject();
            obj.put("id", e.id);
            obj.put("name", e.name);
            obj.put("title", e.title);
            obj.put("relativePath", e.relativePath);
            obj.put("folderId", e.folderId);
            obj.put("parentRelativePath", e.parentRelativePath);
            obj.put("sizeBytes", e.sizeBytes);
            obj.put("systemHint", e.systemHint);
            obj.put("downloadUrl", e.downloadUrl);
            obj.put("downloadedLocalPath", e.downloadedLocalPath);
            obj.put("downloadedBytes", e.downloadedBytes);
            obj.put("downloadStatus", e.downloadStatus);
            obj.put("downloadError", e.downloadError);
            items.put(obj);
        }
        root.put("items", items);
        return root;
    }

    public static ScanCheckpoint deserializeCheckpoint(JSONObject root) {
        ScanCheckpoint state = new ScanCheckpoint();
        if (root == null) return state;
        state.rootUrl = root.optString("rootUrl", "");
        state.rootFolderId = root.optString("rootFolderId", "");
        state.completed = root.optBoolean("completed", false);
        state.totalFoldersRead = root.optInt("totalFoldersRead", 0);
        state.lastError = root.optString("lastError", "");
        state.updatedAtMs = root.optLong("updatedAtMs", 0L);

        JSONArray pending = root.optJSONArray("pendingFolders");
        if (pending != null) {
            for (int i = 0; i < pending.length(); i++) {
                JSONObject obj = pending.optJSONObject(i);
                if (obj != null && !obj.optString("id").isEmpty()) {
                    state.pendingFolders.add(new FolderTask(
                        obj.optString("id"),
                        obj.optString("relativePath"),
                        obj.optInt("depth", 0),
                        obj.optString("resourceKey", "")
                    ));
                }
            }
        }
        JSONArray visited = root.optJSONArray("visitedFolderIds");
        if (visited != null) {
            for (int i = 0; i < visited.length(); i++) {
                String id = visited.optString(i);
                if (!id.isEmpty()) state.visitedFolderIds.add(id);
            }
        }
        JSONArray seen = root.optJSONArray("seenFileIds");
        if (seen != null) {
            for (int i = 0; i < seen.length(); i++) {
                String id = seen.optString(i);
                if (!id.isEmpty()) state.seenFileIds.add(id);
            }
        }
        JSONArray items = root.optJSONArray("items");
        if (items != null) {
            for (int i = 0; i < items.length(); i++) {
                JSONObject obj = items.optJSONObject(i);
                if (obj == null || obj.optString("id").isEmpty()) continue;
                CloudGameEntry entry = new CloudGameEntry(
                    obj.optString("id"),
                    obj.optString("name"),
                    obj.optString("title"),
                    obj.optString("relativePath"),
                    obj.optString("folderId"),
                    obj.optString("parentRelativePath"),
                    obj.optLong("sizeBytes", -1L),
                    obj.optString("systemHint"),
                    obj.optString("downloadUrl")
                );
                entry.downloadedLocalPath = obj.optString("downloadedLocalPath", "");
                entry.downloadedBytes = obj.optLong("downloadedBytes", 0L);
                entry.downloadStatus = obj.optString("downloadStatus", ClassicDriveCloudRules.isAvailabilityPlayableLocally(entry.downloadedLocalPath) ? "available" : "cloud");
                entry.downloadError = obj.optString("downloadError", "");
                state.itemsById.put(entry.id, entry);
            }
        }
        return state;
    }

    private ScanCheckpoint loadCheckpoint() {
        if (!checkpointFile.getBaseFile().isFile()) return new ScanCheckpoint();
        try (InputStream in = checkpointFile.openRead()) {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) >= 0) baos.write(buf, 0, n);
            return deserializeCheckpoint(new JSONObject(baos.toString(StandardCharsets.UTF_8.name())));
        } catch (Exception ignored) {
            return new ScanCheckpoint();
        }
    }

    private synchronized void saveCheckpoint(ScanCheckpoint state) throws Exception {
        this.checkpoint = state;
        byte[] bytes = serializeCheckpoint(state).toString().getBytes(StandardCharsets.UTF_8);
        FileOutputStream out = null;
        try {
            out = checkpointFile.startWrite();
            out.write(bytes);
            out.getFD().sync();
            checkpointFile.finishWrite(out);
        } catch (Exception err) {
            if (out != null) checkpointFile.failWrite(out);
            throw err;
        }
    }

    private void saveCheckpointQuietly() {
        try { saveCheckpoint(checkpoint); } catch (Exception ignored) {}
    }

    private static final class AndroidHttpFetcher implements ClassicDriveCloudRules.HttpFetcher {
        @Override
        public FetchResult fetch(String folderId, String bearerToken) throws Exception {
            return fetch(folderId, "", bearerToken);
        }

        @Override
        public FetchResult fetch(String folderId, String resourceKey, String bearerToken) throws Exception {
            StringBuilder urlBuilder = new StringBuilder("https://drive.google.com/embeddedfolderview?id=")
                .append(java.net.URLEncoder.encode(folderId, StandardCharsets.UTF_8.name()));
            if (resourceKey != null && !resourceKey.isEmpty()) {
                urlBuilder.append("&resourcekey=").append(java.net.URLEncoder.encode(resourceKey, StandardCharsets.UTF_8.name()));
            }
            urlBuilder.append("#list");
            String url = urlBuilder.toString();
            if (!ClassicDriveCloudRules.isAllowedUrl(url)) throw new SecurityException("Host não permitido.");
            HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(20000);
            conn.setInstanceFollowRedirects(true);
            conn.setRequestProperty("User-Agent", "BRUMCLASSICS");
            conn.setRequestProperty("Accept", "text/html,application/xhtml+xml");
            if (bearerToken != null && !bearerToken.isEmpty()) conn.setRequestProperty("Authorization", "Bearer " + bearerToken);
            try {
                int code = conn.getResponseCode();
                InputStream stream = (code >= 200 && code < 400) ? conn.getInputStream() : conn.getErrorStream();
                if (stream == null) return new FetchResult(code, "");
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[16384];
                int n;
                int total = 0;
                while ((n = stream.read(buf)) >= 0) {
                    total += n;
                    if (total > ClassicDriveCloudRules.MAX_RESPONSE_BYTES) throw new IllegalStateException("Resposta do Drive excedeu 8 MB.");
                    out.write(buf, 0, n);
                }
                return new FetchResult(code, out.toString(StandardCharsets.UTF_8.name()));
            } finally {
                conn.disconnect();
            }
        }
    }
}

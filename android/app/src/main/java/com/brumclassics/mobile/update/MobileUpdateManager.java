package com.brumclassics.mobile.update;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import org.json.JSONArray;
import org.json.JSONObject;
import com.brumclassics.mobile.sync.PinnedTls;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MobileUpdateManager {
    public static final String CURRENT_VERSION = "0.17.0";
    public static final String DISPLAY_VERSION = "0.17.0";
    private static final String RELEASES = "https://api.github.com/repos/GBrum0o0/BRUMCLASSICS/releases?per_page=20";
    private static final long CHECK_INTERVAL_MS = 6L * 60L * 60L * 1000L;
    private static final long MAX_APK_BYTES = 250L * 1024L * 1024L;

    public interface Listener {
        void onStatus(String state, String detail, int percent);
        void onAvailable(UpdateInfo update);
        void onCurrent();
        void onError(String safeMessage);
    }

    public static final class UpdateInfo {
        public final String version, notes, url, sha256, source;
        public final long size;
        public final boolean authenticated;
        UpdateInfo(String version, String notes, String url, String sha256, long size, String source, boolean authenticated) {
            this.version = version; this.notes = notes; this.url = url; this.sha256 = sha256;
            this.size = size; this.source = source; this.authenticated = authenticated;
        }
    }

    private final Context context;
    private final Listener listener;
    private final SharedPreferences updatePreferences;
    private final SharedPreferences bridgePreferences;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final AtomicBoolean active = new AtomicBoolean(false);
    private volatile UpdateInfo available;
    private volatile boolean installPending;

    public MobileUpdateManager(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        this.updatePreferences = context.getSharedPreferences("brum_mobile_updates", Context.MODE_PRIVATE);
        this.bridgePreferences = context.getSharedPreferences("brum_bridge", Context.MODE_PRIVATE);
    }

    public UpdateInfo availableUpdate() { return available; }

    public void check(boolean force) {
        if (!force && System.currentTimeMillis() - updatePreferences.getLong("checked_at", 0) < CHECK_INTERVAL_MS) return;
        if (!active.compareAndSet(false, true)) return;
        status("checking", "Procurando uma atualização oficial...", 0);
        executor.execute(() -> {
            Exception githubError = null;
            try {
                try {
                    UpdateInfo update = checkGitHub();
                    updatePreferences.edit().putLong("checked_at", System.currentTimeMillis()).apply();
                    if (update != null) { available = update; listener.onAvailable(update); return; }
                    available = null; listener.onCurrent(); return;
                } catch (Exception error) { githubError = error; }
                try {
                    UpdateInfo update = checkLauncher();
                    updatePreferences.edit().putLong("checked_at", System.currentTimeMillis()).apply();
                    if (update != null) { available = update; listener.onAvailable(update); return; }
                    available = null; listener.onCurrent();
                } catch (Exception localError) {
                    String detail = githubError == null ? safeMessage(localError) : "GitHub e launcher local estão temporariamente indisponíveis.";
                    listener.onError(detail);
                }
            } finally { active.set(false); }
        });
    }

    public void downloadAndInstall() {
        final UpdateInfo update = available;
        if (update == null || !active.compareAndSet(false, true)) return;
        executor.execute(() -> {
            try {
                File target = download(update);
                verifyApk(target, update);
                installPending = true;
                status("ready", "Download verificado. Confirme a instalação no Android.", 100);
                requestInstallPermissionOrInstall();
            } catch (Exception error) { listener.onError(safeMessage(error)); }
            finally { active.set(false); }
        });
    }

    public void resumeInstallIfReady() {
        if (!installPending || !UpdateFileProvider.updateFile(context).isFile()) return;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.getPackageManager().canRequestPackageInstalls()) {
            installPending = false;
            launchInstaller();
        }
    }

    public void close() { executor.shutdownNow(); }

    private UpdateInfo checkGitHub() throws Exception {
        HttpURLConnection connection = open(RELEASES, "GET", false);
        String raw = readText(connection, 4 * 1024 * 1024);
        if (connection.getResponseCode() != 200) throw new IllegalStateException("O GitHub respondeu com erro " + connection.getResponseCode() + ".");
        JSONArray releases = new JSONArray(raw);
        UpdateInfo best = null;
        for (int releaseIndex = 0; releaseIndex < releases.length(); releaseIndex++) {
            JSONObject release = releases.optJSONObject(releaseIndex);
            if (release == null || release.optBoolean("draft") || release.optBoolean("prerelease")) continue;
            JSONArray assets = release.optJSONArray("assets");
            if (assets == null) continue;
            for (int assetIndex = 0; assetIndex < assets.length(); assetIndex++) {
                JSONObject asset = assets.optJSONObject(assetIndex); if (asset == null) continue;
                String name = asset.optString("name", "");
                java.util.regex.Matcher match = java.util.regex.Pattern.compile("^BRUMCLASSICS-MOVEL-(\\d+\\.\\d+\\.\\d+)(?:-debug)?\\.apk$", java.util.regex.Pattern.CASE_INSENSITIVE).matcher(name);
                if (!match.matches() || !"uploaded".equals(asset.optString("state", "uploaded"))) continue;
                String version = match.group(1);
                if (compareVersions(version, CURRENT_VERSION) <= 0 || (best != null && compareVersions(version, best.version) <= 0)) continue;
                String digest = asset.optString("digest", "").toLowerCase(Locale.ROOT);
                if (!digest.matches("sha256:[a-f0-9]{64}")) continue;
                String url = asset.optString("browser_download_url", "");
                if (!allowedGitHubUrl(url)) continue;
                long size = asset.optLong("size", 0);
                if (size < 1024 || size > MAX_APK_BYTES) continue;
                best = new UpdateInfo(version, release.optString("body", "Nova versão do BRUMCLASSICS MOVEL."), url, digest.substring(7), size, "github", false);
            }
        }
        return best;
    }

    private UpdateInfo checkLauncher() throws Exception {
        if (!bridgeConfigured()) throw new IllegalStateException("Launcher local não conectado.");
        String url = baseUrl() + "/v1/mobile-update?current=" + CURRENT_VERSION;
        HttpURLConnection connection = open(url, "GET", true);
        String raw = readText(connection, 512 * 1024);
        if (connection.getResponseCode() == 404) return null;
        if (connection.getResponseCode() != 200) throw new IllegalStateException("O launcher local não ofereceu uma atualização.");
        JSONObject manifest = new JSONObject(raw);
        String version = manifest.optString("version", "");
        if (!manifest.optBoolean("available", false) || compareVersions(version, CURRENT_VERSION) <= 0) return null;
        String hash = manifest.optString("sha256", "").toLowerCase(Locale.ROOT);
        long size = manifest.optLong("size", 0);
        String downloadPath = manifest.optString("downloadPath", "");
        if (!hash.matches("[a-f0-9]{64}") || size < 1024 || size > MAX_APK_BYTES || !"/v1/mobile-update/apk".equals(downloadPath)) throw new IllegalStateException("Manifesto local inválido.");
        return new UpdateInfo(version, manifest.optString("notes", "Atualização fornecida pelo launcher."), baseUrl() + downloadPath, hash, size, "launcher", true);
    }

    private File download(UpdateInfo update) throws Exception {
        status("downloading", "Baixando pelo " + ("github".equals(update.source) ? "GitHub" : "launcher local") + "...", 0);
        File target = UpdateFileProvider.updateFile(context);
        File directory = target.getParentFile();
        if (!directory.exists() && !directory.mkdirs()) throw new IllegalStateException("Não foi possível preparar o armazenamento.");
        File temporary = new File(directory, "pending-update.tmp");
        if (temporary.exists()) temporary.delete();
        HttpURLConnection connection = open(update.url, "GET", update.authenticated);
        int response = connection.getResponseCode();
        if (response != 200) throw new IllegalStateException("O download respondeu com erro " + response + ".");
        long total = 0; long lastReport = 0;
        try (InputStream input = connection.getInputStream(); FileOutputStream output = new FileOutputStream(temporary)) {
            byte[] buffer = new byte[32 * 1024]; int read;
            while ((read = input.read(buffer)) >= 0) {
                total += read;
                if (total > MAX_APK_BYTES || total > update.size) throw new IllegalStateException("O download excedeu o tamanho publicado.");
                output.write(buffer, 0, read);
                if (System.currentTimeMillis() - lastReport > 300) {
                    lastReport = System.currentTimeMillis();
                    status("downloading", "Baixando atualização...", Math.min(99, Math.round(total * 100f / update.size)));
                }
            }
            output.getFD().sync();
        } catch (Exception error) { temporary.delete(); throw error; }
        if (total != update.size) { temporary.delete(); throw new IllegalStateException("O tamanho baixado não corresponde ao publicado."); }
        if (target.exists() && !target.delete()) { temporary.delete(); throw new IllegalStateException("Não foi possível substituir o download anterior."); }
        if (!temporary.renameTo(target)) { temporary.delete(); throw new IllegalStateException("Não foi possível concluir o download."); }
        return target;
    }

    private void verifyApk(File target, UpdateInfo update) throws Exception {
        try (FileInputStream input = new FileInputStream(target)) {
            if (input.read() != 'P' || input.read() != 'K') throw new IllegalStateException("O arquivo recebido não é um APK válido.");
        }
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(target)) {
            byte[] buffer = new byte[32 * 1024]; int read;
            while ((read = input.read(buffer)) >= 0) digest.update(buffer, 0, read);
        }
        StringBuilder value = new StringBuilder();
        for (byte item : digest.digest()) value.append(String.format(Locale.ROOT, "%02x", item & 0xff));
        if (!value.toString().equals(update.sha256)) { target.delete(); throw new IllegalStateException("A verificação SHA-256 rejeitou o APK."); }
    }

    private void requestInstallPermissionOrInstall() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !context.getPackageManager().canRequestPackageInstalls()) {
            status("permission", "Autorize o BRUMCLASSICS a instalar esta atualização.", 100);
            Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + context.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return;
        }
        installPending = false;
        launchInstaller();
    }

    private void launchInstaller() {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(UpdateFileProvider.APK_URI, "application/vnd.android.package-archive");
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
        context.startActivity(intent);
    }

    private HttpURLConnection open(String url, String method, boolean authenticated) throws Exception {
        if (authenticated && !allowedLocalUrl(url)) throw new IllegalArgumentException("Endereço local de atualização inválido.");
        if (!authenticated && !allowedGitHubUrl(url)) throw new IllegalArgumentException("Origem de atualização não permitida.");
        HttpURLConnection connection = authenticated
            ? PinnedTls.open(url, bridgePreferences.getString("tls_pin", ""))
            : (HttpURLConnection) new URL(url).openConnection();
        connection.setRequestMethod(method); connection.setConnectTimeout(8000); connection.setReadTimeout(30000);
        connection.setInstanceFollowRedirects(!authenticated); connection.setUseCaches(false);
        connection.setRequestProperty("Accept", "application/vnd.github+json, application/vnd.android.package-archive, application/json");
        connection.setRequestProperty("User-Agent", "BRUMCLASSICS-MOVEL/0.17.0 Android");
        if (authenticated) connection.setRequestProperty("Authorization", "Bearer " + bridgePreferences.getString("token", ""));
        return connection;
    }

    private boolean bridgeConfigured() { return !bridgePreferences.getString("host", "").isEmpty() && !bridgePreferences.getString("token", "").isEmpty() && !bridgePreferences.getString("tls_pin", "").isEmpty(); }
    private String baseUrl() { return "https://" + bridgePreferences.getString("host", "") + ":" + bridgePreferences.getInt("port", 46991); }
    private boolean allowedLocalUrl(String value) { return value != null && value.startsWith(baseUrl() + "/v1/mobile-update"); }
    private boolean allowedGitHubUrl(String value) {
        try {
            URL url = new URL(value);
            String host = url.getHost().toLowerCase(Locale.ROOT);
            return "https".equals(url.getProtocol()) && ("api.github.com".equals(host) || "github.com".equals(host) || host.endsWith(".githubusercontent.com"));
        } catch (Exception ignored) { return false; }
    }

    private String readText(HttpURLConnection connection, int maximum) throws Exception {
        InputStream input = connection.getResponseCode() >= 400 ? connection.getErrorStream() : connection.getInputStream();
        if (input == null) return "";
        java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
        byte[] buffer = new byte[8192]; int read; int total = 0;
        while ((read = input.read(buffer)) >= 0) { total += read; if (total > maximum) throw new IllegalStateException("Resposta muito grande."); output.write(buffer, 0, read); }
        return new String(output.toByteArray(), StandardCharsets.UTF_8);
    }

    private int compareVersions(String left, String right) {
        String[] a = left.split("\\."); String[] b = right.split("\\.");
        if (a.length != 3 || b.length != 3) throw new IllegalArgumentException("Versão inválida.");
        for (int index = 0; index < 3; index++) { int difference = Integer.parseInt(a[index]) - Integer.parseInt(b[index]); if (difference != 0) return difference < 0 ? -1 : 1; }
        return 0;
    }

    private void status(String state, String detail, int percent) { listener.onStatus(state, detail, percent); }
    private String safeMessage(Exception error) {
        String value = error == null ? "Não foi possível verificar a atualização." : String.valueOf(error.getMessage());
        return value.length() > 220 ? value.substring(0, 220) : value;
    }
}

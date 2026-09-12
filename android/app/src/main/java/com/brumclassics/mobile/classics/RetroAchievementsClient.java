package com.brumclassics.mobile.classics;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class RetroAchievementsClient {
    public interface Callback {
        void onSuccess(String title, List<LocalClassic.Achievement> achievements);
        void onError(String message);
    }

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    public void fetch(int gameId, String username, String key, Callback callback) {
        if (gameId <= 0 || username == null || username.trim().isEmpty() || key == null || key.trim().isEmpty()) {
            callback.onError("Informe usuário, Web API Key e ID oficial do jogo."); return;
        }
        executor.execute(() -> {
            try {
                String endpoint = "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php?y="
                    + URLEncoder.encode(key.trim(), "UTF-8") + "&u=" + URLEncoder.encode(username.trim(), "UTF-8") + "&g=" + gameId;
                HttpURLConnection connection = (HttpURLConnection) new URL(endpoint).openConnection();
                connection.setConnectTimeout(8_000); connection.setReadTimeout(20_000); connection.setUseCaches(false);
                connection.setRequestProperty("Accept", "application/json"); connection.setRequestProperty("User-Agent", "BRUMCLASSICS-Android/0.17.0");
                int code = connection.getResponseCode();
                if (code != 200) throw new IllegalStateException("RetroAchievements indisponível ou credencial inválida (" + code + ").");
                String raw; try (InputStream input = connection.getInputStream()) { raw = new String(readAll(input, 12 * 1024 * 1024), StandardCharsets.UTF_8); }
                JSONObject root = new JSONObject(raw);
                if (root.has("Error") || root.optInt("ID", -1) != gameId) throw new IllegalStateException("O RetroAchievements não retornou o jogo solicitado.");
                String title = root.optString("Title", "Jogo " + gameId); JSONObject rows = root.optJSONObject("Achievements");
                if (rows == null) throw new IllegalStateException("O conjunto de conquistas não pôde ser lido.");
                List<LocalClassic.Achievement> achievements = new ArrayList<>(); Iterator<String> ids = rows.keys();
                while (ids.hasNext()) {
                    String id = ids.next(); JSONObject item = rows.optJSONObject(id); if (item == null) continue;
                    String soft = item.optString("DateEarned"); String hard = item.optString("DateEarnedHardcore");
                    achievements.add(new LocalClassic.Achievement(id, item.optString("Title", "Conquista"), item.optString("Description"),
                        Math.max(0, item.optInt("Points")), !soft.isEmpty() || !hard.isEmpty(), !hard.isEmpty(), hard.isEmpty() ? soft : hard));
                }
                Collections.sort(achievements, Comparator.comparing(item -> item.title.toLowerCase(java.util.Locale.ROOT)));
                main.post(() -> callback.onSuccess(title, achievements));
                throttle();
            } catch (Exception error) {
                String message = error.getMessage() == null ? "Não foi possível consultar o RetroAchievements." : error.getMessage();
                main.post(() -> callback.onError(message + " O progresso salvo foi preservado."));
                throttle();
            }
        });
    }

    public void close() { executor.shutdownNow(); }

    private static void throttle() {
        try { Thread.sleep(1_000L); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
    }

    private static byte[] readAll(InputStream input, int maximum) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int read; int total = 0;
        while ((read = input.read(buffer)) >= 0) { total += read; if (total > maximum) throw new IllegalStateException("Resposta grande demais."); output.write(buffer, 0, read); }
        return output.toByteArray();
    }
}

package com.brumclassics.mobile.classics;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public final class LocalClassic {
    public final String id;
    public String uri;
    public String relativePath;
    public String filename;
    public String title;
    public long fileSize;
    public String launcherGameId = "";
    public int raGameId;
    public long lastPlayedAt;
    public String progressTitle = "";
    public String progressUsername = "";
    public long progressUpdatedAt;
    public final List<Achievement> achievements = new ArrayList<>();
    public String streamId;
    public long lastObservedSeconds;
    public long creditedSeconds;
    public long acknowledgedSeconds = -1L;
    public String serverFingerprint = "";
    public boolean counterReset;

    public static final class Achievement {
        public final String id;
        public final String title;
        public final String description;
        public final int points;
        public final boolean unlocked;
        public final boolean hardcore;
        public final String unlockedAt;

        public Achievement(String id, String title, String description, int points, boolean unlocked, boolean hardcore, String unlockedAt) {
            this.id = id; this.title = title; this.description = description; this.points = points;
            this.unlocked = unlocked; this.hardcore = hardcore; this.unlockedAt = unlockedAt;
        }

        JSONObject toJson() throws Exception {
            JSONObject result = new JSONObject();
            result.put("id", id); result.put("title", title); result.put("description", description);
            result.put("points", points); result.put("unlocked", unlocked); result.put("hardcore", hardcore);
            result.put("unlockedAt", unlockedAt);
            return result;
        }

        static Achievement fromJson(JSONObject item) {
            return new Achievement(item.optString("id"), item.optString("title", "Conquista"), item.optString("description"),
                Math.max(0, item.optInt("points")), item.optBoolean("unlocked"), item.optBoolean("hardcore"), item.optString("unlockedAt"));
        }
    }

    public LocalClassic(String id, String uri, String relativePath, String filename, String title, long fileSize) {
        this.id = id; this.uri = uri; this.relativePath = relativePath; this.filename = filename; this.title = title; this.fileSize = fileSize;
        this.streamId = java.util.UUID.randomUUID().toString();
    }

    public int unlockedCount() {
        int count = 0; for (Achievement achievement : achievements) if (achievement.unlocked) count++; return count;
    }

    public int progressPercent() {
        return achievements.isEmpty() ? 0 : Math.min(100, Math.round(unlockedCount() * 100f / achievements.size()));
    }

    public JSONObject toJson() throws Exception {
        JSONObject result = new JSONObject();
        result.put("id", id); result.put("uri", uri); result.put("relativePath", relativePath);
        result.put("filename", filename); result.put("title", title); result.put("fileSize", fileSize);
        result.put("launcherGameId", launcherGameId); result.put("raGameId", raGameId); result.put("lastPlayedAt", lastPlayedAt);
        result.put("progressTitle", progressTitle); result.put("progressUsername", progressUsername); result.put("progressUpdatedAt", progressUpdatedAt);
        JSONArray rows = new JSONArray(); for (Achievement achievement : achievements) rows.put(achievement.toJson()); result.put("achievements", rows);
        result.put("streamId", streamId); result.put("lastObservedSeconds", lastObservedSeconds);
        result.put("creditedSeconds", creditedSeconds); result.put("acknowledgedSeconds", acknowledgedSeconds);
        result.put("serverFingerprint", serverFingerprint); result.put("counterReset", counterReset);
        return result;
    }

    public static LocalClassic fromJson(JSONObject item) {
        LocalClassic game = new LocalClassic(item.optString("id"), item.optString("uri"), item.optString("relativePath"),
            item.optString("filename"), item.optString("title"), Math.max(0L, item.optLong("fileSize")));
        game.launcherGameId = item.optString("launcherGameId"); game.raGameId = Math.max(0, item.optInt("raGameId"));
        game.lastPlayedAt = Math.max(0L, item.optLong("lastPlayedAt")); game.progressTitle = item.optString("progressTitle");
        game.progressUsername = item.optString("progressUsername"); game.progressUpdatedAt = Math.max(0L, item.optLong("progressUpdatedAt"));
        JSONArray rows = item.optJSONArray("achievements");
        if (rows != null) for (int index = 0; index < rows.length(); index++) {
            JSONObject row = rows.optJSONObject(index); if (row != null) game.achievements.add(Achievement.fromJson(row));
        }
        game.streamId = item.optString("streamId", game.streamId); game.lastObservedSeconds = Math.max(0L, item.optLong("lastObservedSeconds"));
        game.creditedSeconds = Math.max(0L, item.optLong("creditedSeconds")); game.acknowledgedSeconds = item.optLong("acknowledgedSeconds", -1L);
        if (game.acknowledgedSeconds < -1L) game.acknowledgedSeconds = -1L;
        if (game.acknowledgedSeconds > game.creditedSeconds) game.acknowledgedSeconds = game.creditedSeconds;
        game.serverFingerprint = item.optString("serverFingerprint"); game.counterReset = item.optBoolean("counterReset");
        return game;
    }
}

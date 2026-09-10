package com.brumclassics.mobile.data;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;

import com.brumclassics.mobile.model.Game;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

public final class GameRepository {
    private final SharedPreferences preferences;
    private List<Game> games;
    private boolean synchronizedLibrary;

    public GameRepository(Context context) {
        preferences = context.getSharedPreferences("brum_mobile_demo", Context.MODE_PRIVATE);
        games = Arrays.asList(
            new Game("neon-circuit", "Neon Circuit", "Velocidade, precisão e cidades elétricas em uma liga automobilística do futuro.", "PC", "Corrida", Game.Status.PLAYING, 68, 2560, true, Color.rgb(19, 62, 77), Color.rgb(135, 255, 93)),
            new Game("echoes-atlas", "Echoes of Atlas", "Uma expedição silenciosa por ruínas orbitais e memórias esquecidas.", "PlayStation 5", "Aventura", Game.Status.PLAYING, 42, 1120, true, Color.rgb(20, 37, 75), Color.rgb(73, 132, 201)),
            new Game("iron-frontier", "Iron Frontier", "Construa sua tripulação e atravesse uma fronteira industrial sem mapas.", "Xbox Series", "RPG", Game.Status.COMPLETED, 100, 4860, true, Color.rgb(66, 31, 18), Color.rgb(222, 124, 62)),
            new Game("moonlit-vale", "Moonlit Vale", "Mistérios ancestrais aguardam sob a luz de duas luas.", "Nintendo Switch", "Aventura", Game.Status.BACKLOG, 0, 0, false, Color.rgb(35, 25, 69), Color.rgb(184, 92, 196)),
            new Game("pocket-rally", "Pocket Rally 96", "Corridas compactas inspiradas nos grandes portáteis de 16 bits.", "Game Boy Advance", "Corrida", Game.Status.COMPLETED, 100, 735, false, Color.rgb(47, 32, 79), Color.rgb(246, 180, 65)),
            new Game("astra-protocol", "Astra Protocol", "Táticas de esquadrão em estações onde cada decisão deixa uma cicatriz.", "PC", "Estratégia", Game.Status.PLAYING, 81, 3215, true, Color.rgb(15, 53, 53), Color.rgb(52, 205, 187)),
            new Game("chronicles-94", "Chronicles 94", "Um RPG de jornada, amizade e mapas desenhados à mão.", "Super Nintendo", "RPG", Game.Status.ABANDONED, 23, 415, false, Color.rgb(73, 27, 40), Color.rgb(218, 77, 104)),
            new Game("silent-harbor", "Silent Harbor", "Investigue um porto abandonado enquanto a maré apaga as pistas.", "PlayStation", "Suspense", Game.Status.BACKLOG, 0, 0, false, Color.rgb(26, 43, 50), Color.rgb(97, 138, 147)),
            new Game("glass-kingdom", "Glass Kingdom", "Defenda um reino frágil usando magia, arquitetura e diplomacia.", "PC", "Estratégia", Game.Status.COMPLETED, 100, 2780, false, Color.rgb(38, 37, 70), Color.rgb(153, 166, 255)),
            new Game("orbital-drift", "Orbital Drift", "Sobreviva a rotas impossíveis entre colônias à deriva.", "Xbox Series", "Ação", Game.Status.BACKLOG, 0, 95, true, Color.rgb(20, 29, 47), Color.rgb(61, 205, 255))
        );
    }

    public synchronized List<Game> all() { return new ArrayList<>(games); }

    public synchronized boolean isSynchronizedLibrary() { return synchronizedLibrary; }

    public synchronized int replaceFromSnapshot(String rawJson) throws Exception {
        JSONObject root = new JSONObject(rawJson);
        JSONArray input = root.optJSONArray("games");
        if (input == null) throw new IllegalArgumentException("A resposta do launcher não contém uma biblioteca válida.");
        if (input.length() == 0 && synchronizedLibrary && !games.isEmpty()) {
            throw new IllegalArgumentException("A resposta vazia foi ignorada para preservar a biblioteca offline.");
        }
        List<Game> synchronizedGames = new ArrayList<>();
        for (int index = 0; index < input.length(); index++) {
            JSONObject item = input.optJSONObject(index);
            if (item == null) continue;
            String id = item.optString("id", "").trim();
            String title = item.optString("title", "").trim();
            if (id.isEmpty() || title.isEmpty()) continue;
            boolean playtimeAvailable = item.optBoolean("playtimeAvailable", !item.isNull("playtimeMinutes"));
            boolean achievementsAvailable = item.optBoolean("achievementsAvailable", !item.isNull("achievementsCollected") && !item.isNull("achievementsTotal"));
            int collected = achievementsAvailable ? Math.max(0, item.optInt("achievementsCollected", 0)) : 0;
            int total = achievementsAvailable ? Math.max(0, item.optInt("achievementsTotal", 0)) : 0;
            int progress = total > 0 ? Math.min(100, Math.round(collected * 100f / total)) : 0;
            int played = item.isNull("playtimeMinutes") ? 0 : Math.max(0, item.optInt("playtimeMinutes", 0));
            Game.Status status = total > 0 && collected >= total ? Game.Status.COMPLETED : played > 0 ? Game.Status.PLAYING : Game.Status.BACKLOG;
            List<Game.Achievement> achievements = new ArrayList<>();
            JSONArray achievementInput = item.optJSONArray("achievements");
            if (achievementInput != null) for (int achievementIndex = 0; achievementIndex < achievementInput.length(); achievementIndex++) {
                JSONObject achievement = achievementInput.optJSONObject(achievementIndex);
                if (achievement == null) continue;
                achievements.add(new Game.Achievement(
                    achievement.optString("id", ""), achievement.optString("title", "Conquista"),
                    achievement.optString("description", ""), achievement.optBoolean("unlocked", false),
                    achievement.optInt("points", 0), achievement.optString("unlockedAt", "")
                ));
            }
            int hash = title.hashCode();
            float hue = Math.abs(hash % 360);
            int start = Color.HSVToColor(new float[]{hue, .62f, .34f});
            int end = Color.HSVToColor(new float[]{(hue + 38f) % 360f, .58f, .88f});
            String platform = displayPlatform(item.optString("platform", "PC"), item.optString("category", "modern"));
            String store = item.optString("store", "").trim();
            String genre = item.optString("genre", "").trim();
            if (genre.isEmpty()) genre = store.isEmpty() ? ("classic".equals(item.optString("category")) ? "Clássico" : "Jogo") : store.toUpperCase();
            JSONObject notes = item.optJSONObject("notes");
            if (notes == null) notes = new JSONObject();
            synchronizedGames.add(new Game(
                id, title, item.optString("description", "Dados sincronizados pelo launcher BRUMCLASSICS."), platform, genre,
                status, progress, played, played > 0 || !item.optString("lastPlayedAt", "").isEmpty(), start, end,
                item.optString("artworkPath", ""), item.optBoolean("installed", false), achievements,
                playtimeAvailable, achievementsAvailable,
                notes.optString("whereStopped", ""), notes.optString("objectives", ""),
                notes.optString("tips", ""), notes.optString("commands", ""),
                Math.max(0, notes.optInt("revision", 0)), notes.optString("updatedAt", ""),
                item.optBoolean("favorite", false), item.optBoolean("wantToPlay", false),
                Math.max(0, item.optInt("libraryStateRevision", 0)),
                item.optString("libraryStateUpdatedAt", ""), item.optString("lastPlayedAt", ""), item.optString("category", "")
            ));
        }
        if (input.length() > 0 && synchronizedGames.isEmpty()) {
            throw new IllegalArgumentException("A resposta do launcher não contém jogos utilizáveis.");
        }
        games = synchronizedGames;
        synchronizedLibrary = true;
        return games.size();
    }

    private String displayPlatform(String raw, String category) {
        String value = raw == null ? "" : raw.trim();
        if (value.isEmpty()) return "classic".equals(category) ? "CLASSICS" : "PC";
        if ("pc".equalsIgnoreCase(value)) return "PC";
        return value.replace('_', ' ').toUpperCase();
    }

    public boolean isFavorite(String gameId) {
        return preferences.getStringSet("favorites", new HashSet<>()).contains(gameId);
    }

    public void toggleFavorite(String gameId) {
        Set<String> next = new HashSet<>(preferences.getStringSet("favorites", new HashSet<>()));
        if (!next.add(gameId)) next.remove(gameId);
        preferences.edit().putStringSet("favorites", next).apply();
    }
}

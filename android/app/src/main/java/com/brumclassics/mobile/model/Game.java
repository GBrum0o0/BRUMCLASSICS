package com.brumclassics.mobile.model;

import java.util.ArrayList;
import java.util.List;

public final class Game {
    public enum Status { PLAYING, COMPLETED, BACKLOG, ABANDONED }

    public final String id;
    public final String title;
    public final String description;
    public final String platform;
    public final String category;
    public final String genre;
    public final Status status;
    public final int progress;
    public final int minutesPlayed;
    public final boolean playtimeAvailable;
    public final boolean achievementsAvailable;
    public final boolean recent;
    public final int colorStart;
    public final int colorEnd;
    public final String artworkPath;
    public final boolean installed;
    public final List<Achievement> achievements;
    public final String whereStopped;
    public final String objectives;
    public final String tips;
    public final String commands;
    public final int notesRevision;
    public final String notesUpdatedAt;
    public final boolean favorite;
    public final boolean wantToPlay;
    public final int libraryStateRevision;
    public final String libraryStateUpdatedAt;
    public final String lastPlayedAt;

    public static final class Achievement {
        public final String id;
        public final String title;
        public final String description;
        public final boolean unlocked;
        public final int points;
        public final String unlockedAt;

        public Achievement(String id, String title, String description, boolean unlocked, int points, String unlockedAt) {
            this.id = id; this.title = title; this.description = description; this.unlocked = unlocked; this.points = points; this.unlockedAt = unlockedAt;
        }
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd) {
        this(id, title, description, platform, genre, status, progress, minutesPlayed, recent,
            colorStart, colorEnd, "", false, new ArrayList<>(), true, true, "", "", "", "");
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd, String artworkPath, boolean installed,
                List<Achievement> achievements, boolean playtimeAvailable, boolean achievementsAvailable) {
        this(id, title, description, platform, genre, status, progress, minutesPlayed, recent,
            colorStart, colorEnd, artworkPath, installed, achievements, playtimeAvailable,
            achievementsAvailable, "", "", "", "");
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd, String artworkPath, boolean installed,
                List<Achievement> achievements, boolean playtimeAvailable, boolean achievementsAvailable,
                String whereStopped, String objectives, String tips, String commands) {
        this(id, title, description, platform, genre, status, progress, minutesPlayed, recent,
            colorStart, colorEnd, artworkPath, installed, achievements, playtimeAvailable,
            achievementsAvailable, whereStopped, objectives, tips, commands, 0, "", false, 0, "");
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd, String artworkPath, boolean installed,
                List<Achievement> achievements, boolean playtimeAvailable, boolean achievementsAvailable,
                String whereStopped, String objectives, String tips, String commands,
                int notesRevision, String notesUpdatedAt, boolean wantToPlay,
                int libraryStateRevision, String libraryStateUpdatedAt) {
        this(id, title, description, platform, genre, status, progress, minutesPlayed, recent,
            colorStart, colorEnd, artworkPath, installed, achievements, playtimeAvailable,
            achievementsAvailable, whereStopped, objectives, tips, commands, notesRevision,
            notesUpdatedAt, false, wantToPlay, libraryStateRevision, libraryStateUpdatedAt, "");
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd, String artworkPath, boolean installed,
                List<Achievement> achievements, boolean playtimeAvailable, boolean achievementsAvailable,
                String whereStopped, String objectives, String tips, String commands,
                int notesRevision, String notesUpdatedAt, boolean favorite, boolean wantToPlay,
                int libraryStateRevision, String libraryStateUpdatedAt, String lastPlayedAt) {
        this(id, title, description, platform, genre, status, progress, minutesPlayed, recent,
            colorStart, colorEnd, artworkPath, installed, achievements, playtimeAvailable,
            achievementsAvailable, whereStopped, objectives, tips, commands, notesRevision,
            notesUpdatedAt, favorite, wantToPlay, libraryStateRevision, libraryStateUpdatedAt, lastPlayedAt, "");
    }

    public Game(String id, String title, String description, String platform, String genre,
                Status status, int progress, int minutesPlayed, boolean recent,
                int colorStart, int colorEnd, String artworkPath, boolean installed,
                List<Achievement> achievements, boolean playtimeAvailable, boolean achievementsAvailable,
                String whereStopped, String objectives, String tips, String commands,
                int notesRevision, String notesUpdatedAt, boolean favorite, boolean wantToPlay,
                int libraryStateRevision, String libraryStateUpdatedAt, String lastPlayedAt, String category) {
        this.id = id;
        this.title = title;
        this.description = description;
        this.platform = platform;
        this.category = normalizeCategory(category, platform, genre);
        this.genre = genre;
        this.status = status;
        this.progress = progress;
        this.minutesPlayed = minutesPlayed;
        this.playtimeAvailable = playtimeAvailable;
        this.achievementsAvailable = achievementsAvailable;
        this.recent = recent;
        this.colorStart = colorStart;
        this.colorEnd = colorEnd;
        this.artworkPath = artworkPath == null ? "" : artworkPath;
        this.installed = installed;
        this.achievements = achievements == null ? new ArrayList<>() : new ArrayList<>(achievements);
        this.whereStopped = whereStopped == null ? "" : whereStopped;
        this.objectives = objectives == null ? "" : objectives;
        this.tips = tips == null ? "" : tips;
        this.commands = commands == null ? "" : commands;
        this.notesRevision = Math.max(0, notesRevision);
        this.notesUpdatedAt = notesUpdatedAt == null ? "" : notesUpdatedAt;
        this.favorite = favorite;
        this.wantToPlay = wantToPlay;
        this.libraryStateRevision = Math.max(0, libraryStateRevision);
        this.libraryStateUpdatedAt = libraryStateUpdatedAt == null ? "" : libraryStateUpdatedAt;
        this.lastPlayedAt = lastPlayedAt == null ? "" : lastPlayedAt;
    }

    public String statusLabel() {
        switch (status) {
            case PLAYING: return "JOGANDO";
            case COMPLETED: return "CONCLUÍDO";
            case ABANDONED: return "ABANDONADO";
            default: return wantToPlay ? "QUERO JOGAR" : "NÃO INICIADO";
        }
    }

    private static String normalizeCategory(String category, String platform, String genre) {
        if ("classic".equals(category) || "modern".equals(category)) return category;
        // Compatibility only for old data without a category; the launcher wins.
        String value = platform == null ? "" : platform.toLowerCase(java.util.Locale.ROOT).replace(" ", "").replace("_", "");
        switch (value) {
            case "gb": case "gbc": case "gba": case "gameboy": case "gameboycolor": case "gameboyadvance":
            case "nes": case "snes": case "supernintendo": case "n64": case "nds":
            case "ps1": case "psx": case "ps2": case "ps3": case "playstation": case "psp":
            case "genesis": case "megadrive": case "gamecube": case "arcade": case "classics":
                return "classic";
            default: return "Clássico".equalsIgnoreCase(genre) ? "classic" : "modern";
        }
    }

    public String playedLabel() {
        if (!playtimeAvailable) return "INDISPONÍVEL";
        int hours = minutesPlayed / 60;
        int minutes = minutesPlayed % 60;
        return hours > 0 ? hours + " h " + minutes + " min" : minutes + " min";
    }

    public String progressLabel() {
        return achievementsAvailable ? progress + "%" : "INDISPONÍVEL";
    }
}

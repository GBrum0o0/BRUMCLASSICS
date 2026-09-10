package com.brumclassics.mobile.model;

public final class Moment {
    public final String id;
    public final String gameId;
    public final String gameTitle;
    public final String capturedAt;
    public final String imagePath;
    public final String location;
    public final String note;
    public final String category;
    public final boolean favorite;

    public Moment(String id, String gameId, String gameTitle, String capturedAt, String imagePath,
                  String location, String note, String category, boolean favorite) {
        this.id = id == null ? "" : id;
        this.gameId = gameId == null ? "" : gameId;
        this.gameTitle = gameTitle == null ? "Jogo" : gameTitle;
        this.capturedAt = capturedAt == null ? "" : capturedAt;
        this.imagePath = imagePath == null ? "" : imagePath;
        this.location = location == null ? "" : location;
        this.note = note == null ? "" : note;
        this.category = category == null || category.isEmpty() ? "MOMENTO" : category;
        this.favorite = favorite;
    }
}

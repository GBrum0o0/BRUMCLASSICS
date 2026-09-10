package com.brumclassics.mobile.model;

/** Ephemeral state: never persist performance readings as live data. */
public final class PerformanceLiveState {
    private long receivedAt = -1L;
    private String gameId = "";
    private boolean active;

    public void accept(boolean isActive, String id, long now) {
        active = isActive && id != null && !id.isEmpty();
        gameId = active ? id : "";
        receivedAt = active ? now : -1L;
    }

    public void disconnect() { active = false; receivedAt = -1L; gameId = ""; }

    public boolean isLive(String currentGameId, long now) {
        return active && receivedAt >= 0 && now >= receivedAt && now - receivedAt < 15000L
            && gameId.equals(currentGameId);
    }
}

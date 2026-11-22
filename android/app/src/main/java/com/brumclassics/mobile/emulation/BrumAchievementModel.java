package com.brumclassics.mobile.emulation;

import java.net.URI;
import java.util.ArrayDeque;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Pure-Java model and deduplication rules for BRUM CLASSICS achievement popups.
 * Kept free of Android framework dependencies so contract tests compile cleanly with JDK javac.
 */
public final class BrumAchievementModel {
    private static final Set<String> SEEN_EVENTS = new HashSet<>();
    private static final ArrayDeque<String> SEEN_ORDER = new ArrayDeque<>();

    private BrumAchievementModel() {}

    public static String resolveEventId(String eventId, String achievementId, String title) {
        String cleanEventId = eventId == null ? "" : eventId.trim();
        if (!cleanEventId.isEmpty()) return cleanEventId;
        String cleanAchId = achievementId == null ? "" : achievementId.trim();
        if (!cleanAchId.isEmpty()) return "id:" + cleanAchId;
        String cleanTitle = title == null ? "" : title.trim().toLowerCase(Locale.ROOT);
        return "title:" + cleanTitle;
    }

    public static String normalizeTitle(String title) {
        String cleanTitle = title == null ? "" : title.trim();
        return cleanTitle.isEmpty() ? "Conquista desbloqueada" : cleanTitle;
    }

    public static String sanitizeBadgeUrl(String raw) {
        if (raw == null) return "";
        String trimmed = raw.trim();
        if (trimmed.isEmpty()) return "";
        try {
            URI uri = URI.create(trimmed);
            String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
            String path = uri.getPath() == null ? "" : uri.getPath();
            if ("https".equals(scheme)
                && ("media.retroachievements.org".equals(host) || "i.retroachievements.org".equals(host))
                && path.startsWith("/Badge/")) {
                return trimmed;
            }
        } catch (Exception ignored) {}
        return "";
    }

    public static boolean markEventIfNew(String eventId) {
        if (eventId == null || eventId.trim().isEmpty()) return true;
        String key = eventId.trim().toLowerCase(Locale.ROOT);
        synchronized (SEEN_ORDER) {
            if (SEEN_EVENTS.contains(key)) return false;
            if (SEEN_ORDER.size() >= 512) {
                String oldest = SEEN_ORDER.pollFirst();
                if (oldest != null) SEEN_EVENTS.remove(oldest);
            }
            SEEN_ORDER.addLast(key);
            SEEN_EVENTS.add(key);
            return true;
        }
    }

    public static void clearSeenEventsForTest() {
        synchronized (SEEN_ORDER) {
            SEEN_ORDER.clear();
            SEEN_EVENTS.clear();
        }
    }

    public static String formatStatusBanner(String coreDisplayName, String systemId, int raGameId, String raState, boolean missing3dsKeys) {
        String sysUpper = systemId == null ? "" : systemId.trim().toUpperCase(Locale.ROOT);
        String base = "BRUM CORE · " + (coreDisplayName == null ? "" : coreDisplayName) + " · " + sysUpper;
        if ("3DS".equals(sysUpper)) {
            return base + (missing3dsKeys ? " · falta aes_keys.txt" : "") + " · RA indisponível no 3DS";
        }
        String state = raState == null ? "" : raState.trim().toLowerCase(Locale.ROOT);
        if ("active".equals(state)) return base + " · RA ATIVO";
        if ("unrecognized".equals(state)) return base + " · RA hash não reconhecido";
        if ("error".equals(state)) return base + " · RA indisponível";
        if (raGameId > 0) return base + " · RA ID " + raGameId;
        return base;
    }

    public static final class Payload {
        public final String eventId;
        public final String achievementId;
        public final String title;
        public final String description;
        public final int points;
        public final String badgeUrl;

        public Payload(String eventId, String achievementId, String title, String description, int points, String badgeUrl) {
            this.achievementId = achievementId == null ? "" : achievementId.trim();
            this.eventId = resolveEventId(eventId, this.achievementId, title);
            this.title = normalizeTitle(title);
            this.description = description == null ? "" : description.trim();
            this.points = Math.max(0, points);
            this.badgeUrl = sanitizeBadgeUrl(badgeUrl);
        }
    }
}

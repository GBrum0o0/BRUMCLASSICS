package com.brumclassics.mobile.classics;

import java.text.Normalizer;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.List;
import java.util.ArrayList;
import java.util.Collections;

public final class ClassicsRules {
    private static final Set<String> EXTENSIONS = new HashSet<>(Arrays.asList(
        "gba", "gb", "gbc", "nes", "sfc", "smc", "n64", "z64", "v64", "nds",
        "sms", "gg", "md", "gen", "pce", "chd", "pbp", "iso", "cso", "rvz",
        "cue", "m3u", "gdi", "wad", "zip"
    ));

    private ClassicsRules() {}

    public static boolean accepts(String filename) {
        return EXTENSIONS.contains(extension(filename));
    }

    public static String extension(String filename) {
        if (filename == null) return "";
        int dot = filename.lastIndexOf('.');
        return dot < 0 || dot == filename.length() - 1 ? "" : filename.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    public static String cleanTitle(String filename) {
        if (filename == null) return "";
        String value = filename.replaceFirst("(?i)\\.[a-z0-9]{2,5}$", "")
            .replaceFirst("^\\s*\\d{1,6}\\s*(?:[-_.:]\\s*)+", "")
            .replaceAll("\\[[^\\]]*]|\\([^)]*\\)", " ")
            .replaceAll("([a-zà-öø-ÿ])([A-Z])", "$1 $2")
            .replace('_', ' ')
            .replaceFirst("(?i)\\s+-\\s+(?:rev(?:ision)?|beta|proto(?:type)?|demo|sample)\\b.*$", "")
            .replaceFirst("(?i)\\s+version\\s*$", "")
            .replaceAll("\\s+", " ")
            .trim();
        return value.replaceAll("^[-_. ]+|[-_. ]+$", "");
    }

    public static String normalizedTitle(String value) {
        String clean = cleanTitle(value);
        clean = Normalizer.normalize(clean, Normalizer.Form.NFD).replaceAll("\\p{M}+", "");
        return clean.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", " ").trim().replaceAll("\\s+", " ");
    }

    public static String runtimeLogName(String filename) {
        if (filename == null || filename.isEmpty() || filename.contains("/") || filename.contains("\\")) {
            throw new IllegalArgumentException("Nome de ROM inválido.");
        }
        int dot = filename.lastIndexOf('.');
        return (dot > 0 ? filename.substring(0, dot) : filename) + ".lrtl";
    }

    public static long parseRuntimeSeconds(String json) {
        if (json == null || json.length() > 65_536) throw new IllegalArgumentException("Log inválido ou grande demais.");
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile("\\\"runtime\\\"\\s*:\\s*\\\"(\\d+):(\\d{2}):(\\d{2})\\\"").matcher(json);
        if (!matcher.find()) throw new IllegalArgumentException("Formato de tempo do RetroArch não reconhecido.");
        long hours = Long.parseLong(matcher.group(1));
        int minutes = Integer.parseInt(matcher.group(2));
        int seconds = Integer.parseInt(matcher.group(3));
        if (hours > 87_660 || minutes >= 60 || seconds >= 60) throw new IllegalArgumentException("Formato de tempo do RetroArch não reconhecido.");
        return hours * 3600L + minutes * 60L + seconds;
    }

    public static String artworkRepository(String filename) {
        switch (extension(filename)) {
            case "gba": return "Nintendo_-_Game_Boy_Advance";
            case "gb": return "Nintendo_-_Game_Boy";
            case "gbc": return "Nintendo_-_Game_Boy_Color";
            case "nes": return "Nintendo_-_Nintendo_Entertainment_System";
            case "sfc": case "smc": return "Nintendo_-_Super_Nintendo_Entertainment_System";
            case "n64": case "z64": case "v64": return "Nintendo_-_Nintendo_64";
            case "nds": return "Nintendo_-_Nintendo_DS";
            case "md": case "gen": return "Sega_-_Mega_Drive_-_Genesis";
            case "sms": return "Sega_-_Master_System_-_Mark_III";
            case "gg": return "Sega_-_Game_Gear";
            case "pce": return "NEC_-_PC_Engine_-_TurboGrafx_16";
            default: return null;
        }
    }

    public static String matchArtwork(String filename, List<String> paths) {
        String wanted = normalizedTitle(filename); if (wanted.isEmpty() || paths == null) return null;
        List<String> candidates = new ArrayList<>();
        for (String path : paths) {
            if (path == null || !path.startsWith("Named_Boxarts/") || !path.toLowerCase(Locale.ROOT).endsWith(".png") || path.indexOf('/', 14) >= 0) continue;
            String name = path.substring(path.lastIndexOf('/') + 1);
            if (normalizedTitle(name).equals(wanted)) candidates.add(path);
        }
        Collections.sort(candidates); if (candidates.isEmpty()) return null;
        String region = filename != null && filename.matches(".*\\((?:U|USA)(?:\\)|,).*" ) ? "USA" :
            filename != null && filename.matches(".*\\((?:E|Europe)(?:\\)|,).*" ) ? "Europe" :
            filename != null && filename.matches(".*\\((?:J|Japan)(?:\\)|,).*" ) ? "Japan" : null;
        if (region != null) for (String candidate : candidates) if (candidate.contains(region)) return candidate;
        return candidates.get(0);
    }
}

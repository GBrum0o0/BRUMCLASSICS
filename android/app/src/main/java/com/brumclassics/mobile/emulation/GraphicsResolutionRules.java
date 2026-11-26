package com.brumclassics.mobile.emulation;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** Pure-JVM resolution enhancement rules shared by Android runtime and contract tests. */
public final class GraphicsResolutionRules {
    public static final String PROFILE_ORIGINAL = "original";
    public static final String PROFILE_AUTOMATIC = "automatic";
    public static final String PROFILE_ENHANCED = "enhanced";
    public static final String PROFILE_CUSTOM = "custom";

    public static final String SCALE_ORIGINAL = "original";
    public static final String SCALE_INTEGER = "integer";
    public static final String SCALE_STRETCH = "stretch";

    public static final String FILTER_NONE = "none";
    public static final String FILTER_CRT_SCANLINES = "crt_scanlines";
    public static final String FILTER_LCD_GRID = "lcd_grid";
    public static final String FILTER_BILINEAR_SUBTLE = "bilinear_subtle";
    public static final String FILTER_CAS_SHARPEN = "cas_sharpen";
    public static final String FILTER_SHARP_BILINEAR = "sharp_bilinear";
    public static final String FILTER_EDGE_UPSCALE_2X = "edge_upscale_2x";

    public static final String TIER_LOW = "low";
    public static final String TIER_MEDIUM = "medium";
    public static final String TIER_HIGH = "high";

    public static final class CatalogEntry {
        public final String id;
        public final String label;
        public final boolean is3D;
        public final boolean handheld;
        public final boolean heavy;
        public final String aspectRatio;
        public final int maxMultiplier;
        public final boolean supportsIntegerScale;
        public final List<String> supportedFilters;

        CatalogEntry(String id, String label, boolean is3D, boolean handheld, boolean heavy,
                     String aspectRatio, int maxMultiplier, List<String> supportedFilters) {
            this.id = id;
            this.label = label;
            this.is3D = is3D;
            this.handheld = handheld;
            this.heavy = heavy;
            this.aspectRatio = aspectRatio;
            this.maxMultiplier = maxMultiplier;
            this.supportsIntegerScale = true;
            this.supportedFilters = Collections.unmodifiableList(supportedFilters);
        }
    }

    public static final class SystemOverride {
        public String profile;
        public int multiplier = 1;
        public String scaleMode = SCALE_ORIGINAL;
        public String videoFilter = FILTER_NONE;
    }

    public static final class Settings {
        public String profile = PROFILE_AUTOMATIC;
        public int globalMultiplier = 2;
        public String globalScaleMode = SCALE_ORIGINAL;
        public String globalVideoFilter = FILTER_NONE;
        public final Map<String, SystemOverride> systems = new HashMap<>();
    }

    public static final class ResolvedConfig {
        public final String profile;
        public final String systemId;
        public final boolean is3D;
        public final String aspectRatio;
        public final boolean preserveAspectRatio;
        public final int internalMultiplier;
        public final String scaleMode;
        public final boolean integerScalingEnabled;
        public final String videoFilterMode;
        public final Map<String, String> coreVariables;
        public final String hardwareTier;

        ResolvedConfig(String profile, String systemId, boolean is3D, String aspectRatio,
                       boolean preserveAspectRatio, int internalMultiplier, String scaleMode,
                       String videoFilterMode, Map<String, String> coreVariables, String hardwareTier) {
            this.profile = profile;
            this.systemId = systemId;
            this.is3D = is3D;
            this.aspectRatio = aspectRatio;
            this.preserveAspectRatio = preserveAspectRatio;
            this.internalMultiplier = internalMultiplier;
            this.scaleMode = scaleMode;
            this.integerScalingEnabled = SCALE_INTEGER.equals(scaleMode);
            this.videoFilterMode = videoFilterMode;
            this.coreVariables = Collections.unmodifiableMap(coreVariables);
            this.hardwareTier = hardwareTier;
        }
    }

    private static final List<CatalogEntry> CATALOG = new ArrayList<>();
    private static final Map<String, CatalogEntry> CATALOG_MAP = new LinkedHashMap<>();
    private static final Map<String, String> ALIASES = new HashMap<>();

    static {
        List<String> consoleFilters = Arrays.asList(
                FILTER_NONE, FILTER_CRT_SCANLINES, FILTER_SHARP_BILINEAR, FILTER_EDGE_UPSCALE_2X, FILTER_CAS_SHARPEN, FILTER_BILINEAR_SUBTLE);
        List<String> handheldFilters = Arrays.asList(
                FILTER_NONE, FILTER_LCD_GRID, FILTER_SHARP_BILINEAR, FILTER_EDGE_UPSCALE_2X, FILTER_CAS_SHARPEN, FILTER_BILINEAR_SUBTLE);
        List<String> allFilters = Arrays.asList(
                FILTER_NONE, FILTER_CRT_SCANLINES, FILTER_LCD_GRID, FILTER_SHARP_BILINEAR, FILTER_EDGE_UPSCALE_2X, FILTER_CAS_SHARPEN, FILTER_BILINEAR_SUBTLE);

        addEntry("atari2600", "Atari 2600", false, false, false, "4:3", 1, consoleFilters);
        addEntry("atari5200", "Atari 5200", false, false, false, "4:3", 1, consoleFilters);
        addEntry("atari7800", "Atari 7800", false, false, false, "4:3", 1, consoleFilters);
        addEntry("lynx", "Atari Lynx", false, true, false, "160:102", 1, handheldFilters);
        addEntry("nes", "Nintendo (NES)", false, false, false, "4:3", 1, consoleFilters);
        addEntry("snes", "Super Nintendo (SNES)", false, false, false, "4:3", 1, consoleFilters);
        addEntry("gb", "Game Boy", false, true, false, "10:9", 1, handheldFilters);
        addEntry("gbc", "Game Boy Color", false, true, false, "10:9", 1, handheldFilters);
        addEntry("gba", "Game Boy Advance", false, true, false, "3:2", 1, handheldFilters);
        addEntry("sms", "Master System", false, false, false, "4:3", 1, consoleFilters);
        addEntry("gg", "Game Gear", false, true, false, "10:9", 1, handheldFilters);
        addEntry("genesis", "Mega Drive / Genesis", false, false, false, "4:3", 1, consoleFilters);
        addEntry("segacd", "Sega CD", false, false, false, "4:3", 1, consoleFilters);
        addEntry("32x", "Sega 32X", false, false, false, "4:3", 1, consoleFilters);
        addEntry("sg1000", "SG-1000", false, false, false, "4:3", 1, consoleFilters);
        addEntry("pce", "PC Engine", false, false, false, "4:3", 1, consoleFilters);
        addEntry("pcecd", "PC Engine CD", false, false, false, "4:3", 1, consoleFilters);
        addEntry("neogeo", "Neo Geo AES / MVS", false, false, false, "4:3", 1, consoleFilters);
        addEntry("ngp", "Neo Geo Pocket", false, true, false, "20:19", 1, handheldFilters);
        addEntry("ws", "WonderSwan", false, true, false, "14:9", 1, handheldFilters);
        addEntry("wsc", "WonderSwan Color", false, true, false, "14:9", 1, handheldFilters);
        addEntry("msx", "MSX / MSX2", false, false, false, "4:3", 1, consoleFilters);
        addEntry("arcade", "Arcade (MAME)", false, false, false, "4:3", 1, consoleFilters);
        addEntry("fbneo", "Arcade (FBNeo)", false, false, false, "4:3", 1, consoleFilters);
        addEntry("virtualboy", "Virtual Boy", false, true, false, "16:9", 1, handheldFilters);
        addEntry("3do", "3DO", true, false, false, "4:3", 2, allFilters);
        addEntry("jaguar", "Atari Jaguar", true, false, false, "4:3", 1, allFilters);
        addEntry("ps1", "PlayStation 1", true, false, false, "4:3", 4, allFilters);
        addEntry("n64", "Nintendo 64", true, false, false, "4:3", 4, allFilters);
        addEntry("saturn", "Sega Saturn", true, false, true, "4:3", 3, allFilters);
        addEntry("dreamcast", "Dreamcast", true, false, false, "4:3", 4, allFilters);
        addEntry("nds", "Nintendo DS", true, true, false, "4:3 (Dual)", 4, allFilters);
        addEntry("psp", "PlayStation Portable (PSP)", true, true, false, "16:9", 4, allFilters);
        addEntry("3ds", "Nintendo 3DS", true, true, true, "5:3 / 4:3", 3, allFilters);
        addEntry("gamecube", "GameCube", true, false, true, "4:3", 3, allFilters);
        addEntry("wii", "Nintendo Wii", true, false, true, "16:9", 3, allFilters);
        addEntry("ps2", "PlayStation 2", true, false, true, "4:3", 3, allFilters);

        ALIASES.put("fc", "nes");
        ALIASES.put("famicom", "nes");
        ALIASES.put("sfc", "snes");
        ALIASES.put("superfamicom", "snes");
        ALIASES.put("md", "genesis");
        ALIASES.put("megadrive", "genesis");
        ALIASES.put("megacd", "segacd");
        ALIASES.put("sega32x", "32x");
        ALIASES.put("tg16", "pce");
        ALIASES.put("turbografx", "pce");
        ALIASES.put("psx", "ps1");
        ALIASES.put("psone", "ps1");
        ALIASES.put("ds", "nds");
        ALIASES.put("n3ds", "3ds");
        ALIASES.put("gc", "gamecube");
        ALIASES.put("ngpc", "ngp");
        ALIASES.put("a2600", "atari2600");
        ALIASES.put("a5200", "atari5200");
        ALIASES.put("a7800", "atari7800");
        ALIASES.put("mame", "arcade");
        ALIASES.put("fba", "fbneo");
    }

    private GraphicsResolutionRules() {}

    private static void addEntry(String id, String label, boolean is3D, boolean handheld, boolean heavy,
                                 String aspectRatio, int maxMultiplier, List<String> filters) {
        CatalogEntry entry = new CatalogEntry(id, label, is3D, handheld, heavy, aspectRatio, maxMultiplier, filters);
        CATALOG.add(entry);
        CATALOG_MAP.put(id, entry);
    }

    public static List<CatalogEntry> catalog() {
        return Collections.unmodifiableList(CATALOG);
    }

    public static String canonicalSystemId(String raw) {
        String lower = raw == null ? "" : raw.trim().toLowerCase(Locale.ROOT);
        if (lower.isEmpty()) return "snes";
        String mapped = ALIASES.get(lower);
        return mapped != null ? mapped : lower;
    }

    public static String detectHardwareTier(long totalRamBytes, int cpuCores) {
        double ramGb = totalRamBytes / (1024.0 * 1024.0 * 1024.0);
        if (ramGb >= 5.5 && cpuCores >= 6) return TIER_HIGH;
        if (ramGb >= 3.5 && cpuCores >= 4) return TIER_MEDIUM;
        return TIER_LOW;
    }

    public static ResolvedConfig resolve(Settings settings, String systemId, String hardwareTier) {
        Settings s = settings == null ? new Settings() : settings;
        String canonical = canonicalSystemId(systemId);
        CatalogEntry entry = CATALOG_MAP.get(canonical);
        if (entry == null) {
            entry = new CatalogEntry(canonical, canonical.toUpperCase(Locale.ROOT), false, false, false, "4:3", 1,
                Arrays.asList(FILTER_NONE, FILTER_CRT_SCANLINES, FILTER_SHARP_BILINEAR, FILTER_EDGE_UPSCALE_2X, FILTER_CAS_SHARPEN, FILTER_BILINEAR_SUBTLE));
        }
        String tier = hardwareTier == null || hardwareTier.isEmpty() ? TIER_MEDIUM : hardwareTier;
        SystemOverride ov = s.systems.get(canonical);
        String effProfile = (ov != null && ov.profile != null && !ov.profile.isEmpty()) ? ov.profile : s.profile;

        int multiplier = 1;
        String scaleMode = SCALE_ORIGINAL;
        String filter = FILTER_NONE;

        if (PROFILE_ORIGINAL.equals(effProfile)) {
            multiplier = 1;
            scaleMode = SCALE_ORIGINAL;
            filter = FILTER_NONE;
        } else if (PROFILE_AUTOMATIC.equals(effProfile)) {
            if (entry.is3D) {
                if (TIER_LOW.equals(tier)) multiplier = 1;
                else if (TIER_MEDIUM.equals(tier)) multiplier = entry.heavy ? 1 : Math.min(entry.maxMultiplier, 2);
                else multiplier = entry.heavy ? Math.min(entry.maxMultiplier, 2) : Math.min(entry.maxMultiplier, 3);
                scaleMode = SCALE_ORIGINAL;
            } else {
                multiplier = 1;
                scaleMode = SCALE_INTEGER;
            }
            filter = FILTER_NONE;
        } else if (PROFILE_ENHANCED.equals(effProfile)) {
            if (entry.is3D) {
                multiplier = entry.heavy ? Math.min(entry.maxMultiplier, 2) : Math.min(entry.maxMultiplier, 3);
                scaleMode = SCALE_ORIGINAL;
                filter = FILTER_NONE;
            } else {
                multiplier = 1;
                scaleMode = SCALE_INTEGER;
                filter = entry.handheld ? FILTER_LCD_GRID : FILTER_CRT_SCANLINES;
            }
        } else {
            int rawMult = ov != null ? ov.multiplier : s.globalMultiplier;
            multiplier = entry.is3D ? Math.max(1, Math.min(entry.maxMultiplier, rawMult)) : 1;
            scaleMode = normalizeScaleMode(ov != null ? ov.scaleMode : s.globalScaleMode);
            filter = normalizeFilter(ov != null ? ov.videoFilter : s.globalVideoFilter);
            if (!entry.supportedFilters.contains(filter)) {
                filter = FILTER_NONE;
            }
        }

        return new ResolvedConfig(
            effProfile,
            canonical,
            entry.is3D,
            entry.aspectRatio,
            !SCALE_STRETCH.equals(scaleMode),
            multiplier,
            scaleMode,
            filter,
            buildCoreVariables(canonical, multiplier),
            tier
        );
    }

    public static Map<String, String> buildCoreVariables(String systemId, int multiplier) {
        int m = Math.max(1, Math.min(4, multiplier));
        Map<String, String> vars = new LinkedHashMap<>();
        switch (systemId) {
            case "psp":
                vars.put("ppsspp_internal_resolution", (480 * m) + "x" + (272 * m));
                break;
            case "3ds":
                vars.put("citra_resolution_factor", m + "x Native");
                vars.put("citra2018_resolution_factor", m + "x Native");
                break;
            case "nds":
                vars.put("melonds_opengl_resolution", m + "x native (" + (256 * m) + "x" + (192 * m) + ")");
                vars.put("desmume_internal_resolution", (256 * m) + "x" + (192 * m));
                break;
            case "ps1":
                vars.put("beetle_psx_hw_internal_resolution", m + "x");
                vars.put("swanstation_GPU_ResolutionScale", m + "x");
                vars.put("pcsx_rearmed_neon_enhancement_enable", m >= 2 ? "enabled" : "disabled");
                break;
            case "n64":
                vars.put("mupen64plus-43screensize", (320 * m) + "x" + (240 * m));
                vars.put("parallel-n64-screensize", (320 * m) + "x" + (240 * m));
                break;
            case "dreamcast":
                vars.put("reicast_internal_resolution", (640 * m) + "x" + (480 * m));
                vars.put("flycast_internal_resolution", (640 * m) + "x" + (480 * m));
                break;
            case "saturn":
                vars.put("yabasanshiro_resolution_mode", m == 1 ? "original" : (m + "x"));
                vars.put("kronos_resolution_mode", m == 1 ? "original" : (m + "x"));
                break;
            case "gamecube":
            case "wii":
                vars.put("dolphin_efb_scale", m + "x (" + (640 * m) + "x" + (528 * m) + ")");
                break;
            default:
                break;
        }
        return vars;
    }

    public static String normalizeScaleMode(String raw) {
        if (SCALE_INTEGER.equals(raw) || SCALE_STRETCH.equals(raw)) return raw;
        return SCALE_ORIGINAL;
    }

    public static String normalizeFilter(String raw) {
        if (FILTER_CRT_SCANLINES.equals(raw) || FILTER_LCD_GRID.equals(raw) || FILTER_BILINEAR_SUBTLE.equals(raw)
                || FILTER_CAS_SHARPEN.equals(raw) || FILTER_SHARP_BILINEAR.equals(raw) || FILTER_EDGE_UPSCALE_2X.equals(raw)) {
            return raw;
        }
        return FILTER_NONE;
    }
}

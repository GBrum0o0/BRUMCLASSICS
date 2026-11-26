package com.brumclassics.mobile.emulation;

import android.app.ActivityManager;
import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.util.Iterator;
import java.util.List;
import java.util.Map;

public final class GraphicsResolutionPack {
    public static final String PROFILE_ORIGINAL = GraphicsResolutionRules.PROFILE_ORIGINAL;
    public static final String PROFILE_AUTOMATIC = GraphicsResolutionRules.PROFILE_AUTOMATIC;
    public static final String PROFILE_ENHANCED = GraphicsResolutionRules.PROFILE_ENHANCED;
    public static final String PROFILE_CUSTOM = GraphicsResolutionRules.PROFILE_CUSTOM;

    private static final String PREFS_NAME = "brum_graphics_pack_v1";
    private static final String PREFS_KEY = "settings_json";

    public static final class CatalogEntry {
        public final String id;
        public final String label;
        public final boolean is3D;
        public final String aspectRatio;
        public final int maxMultiplier;
        CatalogEntry(GraphicsResolutionRules.CatalogEntry e) {
            this.id = e.id; this.label = e.label; this.is3D = e.is3D;
            this.aspectRatio = e.aspectRatio; this.maxMultiplier = e.maxMultiplier;
        }
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

        ResolvedConfig(GraphicsResolutionRules.ResolvedConfig src) {
            this.profile = src.profile;
            this.systemId = src.systemId;
            this.is3D = src.is3D;
            this.aspectRatio = src.aspectRatio;
            this.preserveAspectRatio = src.preserveAspectRatio;
            this.internalMultiplier = src.internalMultiplier;
            this.scaleMode = src.scaleMode;
            this.integerScalingEnabled = src.integerScalingEnabled;
            this.videoFilterMode = src.videoFilterMode;
            this.coreVariables = src.coreVariables;
            this.hardwareTier = src.hardwareTier;
        }
    }

    private GraphicsResolutionPack() {}

    public static List<GraphicsResolutionRules.CatalogEntry> catalog() {
        return GraphicsResolutionRules.catalog();
    }

    public static String detectHardwareTier(Context context) {
        long totalRam = 4L * 1024L * 1024L * 1024L;
        if (context != null) {
            try {
                ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
                if (am != null) {
                    ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
                    am.getMemoryInfo(mi);
                    if (mi.totalMem > 0) totalRam = mi.totalMem;
                }
            } catch (Throwable ignored) {}
        }
        return GraphicsResolutionRules.detectHardwareTier(totalRam, Math.max(1, Runtime.getRuntime().availableProcessors()));
    }

    public static String serializeSettings(GraphicsResolutionRules.Settings s) throws Exception {
        JSONObject root = new JSONObject();
        root.put("profile", s.profile);
        root.put("globalMultiplier", s.globalMultiplier);
        root.put("globalScaleMode", s.globalScaleMode);
        root.put("globalVideoFilter", s.globalVideoFilter);
        JSONObject sysObj = new JSONObject();
        for (Map.Entry<String, GraphicsResolutionRules.SystemOverride> e : s.systems.entrySet()) {
            GraphicsResolutionRules.SystemOverride ov = e.getValue();
            if (ov == null) continue;
            JSONObject item = new JSONObject();
            if (ov.profile != null) item.put("profile", ov.profile);
            item.put("multiplier", ov.multiplier);
            item.put("scaleMode", ov.scaleMode);
            item.put("videoFilter", ov.videoFilter);
            sysObj.put(e.getKey(), item);
        }
        root.put("systems", sysObj);
        return root.toString();
    }

    public static GraphicsResolutionRules.Settings deserializeSettings(String raw) {
        GraphicsResolutionRules.Settings s = new GraphicsResolutionRules.Settings();
        if (raw == null || raw.trim().isEmpty()) return s;
        try {
            JSONObject root = new JSONObject(raw);
            String profile = root.optString("profile", PROFILE_AUTOMATIC);
            if (PROFILE_ORIGINAL.equals(profile) || PROFILE_AUTOMATIC.equals(profile)
                    || PROFILE_ENHANCED.equals(profile) || PROFILE_CUSTOM.equals(profile)) {
                s.profile = profile;
            }
            s.globalMultiplier = Math.max(1, Math.min(4, root.optInt("globalMultiplier", 2)));
            s.globalScaleMode = GraphicsResolutionRules.normalizeScaleMode(root.optString("globalScaleMode", GraphicsResolutionRules.SCALE_ORIGINAL));
            s.globalVideoFilter = GraphicsResolutionRules.normalizeFilter(root.optString("globalVideoFilter", GraphicsResolutionRules.FILTER_NONE));
            JSONObject sysObj = root.optJSONObject("systems");
            if (sysObj != null) {
                Iterator<String> keys = sysObj.keys();
                while (keys.hasNext()) {
                    String k = GraphicsResolutionRules.canonicalSystemId(keys.next());
                    JSONObject item = sysObj.optJSONObject(k);
                    if (item == null) continue;
                    GraphicsResolutionRules.SystemOverride ov = new GraphicsResolutionRules.SystemOverride();
                    String ovProf = item.optString("profile", "");
                    ov.profile = ovProf.isEmpty() ? null : ovProf;
                    ov.multiplier = Math.max(1, Math.min(4, item.optInt("multiplier", 1)));
                    ov.scaleMode = GraphicsResolutionRules.normalizeScaleMode(item.optString("scaleMode", GraphicsResolutionRules.SCALE_ORIGINAL));
                    ov.videoFilter = GraphicsResolutionRules.normalizeFilter(item.optString("videoFilter", GraphicsResolutionRules.FILTER_NONE));
                    s.systems.put(k, ov);
                }
            }
        } catch (Exception ignored) {}
        return s;
    }

    public static GraphicsResolutionRules.Settings load(Context context) {
        SharedPreferences prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return deserializeSettings(prefs.getString(PREFS_KEY, ""));
    }

    public static void save(Context context, GraphicsResolutionRules.Settings settings) {
        try {
            SharedPreferences prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            prefs.edit().putString(PREFS_KEY, serializeSettings(settings)).apply();
        } catch (Exception ignored) {}
    }

    public static GraphicsResolutionRules.Settings reset(Context context, String systemId) {
        GraphicsResolutionRules.Settings current = load(context);
        if (systemId != null && !systemId.trim().isEmpty()) {
            current.systems.remove(GraphicsResolutionRules.canonicalSystemId(systemId));
            save(context, current);
            return current;
        }
        GraphicsResolutionRules.Settings fresh = new GraphicsResolutionRules.Settings();
        save(context, fresh);
        return fresh;
    }

    public static ResolvedConfig resolveForDevice(Context context, String systemId) {
        return new ResolvedConfig(GraphicsResolutionRules.resolve(load(context), systemId, detectHardwareTier(context)));
    }
}

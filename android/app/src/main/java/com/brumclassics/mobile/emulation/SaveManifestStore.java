package com.brumclassics.mobile.emulation;

import android.content.Context;
import android.provider.Settings;
import android.util.AtomicFile;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Locale;

final class SaveManifestStore {
    private SaveManifestStore() {}

    static void update(Context context, IntegratedEmulatorLaunch launch) throws Exception {
        if (!launch.saveFile.isFile() || launch.saveFile.length() <= 0) return;
        String payloadHash = sha256(launch.saveFile);
        JSONObject previous = read(launch);
        if (previous != null && payloadHash.equals(previous.optString("payloadSHA256")) &&
            previous.optLong("sizeBytes") == launch.saveFile.length()) return;

        long generation = previous == null ? 1 : Math.max(1, previous.optLong("generation") + 1);
        String deviceId = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ANDROID_ID);
        if (deviceId == null || deviceId.trim().isEmpty()) deviceId = "android-local";
        JSONObject manifest = new JSONObject();
        manifest.put("schemaVersion", 1);
        manifest.put("canonicalGameID", launch.canonicalGameId);
        manifest.put("systemID", launch.systemId);
        manifest.put("coreID", launch.coreId);
        manifest.put("coreVersion", launch.coreVersion);
        manifest.put("slot", "battery");
        manifest.put("generation", generation);
        manifest.put("payloadSHA256", payloadHash);
        manifest.put("sizeBytes", launch.saveFile.length());
        manifest.put("updatedAt", Instant.now().toString());
        manifest.put("deviceID", deviceId);
        manifest.put("formatVersion", 1);

        AtomicFile target = new AtomicFile(launch.manifestFile);
        FileOutputStream output = null;
        try {
            output = target.startWrite();
            output.write(manifest.toString().getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
            target.finishWrite(output);
        } catch (Exception error) {
            if (output != null) target.failWrite(output);
            throw error;
        }
    }

    private static JSONObject read(IntegratedEmulatorLaunch launch) {
        if (!launch.manifestFile.isFile() || launch.manifestFile.length() > 64 * 1024) return null;
        try (FileInputStream input = new FileInputStream(launch.manifestFile); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int read;
            while ((read = input.read(buffer)) >= 0) output.write(buffer, 0, read);
            return new JSONObject(new String(output.toByteArray(), StandardCharsets.UTF_8));
        } catch (Exception ignored) { return null; }
    }

    private static String sha256(java.io.File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[64 * 1024]; int read;
            while ((read = input.read(buffer)) >= 0) if (read > 0) digest.update(buffer, 0, read);
        }
        StringBuilder result = new StringBuilder(64);
        for (byte value : digest.digest()) result.append(String.format(Locale.ROOT, "%02x", value & 0xff));
        return result.toString();
    }
}

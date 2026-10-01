package com.brumclassics.mobile.emulation;

import android.util.AtomicFile;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;

final class QuickStateStore {
    private QuickStateStore() {}

    static void update(IntegratedEmulatorLaunch launch, int slot, File state) throws Exception {
        JSONObject metadata = new JSONObject();
        metadata.put("schemaVersion", 1);
        metadata.put("canonicalGameID", launch.canonicalGameId);
        metadata.put("systemID", launch.systemId);
        metadata.put("coreID", launch.coreId);
        metadata.put("coreVersion", launch.coreVersion);
        metadata.put("slot", slot);
        metadata.put("sizeBytes", state.length());
        metadata.put("updatedAt", Instant.now().toString());

        AtomicFile target = new AtomicFile(new File(state.getAbsolutePath() + ".json"));
        FileOutputStream output = null;
        try {
            output = target.startWrite();
            output.write(metadata.toString().getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
            target.finishWrite(output);
        } catch (Exception error) {
            if (output != null) target.failWrite(output);
            throw error;
        }
    }

    static boolean isCompatible(IntegratedEmulatorLaunch launch, int slot, File state) {
        File metadataFile = new File(state.getAbsolutePath() + ".json");
        if (!state.isFile() || !metadataFile.isFile() || metadataFile.length() > 64 * 1024) return false;
        try (FileInputStream input = new FileInputStream(metadataFile); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096]; int read;
            while ((read = input.read(buffer)) >= 0) output.write(buffer, 0, read);
            JSONObject metadata = new JSONObject(new String(output.toByteArray(), StandardCharsets.UTF_8));
            return metadata.optInt("schemaVersion") == 1 && metadata.optInt("slot") == slot &&
                launch.canonicalGameId.equals(metadata.optString("canonicalGameID")) &&
                launch.systemId.equals(metadata.optString("systemID")) && launch.coreId.equals(metadata.optString("coreID")) &&
                launch.coreVersion.equals(metadata.optString("coreVersion")) && metadata.optLong("sizeBytes") == state.length();
        } catch (Exception ignored) { return false; }
    }
}

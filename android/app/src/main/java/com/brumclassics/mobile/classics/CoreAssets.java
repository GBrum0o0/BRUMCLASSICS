package com.brumclassics.mobile.classics;

import android.content.res.AssetManager;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

/** Installs only packaged core resources; the memory stick lives elsewhere. */
final class CoreAssets {
    private CoreAssets() {}

    static void installPpsspp(AssetManager assets, File systemDirectory) throws Exception {
        copyTree(assets, "system/PPSSPP", new File(systemDirectory, "PPSSPP"));
        if (!new File(systemDirectory, "PPSSPP/ppge_atlas.zim").isFile() ||
            !new File(systemDirectory, "PPSSPP/flash0/font/ltn0.pgf").isFile()) {
            throw new IllegalStateException("Os recursos do PPSSPP estão ausentes. Reinstale o aplicativo completo.");
        }
    }

    private static void copyTree(AssetManager assets, String source, File target) throws Exception {
        String[] children = assets.list(source);
        if (children != null && children.length > 0) {
            if (!target.isDirectory() && !target.mkdirs()) throw new IllegalStateException("Não foi possível preparar os recursos do PPSSPP.");
            for (String child : children) copyTree(assets, source + "/" + child, new File(target, child));
            return;
        }
        File temporary = new File(target.getParentFile(), target.getName() + ".install.tmp");
        try {
            try (InputStream input = assets.open(source); FileOutputStream output = new FileOutputStream(temporary)) {
                byte[] buffer = new byte[64 * 1024]; int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.getFD().sync();
            }
            Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        } finally { temporary.delete(); }
    }
}

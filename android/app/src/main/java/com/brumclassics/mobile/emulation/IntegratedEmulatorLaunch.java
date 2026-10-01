package com.brumclassics.mobile.emulation;

import java.io.File;

public final class IntegratedEmulatorLaunch {
    public final String gameId;
    public final String title;
    public final String canonicalGameId;
    public final String systemId;
    public final String contentSha256;
    public final String coreId;
    public final File romFile;
    public final File saveFile;
    public final File manifestFile;
    public final File systemDirectory;

    public IntegratedEmulatorLaunch(String gameId, String title, String canonicalGameId, String systemId,
                                    String contentSha256, String coreId, File romFile, File saveFile,
                                    File manifestFile, File systemDirectory) {
        this.gameId = gameId;
        this.title = title;
        this.canonicalGameId = canonicalGameId;
        this.systemId = systemId;
        this.contentSha256 = contentSha256;
        this.coreId = coreId;
        this.romFile = romFile;
        this.saveFile = saveFile;
        this.manifestFile = manifestFile;
        this.systemDirectory = systemDirectory;
    }
}

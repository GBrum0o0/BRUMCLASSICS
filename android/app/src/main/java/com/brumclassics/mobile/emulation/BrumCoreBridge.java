package com.brumclassics.mobile.emulation;

public final class BrumCoreBridge implements AutoCloseable {
    static {
        System.loadLibrary("brumcore");
    }

    private long handle;

    public BrumCoreBridge(String corePath, IntegratedEmulatorLaunch launch) {
        handle = nativeCreate(corePath, launch.romFile.getAbsolutePath(), launch.systemDirectory.getAbsolutePath(),
            launch.saveFile.getParentFile().getAbsolutePath(), launch.saveFile.getAbsolutePath());
        if (handle == 0) throw new IllegalStateException("O BRUM Core não pôde iniciar esta ROM.");
    }

    public void runFrames(int count, int inputMask) { ensureOpen(); nativeRunFrames(handle, Math.max(1, count), inputMask); }
    public long copyFrame(int[] target) { ensureOpen(); return nativeCopyFrame(handle, target); }
    public int drainAudio(short[] target) { ensureOpen(); return nativeDrainAudio(handle, target); }
    public int sampleRate() { ensureOpen(); return nativeSampleRate(handle); }
    public void persist() { if (handle != 0) nativePersist(handle); }
    public boolean saveState(String path) { ensureOpen(); return nativeSaveState(handle, path); }
    public boolean loadState(String path) { ensureOpen(); return nativeLoadState(handle, path); }

    @Override public void close() {
        if (handle == 0) return;
        nativeDestroy(handle);
        handle = 0;
    }

    private void ensureOpen() { if (handle == 0) throw new IllegalStateException("A sessão de emulação já foi encerrada."); }

    private static native long nativeCreate(String corePath, String romPath, String systemDirectory, String saveDirectory, String savePath);
    private static native void nativeRunFrames(long handle, int count, int inputMask);
    private static native long nativeCopyFrame(long handle, int[] target);
    private static native int nativeDrainAudio(long handle, short[] target);
    private static native int nativeSampleRate(long handle);
    private static native void nativePersist(long handle);
    private static native boolean nativeSaveState(long handle, String path);
    private static native boolean nativeLoadState(long handle, String path);
    private static native void nativeDestroy(long handle);
}

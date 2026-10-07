package com.brumclassics.mobile.emulation;

public final class BrumCoreBridge implements AutoCloseable {
    static {
        System.loadLibrary("brumcore");
    }

    private long handle;

    public BrumCoreBridge(String corePath, String romPath, IntegratedEmulatorLaunch launch) {
        handle = nativeCreate(corePath, romPath, launch.systemDirectory.getAbsolutePath(),
            launch.saveFile.getParentFile().getAbsolutePath(), launch.saveFile.getAbsolutePath());
        if (handle == 0) throw new IllegalStateException("O BRUM Core não pôde iniciar esta ROM.");
    }

    public void runFrames(int count, int inputMask) { ensureOpen(); nativeRunFrames(handle, Math.max(1, count), inputMask); }
    public void setPointer(float normalizedX, float normalizedY, boolean pressed) {
        ensureOpen();
        int x = Math.round(Math.max(-1f, Math.min(1f, normalizedX)) * 32767f);
        int y = Math.round(Math.max(-1f, Math.min(1f, normalizedY)) * 32767f);
        nativeSetPointer(handle, x, y, pressed);
    }
    public long copyFrame(int[] target) { ensureOpen(); return nativeCopyFrame(handle, target); }
    public int drainAudio(short[] target) { ensureOpen(); return nativeDrainAudio(handle, target); }
    public void clearAudio() { if (handle != 0) nativeClearAudio(handle); }
    public int sampleRate() { ensureOpen(); return nativeSampleRate(handle); }
    public double frameRate() { ensureOpen(); return nativeFrameRate(handle); }
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
    private static native void nativeSetPointer(long handle, int x, int y, boolean pressed);
    private static native long nativeCopyFrame(long handle, int[] target);
    private static native int nativeDrainAudio(long handle, short[] target);
    private static native void nativeClearAudio(long handle);
    private static native int nativeSampleRate(long handle);
    private static native double nativeFrameRate(long handle);
    private static native void nativePersist(long handle);
    private static native boolean nativeSaveState(long handle, String path);
    private static native boolean nativeLoadState(long handle, String path);
    private static native void nativeDestroy(long handle);
}

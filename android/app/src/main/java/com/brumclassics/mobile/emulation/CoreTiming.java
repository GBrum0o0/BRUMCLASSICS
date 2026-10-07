package com.brumclassics.mobile.emulation;

final class CoreTiming {
    private CoreTiming() {}

    static long frameDurationNanos(double framesPerSecond) {
        double rate = Double.isFinite(framesPerSecond) && framesPerSecond >= 1.0 && framesPerSecond <= 1000.0
            ? framesPerSecond : 60.0;
        return Math.max(1L, Math.round(1_000_000_000.0 / rate));
    }
}

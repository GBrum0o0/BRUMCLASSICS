package com.brumclassics.mobile.emulation;

public final class CoreTimingTest {
    public static void main(String[] args) {
        followsCoreCadenceInsteadOfFixedSixty();
        invalidCadenceFallsBackSafely();
        System.out.println("CoreTimingTest: OK");
    }

    private static void followsCoreCadenceInsteadOfFixedSixty() {
        assertEquals(16_666_667L, CoreTiming.frameDurationNanos(60.0));
        assertEquals(13_333_333L, CoreTiming.frameDurationNanos(75.0));
        assertEquals(8_333_333L, CoreTiming.frameDurationNanos(120.0));
    }

    private static void invalidCadenceFallsBackSafely() {
        assertEquals(16_666_667L, CoreTiming.frameDurationNanos(Double.NaN));
        assertEquals(16_666_667L, CoreTiming.frameDurationNanos(0.0));
    }

    private static void assertEquals(long expected, long actual) {
        if (expected != actual) throw new AssertionError("Esperado " + expected + ", recebido " + actual);
    }
}

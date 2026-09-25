package com.brumclassics.mobile.sync;

public final class MobileSyncStateTest {
    public static void main(String[] args) {
        MobileSyncState.Summary value = MobileSyncState.summarize("offline", true, 42, 3, 1_000L);
        if (!"Dados salvos no aparelho".equals(value.title)) throw new AssertionError("Estado offline ambíguo.");
        if (!value.detail.contains("3 alteração")) throw new AssertionError("Fila pendente não exibida.");
        if (!"Reconexão automática ativa".equals(value.action)) throw new AssertionError("Reconexão não informada.");
        MobileSyncState.Summary connected = MobileSyncState.summarize("connected", true, 12, 0, System.currentTimeMillis());
        if (!"Tudo sincronizado".equals(connected.title) || !connected.healthy) throw new AssertionError("Estado conectado incorreto.");
        System.out.println("MobileSyncStateTest: OK");
    }
}

package com.brumclassics.mobile.model;

public final class PerformanceLiveStateTest {
    public static void main(String[] args) {
        PerformanceLiveState state = new PerformanceLiveState();
        if (state.isLive("jogo", 1)) throw new AssertionError("Sem coleta não pode estar ao vivo");
        state.accept(true, "jogo", 100);
        if (!state.isLive("jogo", 101)) throw new AssertionError("Primeira coleta deve mostrar o painel");
        if (state.isLive("outro", 101)) throw new AssertionError("Coleta de outro jogo recusada");
        if (state.isLive("jogo", 15100)) throw new AssertionError("Coleta expirada recusada");
        state.accept(true, "jogo", 20000); state.disconnect();
        if (state.isLive("jogo", 20001)) throw new AssertionError("Offline não mostra dados antigos ao vivo");
        state.accept(true, "jogo", 30000); state.accept(false, "", 30001);
        if (state.isLive("jogo", 30002)) throw new AssertionError("Fim da sessão deve ocultar o painel");
        System.out.println("PerformanceLiveStateTest: OK");
    }
}

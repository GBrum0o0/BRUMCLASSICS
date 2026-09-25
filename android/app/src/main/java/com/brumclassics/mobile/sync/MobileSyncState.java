package com.brumclassics.mobile.sync;

import java.util.Locale;
import java.util.concurrent.TimeUnit;

public final class MobileSyncState {
    private MobileSyncState() {}

    public static final class Summary {
        public final String title;
        public final String detail;
        public final String action;
        public final boolean healthy;
        Summary(String title, String detail, String action, boolean healthy) {
            this.title = title; this.detail = detail; this.action = action; this.healthy = healthy;
        }
    }

    public static Summary summarize(String state, boolean paired, int games, int pending, long lastSuccess) {
        String age = relativeTime(lastSuccess, System.currentTimeMillis());
        if (!paired) return new Summary(games > 0 ? "Dados salvos no aparelho" : "Computador não pareado",
            games > 0 ? games + " jogos disponíveis offline · última sincronização " + age : "Leia o QR Code do launcher para trazer sua biblioteca.",
            "Parear com o computador", games > 0);
        if ("connected".equals(state) || "caching".equals(state)) return new Summary(pending == 0 ? "Tudo sincronizado" : pending + " alteração(ões) aguardando o computador",
            games + " jogos salvos no aparelho · última sincronização " + age,
            pending == 0 ? "Nenhuma ação necessária" : "O envio será automático", pending == 0);
        if ("connecting".equals(state) || "syncing".equals(state)) return new Summary("Sincronizando com o computador",
            "Seus " + games + " jogos continuam disponíveis enquanto isso.", "Aguarde o teste automático", true);
        return new Summary("Dados salvos no aparelho", pending + " alteração(ões) pendente(s) · última sincronização " + age,
            "Reconexão automática ativa", games > 0);
    }

    public static String relativeTime(long timestamp, long now) {
        if (timestamp <= 0) return "ainda não concluída";
        long minutes = Math.max(0, TimeUnit.MILLISECONDS.toMinutes(now - timestamp));
        if (minutes < 1) return "agora";
        if (minutes < 60) return String.format(Locale.ROOT, "há %d min", minutes);
        long hours = minutes / 60;
        if (hours < 24) return String.format(Locale.ROOT, "há %d h", hours);
        return String.format(Locale.ROOT, "há %d dia(s)", hours / 24);
    }
}

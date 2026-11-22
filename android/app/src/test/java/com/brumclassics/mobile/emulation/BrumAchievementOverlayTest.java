package com.brumclassics.mobile.emulation;

public final class BrumAchievementOverlayTest {
    public static void main(String[] args) {
        BrumAchievementModel.clearSeenEventsForTest();

        BrumAchievementModel.Payload valid = new BrumAchievementModel.Payload(
            "ra:123:456",
            "456",
            " Primeira Vitória ",
            " Vença sua primeira batalha. ",
            10,
            "https://media.retroachievements.org/Badge/00456.png"
        );
        if (!"ra:123:456".equals(valid.eventId)) throw new AssertionError("eventId inválido");
        if (!"Primeira Vitória".equals(valid.title)) throw new AssertionError("Título não foi normalizado");
        if (valid.points != 10) throw new AssertionError("Pontos incorretos");
        if (!"https://media.retroachievements.org/Badge/00456.png".equals(valid.badgeUrl)) {
            throw new AssertionError("URL oficial de badge rejeitada");
        }

        BrumAchievementModel.Payload untrusted = new BrumAchievementModel.Payload(
            "", "789", "", "Desc", -5, "http://evil.example/Badge/1.png"
        );
        if (!"id:789".equals(untrusted.eventId)) throw new AssertionError("Fallback de eventId incorreto");
        if (!"Conquista desbloqueada".equals(untrusted.title)) throw new AssertionError("Título fallback incorreto");
        if (untrusted.points != 0) throw new AssertionError("Pontos negativos não normalizados");
        if (!"".equals(untrusted.badgeUrl)) throw new AssertionError("URL não HTTPS/não oficial aceita");
        if (!"".equals(BrumAchievementModel.sanitizeBadgeUrl("https://evil.retroachievements.org/other/1.png"))) {
            throw new AssertionError("Host/caminho fora de /Badge/ aceito");
        }

        if (!BrumAchievementModel.markEventIfNew("ra:123:456")) throw new AssertionError("Primeiro evento deveria ser aceito");
        if (BrumAchievementModel.markEventIfNew("RA:123:456")) throw new AssertionError("Evento duplicado não foi bloqueado");
        if (!BrumAchievementModel.markEventIfNew("ra:123:457")) throw new AssertionError("Evento distinto foi bloqueado");

        String banner3dsMissing = BrumAchievementModel.formatStatusBanner("Azahar", "3ds", 0, "", true);
        if (!banner3dsMissing.contains("falta aes_keys.txt") || !banner3dsMissing.contains("RA indisponível no 3DS")) {
            throw new AssertionError("Banner 3DS sem chaves incorreto: " + banner3dsMissing);
        }
        String bannerRaActive = BrumAchievementModel.formatStatusBanner("mGBA", "gba", 515, "active", false);
        if (!bannerRaActive.contains("RA ATIVO")) {
            throw new AssertionError("Banner RA ativo incorreto: " + bannerRaActive);
        }

        System.out.println("BrumAchievementOverlayTest: OK");
    }
}

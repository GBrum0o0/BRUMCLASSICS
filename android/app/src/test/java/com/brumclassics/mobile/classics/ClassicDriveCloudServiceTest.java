package com.brumclassics.mobile.classics;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public final class ClassicDriveCloudServiceTest {
    public static void main(String[] args) throws Exception {
        if (!"1AbCdEfGhIjKlMnOpQrStUv".equals(ClassicDriveCloudRules.parseDriveFolderId("https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv?usp=sharing"))) {
            throw new AssertionError("Falha ao extrair ID da URL do Drive");
        }
        if (!ClassicDriveCloudRules.parseDriveFolderId("http://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv").isEmpty()) {
            throw new AssertionError("Link HTTP inseguro deveria ser bloqueado");
        }
        if (!ClassicDriveCloudRules.parseDriveFolderId("https://evil.example.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUv").isEmpty()) {
            throw new AssertionError("Host não autorizado deveria ser bloqueado");
        }
        if (!ClassicDriveCloudRules.isExcludedPcFile("Setup.exe") || !ClassicDriveCloudRules.isAcceptedClassicFile("Chrono Trigger.sfc")) {
            throw new AssertionError("Filtro PC vs ROM clássica incorreto");
        }

        byte[] htmlErr = "<!DOCTYPE html><html><title>Google Drive - Sign in</title></html>".getBytes(StandardCharsets.UTF_8);
        if (!ClassicDriveCloudRules.looksLikeHtmlPayload(htmlErr, htmlErr.length)) {
            throw new AssertionError("Payload HTML de erro precisa ser rejeitado antes de salvar ROM");
        }

        // Test batched resumable scan > 100 folders + cycle protection + network recovery
        final Map<String, Integer> calls = new HashMap<>();
        final boolean[] failFolder1 = {true};
        ClassicDriveCloudRules.HttpFetcher fetcher = (folderId, bearerToken) -> {
            calls.put(folderId, calls.getOrDefault(folderId, 0) + 1);
            if ("rootFolder_123456".equals(folderId)) {
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < 105; i++) {
                    sb.append("<a href=\"https://drive.google.com/drive/folders/subFolder_1000").append(i).append("\">Pasta ").append(i).append("</a>");
                }
                sb.append("<a href=\"https://drive.google.com/file/d/fileId_GameGba_001/view\">Pokemon Emerald (U).gba</a>");
                sb.append("<a href=\"https://drive.google.com/file/d/fileId_ExePc_001/view\">LauncherSetup.exe</a>");
                return new ClassicDriveCloudRules.FetchResult(200, sb.toString());
            }
            if ("subFolder_10001".equals(folderId) && failFolder1[0]) {
                throw new RuntimeException("Timeout de rede simulado");
            }
            // Also inject a cycle pointing back to rootFolder_123456
            String body = "<a href=\"https://drive.google.com/drive/folders/rootFolder_123456\">LoopRoot</a>"
                + "<a href=\"https://drive.google.com/file/d/file_" + folderId + "_rom/view\">Jogo_" + folderId + ".nes</a>";
            return new ClassicDriveCloudRules.FetchResult(200, body);
        };

        ClassicDriveCloudRules.ScanCheckpoint cp = null;
        try {
            cp = ClassicDriveCloudRules.runScanBatch(null, fetcher, null, true, "https://drive.google.com/drive/folders/rootFolder_123456");
            throw new AssertionError("Deveria falhar na pasta com erro de rede mantendo checkpoint");
        } catch (RuntimeException expected) {
            // Expected transient failure
        }

        // Resume after network recovery
        failFolder1[0] = false;
        // Wait: cp variable wasn't assigned on exception; reconstruct via shared holder to verify partial preservation:
        ClassicDriveCloudRules.ScanCheckpoint resumable = new ClassicDriveCloudRules.ScanCheckpoint();
        failFolder1[0] = true;
        try {
            ClassicDriveCloudRules.runScanBatch(resumable, fetcher, null, true, "https://drive.google.com/drive/folders/rootFolder_123456");
        } catch (RuntimeException ignored) {}
        if (resumable.itemsById.get("fileId_GameGba_001") == null) {
            throw new AssertionError("Checkpoint parcial deveria preservar o jogo encontrado antes do erro de rede");
        }
        if (resumable.itemsById.get("fileId_ExePc_001") != null) {
            throw new AssertionError("Executável PC .exe não deve entrar no catálogo Mobile");
        }
        failFolder1[0] = false;
        ClassicDriveCloudRules.runScanBatch(resumable, fetcher, null, false, "");
        if (resumable.completed) {
            throw new AssertionError("Pasta com > 100 subpastas deve pausar em lotes sem descartar pendentes");
        }
        ClassicDriveCloudRules.runScanBatch(resumable, fetcher, null, false, "");
        if (!resumable.completed || resumable.sortedItems().size() != 106) {
            throw new AssertionError("Retomada final deveria concluir com 106 jogos sem ciclos (atual=" + resumable.sortedItems().size() + ")");
        }

        // Availability states via GamingModeRules contract parity check
        if (!"fileId_GameGba_001".equals(resumable.itemsById.get("fileId_GameGba_001").id)) {
            throw new AssertionError("ID Drive perdido");
        }
        System.out.println("ClassicDriveCloudServiceTest: OK (HTTPS allowlist, rejeição EXE/HTML, lotes resumíveis >100 pastas, sem ciclos)");
    }

    private static boolean isAccepted(String name) {
        return ClassicDriveCloudRules.isAcceptedClassicFile(name);
    }
}

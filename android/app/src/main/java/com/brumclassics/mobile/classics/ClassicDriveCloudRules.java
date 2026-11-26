package com.brumclassics.mobile.classics;

import java.io.File;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Pure-JVM Google Drive cloud library parser, batched resumable scanner and availability checks. */
public final class ClassicDriveCloudRules {
    public static final int BATCH_FOLDER_BUDGET = 100;
    public static final int MAX_BATCH_FILES = 5000;
    public static final int MAX_DEPTH = 12;
    public static final int MAX_RESPONSE_BYTES = 8 * 1024 * 1024;

    private static final Set<String> ALLOWED_HOSTS = new HashSet<>(Arrays.asList(
        "drive.google.com", "docs.google.com", "drive.usercontent.google.com"
    ));
    private static final Set<String> BLOCKED_PC_EXTENSIONS = new HashSet<>(Arrays.asList(
        "exe", "msi", "bat", "cmd", "ps1", "vbs", "wsf", "lnk", "reg",
        "dmg", "pkg", "app", "deb", "rpm", "appimage", "sh", "dll", "so"
    ));
    private static final Pattern RAW_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{10,128}$");
    private static final Pattern FOLDER_URL_PATTERN = Pattern.compile("/folders/([A-Za-z0-9_-]{10,128})");
    private static final Pattern QUERY_ID_PATTERN = Pattern.compile("[?&]id=([A-Za-z0-9_-]{10,128})");
    private static final Pattern HTML_FOLDER_LINK = Pattern.compile(
        "href=\"https://drive\\.google\\.com/drive(?:/u/\\d+)?/folders/([A-Za-z0-9_-]{10,128})[^\"]*\"[^>]*>([^<]{1,180})</a>",
        Pattern.CASE_INSENSITIVE
    );
    private static final Pattern HTML_FILE_LINK = Pattern.compile(
        "href=\"https://drive\\.google\\.com/file/d/([A-Za-z0-9_-]{10,128})/[^\"]*\"[^>]*>([^<]{1,220})</a>",
        Pattern.CASE_INSENSITIVE
    );
    private static final Pattern HTML_DATA_ID = Pattern.compile(
        "data-id=\"([A-Za-z0-9_-]{10,128})\"[^>]*?(?:data-target=\"([^\"]*)\")?[^>]*?>[\\s\\S]{0,600}?(?:aria-label|data-tooltip)=\"([^\"]{1,220})\"",
        Pattern.CASE_INSENSITIVE
    );

    public interface HttpFetcher {
        FetchResult fetch(String folderId, String bearerToken) throws Exception;
    }

    public static final class FetchResult {
        public final int statusCode;
        public final String body;

        public FetchResult(int statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body == null ? "" : body;
        }
    }

    public static final class FolderTask {
        public final String id;
        public final String relativePath;
        public final int depth;

        public FolderTask(String id, String relativePath, int depth) {
            this.id = id;
            this.relativePath = relativePath == null ? "" : relativePath;
            this.depth = depth;
        }
    }

    public static final class CloudGameEntry {
        public final String id;
        public final String name;
        public final String title;
        public final String relativePath;
        public final String folderId;
        public final String parentRelativePath;
        public final long sizeBytes;
        public final String systemHint;
        public final String downloadUrl;
        public String downloadedLocalPath = "";
        public long downloadedBytes = 0L;
        public String downloadStatus = "cloud";
        public String downloadError = "";

        public CloudGameEntry(String id, String name, String title, String relativePath, String folderId,
                              String parentRelativePath, long sizeBytes, String systemHint, String downloadUrl) {
            this.id = id;
            this.name = name;
            this.title = title;
            this.relativePath = relativePath;
            this.folderId = folderId;
            this.parentRelativePath = parentRelativePath;
            this.sizeBytes = sizeBytes;
            this.systemHint = systemHint;
            this.downloadUrl = downloadUrl;
        }
    }

    public static final class ParsedFolderPage {
        public final List<FolderTask> subfolders = new ArrayList<>();
        public final List<CloudGameEntry> files = new ArrayList<>();
    }

    public static final class ScanCheckpoint {
        public String rootUrl = "";
        public String rootFolderId = "";
        public final List<FolderTask> pendingFolders = new ArrayList<>();
        public final Set<String> visitedFolderIds = new LinkedHashSet<>();
        public final Set<String> seenFileIds = new LinkedHashSet<>();
        public final Map<String, CloudGameEntry> itemsById = new LinkedHashMap<>();
        public boolean completed = false;
        public int totalFoldersRead = 0;
        public String lastError = "";
        public long updatedAtMs = 0L;

        public List<CloudGameEntry> sortedItems() {
            List<CloudGameEntry> list = new ArrayList<>(itemsById.values());
            Collections.sort(list, Comparator.comparing(item -> item.title.toLowerCase(Locale.ROOT)));
            return list;
        }
    }

    private ClassicDriveCloudRules() {}

    public static boolean isAllowedUrl(String rawUrl) {
        if (rawUrl == null || rawUrl.trim().isEmpty()) return false;
        try {
            URI uri = URI.create(rawUrl.trim());
            if (!"https".equalsIgnoreCase(uri.getScheme())) return false;
            String host = uri.getHost();
            if (host == null || host.isEmpty()) return false;
            String lower = host.toLowerCase(Locale.ROOT);
            return ALLOWED_HOSTS.contains(lower) || lower.endsWith(".googleusercontent.com");
        } catch (Exception ignored) {
            return false;
        }
    }

    public static String parseDriveFolderId(String rawInput) {
        if (rawInput == null) return "";
        String trimmed = rawInput.trim();
        if (RAW_ID_PATTERN.matcher(trimmed).matches()) return trimmed;
        if (!isAllowedUrl(trimmed)) return "";
        Matcher folderMatcher = FOLDER_URL_PATTERN.matcher(trimmed);
        if (folderMatcher.find()) return folderMatcher.group(1);
        Matcher queryMatcher = QUERY_ID_PATTERN.matcher(trimmed);
        if (queryMatcher.find()) return queryMatcher.group(1);
        return "";
    }

    public static boolean isExcludedPcFile(String filename) {
        String ext = ClassicsRules.extension(filename);
        return !ext.isEmpty() && BLOCKED_PC_EXTENSIONS.contains(ext);
    }

    public static boolean isAcceptedClassicFile(String filename) {
        if (filename == null || filename.isEmpty() || filename.contains("/") || filename.contains("\\")) return false;
        if (isExcludedPcFile(filename)) return false;
        return ClassicsRules.accepts(filename);
    }

    public static String directDownloadUrl(String fileId) {
        return "https://drive.usercontent.google.com/download?id=" + fileId + "&export=download&confirm=t";
    }

    public static String detectSystemHint(String relativePath, String filename) {
        String joined = ((relativePath == null ? "" : relativePath) + "/" + (filename == null ? "" : filename)).toLowerCase(Locale.ROOT);
        if (joined.contains("ppsspp") || joined.contains("/psp/") || joined.endsWith(".cso")) return "psp";
        if (joined.contains("/nds/") || joined.endsWith(".nds")) return "nds";
        if (joined.contains("/3ds/") || joined.endsWith(".3ds") || joined.endsWith(".3dsx")) return "3ds";
        if (joined.contains("/gba/") || joined.endsWith(".gba")) return "gba";
        if (joined.contains("/gbc/") || joined.endsWith(".gbc")) return "gbc";
        if (joined.contains("/gb/") || joined.endsWith(".gb")) return "gb";
        if (joined.contains("/snes/") || joined.endsWith(".sfc") || joined.endsWith(".smc")) return "snes";
        if (joined.contains("/nes/") || joined.endsWith(".nes")) return "nes";
        if (joined.contains("/n64/") || joined.endsWith(".z64") || joined.endsWith(".n64")) return "n64";
        if (joined.contains("/ps1/") || joined.contains("/psx/")) return "ps1";
        if (joined.contains("/ps2/") || joined.endsWith(".isz")) return "ps2";
        if (joined.contains("/dreamcast/") || joined.endsWith(".gdi")) return "dreamcast";
        if (joined.contains("/genesis/") || joined.contains("/megadrive/") || joined.endsWith(".md")) return "megadrive";
        return "";
    }

    public static ParsedFolderPage parseFolderHtml(String html, String parentRelativePath, String folderId, int nextDepth) {
        ParsedFolderPage page = new ParsedFolderPage();
        if (html == null || html.isEmpty()) return page;
        Map<String, String> folders = new LinkedHashMap<>();
        Map<String, String> files = new LinkedHashMap<>();

        Matcher mFolder = HTML_FOLDER_LINK.matcher(html);
        while (mFolder.find()) {
            folders.putIfAbsent(mFolder.group(1), unescapeHtml(mFolder.group(2).trim()));
        }
        Matcher mFile = HTML_FILE_LINK.matcher(html);
        while (mFile.find()) {
            files.putIfAbsent(mFile.group(1), unescapeHtml(mFile.group(2).trim()));
        }
        Matcher mData = HTML_DATA_ID.matcher(html);
        while (mData.find()) {
            String id = mData.group(1);
            String target = mData.group(2) == null ? "" : mData.group(2).toLowerCase(Locale.ROOT);
            String name = unescapeHtml(mData.group(3).trim());
            if (name.isEmpty()) continue;
            if ("folder".equals(target) || (!name.contains(".") && !isAcceptedClassicFile(name))) {
                folders.putIfAbsent(id, name);
            } else {
                files.putIfAbsent(id, name);
            }
        }

        String prefix = parentRelativePath == null ? "" : parentRelativePath;
        for (Map.Entry<String, String> entry : folders.entrySet()) {
            String rel = prefix.isEmpty() ? entry.getValue() : prefix + "/" + entry.getValue();
            page.subfolders.add(new FolderTask(entry.getKey(), rel, nextDepth));
        }
        for (Map.Entry<String, String> entry : files.entrySet()) {
            String name = entry.getValue();
            if (!isAcceptedClassicFile(name)) continue;
            String rel = prefix.isEmpty() ? name : prefix + "/" + name;
            page.files.add(new CloudGameEntry(
                entry.getKey(),
                name,
                ClassicsRules.cleanTitle(name),
                rel,
                folderId,
                prefix,
                -1L,
                detectSystemHint(rel, name),
                directDownloadUrl(entry.getKey())
            ));
        }
        return page;
    }

    public static boolean looksLikeHtmlPayload(byte[] headerBytes, int length) {
        if (headerBytes == null || length <= 0) return false;
        String head = new String(headerBytes, 0, Math.min(length, 512), StandardCharsets.UTF_8).trim().toLowerCase(Locale.ROOT);
        return head.startsWith("<!doctype html") || head.startsWith("<html") || head.contains("<title>google drive");
    }

    public static boolean isAvailabilityPlayableLocally(String localPath) {
        if (localPath == null || localPath.trim().isEmpty()) return false;
        File f = new File(localPath);
        return f.isFile() && f.length() > 0;
    }

    public static ScanCheckpoint runScanBatch(ScanCheckpoint checkpoint, HttpFetcher fetcher, String bearerToken,
                                              boolean refresh, String folderUrlInput) throws Exception {
        ScanCheckpoint state = checkpoint == null ? new ScanCheckpoint() : checkpoint;
        if (refresh) {
            String folderId = parseDriveFolderId(folderUrlInput);
            if (folderId.isEmpty()) throw new IllegalArgumentException("Link de pasta do Google Drive inválido (use HTTPS).");
            Map<String, CloudGameEntry> preservedLocal = new LinkedHashMap<>(state.itemsById);
            state.rootUrl = folderUrlInput.trim();
            state.rootFolderId = folderId;
            state.pendingFolders.clear();
            state.visitedFolderIds.clear();
            state.seenFileIds.clear();
            state.pendingFolders.add(new FolderTask(folderId, "", 0));
            state.completed = false;
            state.totalFoldersRead = 0;
            state.lastError = "";
            state.itemsById.clear();
            state.itemsById.putAll(preservedLocal);
        } else if (state.rootFolderId.isEmpty()) {
            throw new IllegalStateException("Nenhuma varredura do Google Drive configurada.");
        }

        int foldersThisBatch = 0;
        int filesThisBatch = 0;
        state.lastError = "";

        while (!state.pendingFolders.isEmpty() && foldersThisBatch < BATCH_FOLDER_BUDGET && filesThisBatch < MAX_BATCH_FILES) {
            FolderTask current = state.pendingFolders.remove(0);
            if (state.visitedFolderIds.contains(current.id) || current.depth > MAX_DEPTH) {
                continue;
            }
            FetchResult response;
            try {
                response = fetcher.fetch(current.id, bearerToken);
            } catch (Exception netErr) {
                state.pendingFolders.add(0, current);
                state.lastError = "Falha de rede (progresso preservado): " + netErr.getMessage();
                state.updatedAtMs = System.currentTimeMillis();
                throw netErr;
            }
            if (response.statusCode == 401 || response.statusCode == 403) {
                state.pendingFolders.add(0, current);
                state.lastError = "Pasta privada ou sem permissão no Google Drive.";
                state.updatedAtMs = System.currentTimeMillis();
                throw new IllegalStateException(state.lastError);
            }
            if (response.statusCode < 200 || response.statusCode >= 300) {
                state.pendingFolders.add(0, current);
                state.lastError = "Google Drive respondeu HTTP " + response.statusCode;
                state.updatedAtMs = System.currentTimeMillis();
                throw new IllegalStateException(state.lastError);
            }
            if (response.body.getBytes(StandardCharsets.UTF_8).length > MAX_RESPONSE_BYTES) {
                state.pendingFolders.add(0, current);
                state.lastError = "Resposta do Drive excedeu o limite seguro de 8 MB.";
                state.updatedAtMs = System.currentTimeMillis();
                throw new IllegalStateException(state.lastError);
            }

            state.visitedFolderIds.add(current.id);
            foldersThisBatch++;
            state.totalFoldersRead++;

            ParsedFolderPage parsed = parseFolderHtml(response.body, current.relativePath, current.id, current.depth + 1);
            for (FolderTask sub : parsed.subfolders) {
                if (!state.visitedFolderIds.contains(sub.id)) {
                    state.pendingFolders.add(sub);
                }
            }
            for (CloudGameEntry entry : parsed.files) {
                state.seenFileIds.add(entry.id);
                filesThisBatch++;
                CloudGameEntry prev = state.itemsById.get(entry.id);
                if (prev != null && isAvailabilityPlayableLocally(prev.downloadedLocalPath)) {
                    entry.downloadedLocalPath = prev.downloadedLocalPath;
                    entry.downloadedBytes = prev.downloadedBytes;
                    entry.downloadStatus = "available";
                }
                state.itemsById.put(entry.id, entry);
            }
        }

        if (state.pendingFolders.isEmpty()) {
            state.completed = true;
            List<String> toRemove = new ArrayList<>();
            for (Map.Entry<String, CloudGameEntry> e : state.itemsById.entrySet()) {
                if (!state.seenFileIds.contains(e.getKey()) && !isAvailabilityPlayableLocally(e.getValue().downloadedLocalPath)) {
                    toRemove.add(e.getKey());
                }
            }
            for (String key : toRemove) state.itemsById.remove(key);
        } else {
            state.completed = false;
        }
        state.updatedAtMs = System.currentTimeMillis();
        return state;
    }

    private static String unescapeHtml(String text) {
        return text.replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'")
            .replace("&lt;", "<").replace("&gt;", ">");
    }
}

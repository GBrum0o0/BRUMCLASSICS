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
    private static final Pattern RESOURCE_KEY_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,200}$");
    private static final Pattern FOLDER_URL_PATTERN = Pattern.compile("/folders/([A-Za-z0-9_-]{10,128})");
    private static final Pattern FILE_URL_PATTERN = Pattern.compile("/file/d/([A-Za-z0-9_-]{10,128})");
    private static final Pattern QUERY_ID_PATTERN = Pattern.compile("[?&]id=([A-Za-z0-9_-]{10,128})");
    private static final Pattern QUERY_RK_PATTERN = Pattern.compile("[?&]resourcekey=([A-Za-z0-9_-]{1,200})", Pattern.CASE_INSENSITIVE);
    private static final Pattern HTML_ANCHOR_PATTERN = Pattern.compile(
        "<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</a>",
        Pattern.CASE_INSENSITIVE | Pattern.DOTALL
    );
    private static final Pattern FLIP_TITLE_PATTERN = Pattern.compile(
        "class=[\"'][^\"']*flip-entry-title[^\"']*[\"'][^>]*>([\\s\\S]*?)</div>",
        Pattern.CASE_INSENSITIVE | Pattern.DOTALL
    );
    private static final Pattern HTML_TAG_PATTERN = Pattern.compile("<[^>]*>");
    private static final Pattern HTML_ENTITY_PATTERN = Pattern.compile("&#x([0-9a-fA-F]+);|&#(\\d+);|&(amp|quot|apos|lt|gt|nbsp);", Pattern.CASE_INSENSITIVE);
    private static final Pattern HTML_DATA_ID = Pattern.compile(
        "data-id=\"([A-Za-z0-9_-]{10,128})\"[^>]*?(?:data-target=\"([^\"]*)\")?[^>]*?>[\\s\\S]{0,600}?(?:aria-label|data-tooltip)=\"([^\"]{1,220})\"",
        Pattern.CASE_INSENSITIVE
    );

    public interface HttpFetcher {
        FetchResult fetch(String folderId, String bearerToken) throws Exception;

        default FetchResult fetch(String folderId, String resourceKey, String bearerToken) throws Exception {
            return fetch(folderId, bearerToken);
        }
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
        public final String resourceKey;

        public FolderTask(String id, String relativePath, int depth) {
            this(id, relativePath, depth, "");
        }

        public FolderTask(String id, String relativePath, int depth, String resourceKey) {
            this.id = id;
            this.relativePath = relativePath == null ? "" : relativePath;
            this.depth = depth;
            this.resourceKey = resourceKey == null ? "" : resourceKey;
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
            if (uri.getRawUserInfo() != null || uri.getPort() != -1) return false;
            String host = uri.getHost();
            if (host == null || host.isEmpty()) return false;
            String lower = host.toLowerCase(Locale.ROOT);
            return ALLOWED_HOSTS.contains(lower) || lower.endsWith(".googleusercontent.com");
        } catch (Exception ignored) {
            return false;
        }
    }

    public static final class ParsedLink {
        public final String id;
        public final boolean folder;
        public final String resourceKey;

        public ParsedLink(String id, boolean folder, String resourceKey) {
            this.id = id;
            this.folder = folder;
            this.resourceKey = resourceKey == null ? "" : resourceKey;
        }
    }

    public static ParsedLink parseDriveLink(String rawInput) {
        if (rawInput == null) return null;
        String trimmed = rawInput.trim();
        if (RAW_ID_PATTERN.matcher(trimmed).matches()) {
            return new ParsedLink(trimmed, true, "");
        }
        if (!isAllowedUrl(trimmed)) return null;
        String resourceKey = "";
        Matcher rkMatcher = QUERY_RK_PATTERN.matcher(trimmed);
        if (rkMatcher.find()) {
            String candidate = rkMatcher.group(1);
            if (candidate != null && RESOURCE_KEY_PATTERN.matcher(candidate).matches()) {
                resourceKey = candidate;
            }
        }
        Matcher folderMatcher = FOLDER_URL_PATTERN.matcher(trimmed);
        if (folderMatcher.find()) {
            return new ParsedLink(folderMatcher.group(1), true, resourceKey);
        }
        Matcher fileMatcher = FILE_URL_PATTERN.matcher(trimmed);
        if (fileMatcher.find()) {
            return new ParsedLink(fileMatcher.group(1), false, resourceKey);
        }
        Matcher queryMatcher = QUERY_ID_PATTERN.matcher(trimmed);
        if (queryMatcher.find()) {
            boolean isFolder = trimmed.toLowerCase(Locale.ROOT).contains("folder");
            return new ParsedLink(queryMatcher.group(1), isFolder, resourceKey);
        }
        return null;
    }

    public static String parseDriveFolderId(String rawInput) {
        ParsedLink link = parseDriveLink(rawInput);
        return link == null ? "" : link.id;
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
        return directDownloadUrl(fileId, "");
    }

    public static String directDownloadUrl(String fileId, String resourceKey) {
        String base = "https://drive.usercontent.google.com/download?id=" + fileId + "&export=download&confirm=t";
        if (resourceKey != null && !resourceKey.isEmpty()) {
            return base + "&resourcekey=" + resourceKey;
        }
        return base;
    }

    public static String detectSystemHint(String relativePath, String filename) {
        String joined = ((relativePath == null ? "" : relativePath) + "/" + (filename == null ? "" : filename))
            .toLowerCase(Locale.ROOT).replace('\\', '/');
        String ext = ClassicsRules.extension(filename);
        if (joined.contains("ppsspp") || joined.contains("/psp/") || joined.contains("/playstation portable/") || joined.contains("/sony psp/") || "cso".equals(ext)) return "psp";
        if (joined.contains("/nds/") || "nds".equals(ext)) return "nds";
        if (joined.contains("/3ds/") || "3ds".equals(ext) || "3dsx".equals(ext) || "cci".equals(ext) || "cxi".equals(ext)) return "3ds";
        if (joined.contains("/gba/") || "gba".equals(ext)) return "gba";
        if (joined.contains("/gbc/") || "gbc".equals(ext)) return "gbc";
        if (joined.contains("/gb/") || "gb".equals(ext)) return "gb";
        if (joined.contains("/snes/") || "sfc".equals(ext) || "smc".equals(ext)) return "snes";
        if (joined.contains("/nes/") || "nes".equals(ext)) return "nes";
        if (joined.contains("/n64/") || "z64".equals(ext) || "n64".equals(ext) || "v64".equals(ext)) return "n64";
        if (joined.contains("/ps1/") || joined.contains("/psx/")) return "ps1";
        if (joined.contains("/ps2/") || "isz".equals(ext)) return "ps2";
        if (joined.contains("/dreamcast/") || "gdi".equals(ext)) return "dreamcast";
        if (joined.contains("/genesis/") || joined.contains("/megadrive/") || "md".equals(ext) || "gen".equals(ext)) return "megadrive";
        if (joined.contains("/sms/") || "sms".equals(ext)) return "sms";
        if (joined.contains("/gg/") || "gg".equals(ext)) return "gg";
        if (joined.contains("/pce/") || "pce".equals(ext)) return "pce";
        if (joined.contains("/neogeo/") || "neo".equals(ext)) return "neogeo";
        if (joined.contains("/ws/") || "ws".equals(ext)) return "ws";
        if (joined.contains("/wsc/") || "wsc".equals(ext)) return "wsc";
        return "";
    }

    public static ParsedFolderPage parseFolderHtml(String html, String parentRelativePath, String folderId, int nextDepth) {
        ParsedFolderPage page = new ParsedFolderPage();
        if (html == null || html.isEmpty()) return page;
        Map<String, FolderTask> folders = new LinkedHashMap<>();
        Map<String, ParsedLink> files = new LinkedHashMap<>();
        Map<String, String> fileNames = new LinkedHashMap<>();
        String prefix = parentRelativePath == null ? "" : parentRelativePath;

        Matcher anchorMatcher = HTML_ANCHOR_PATTERN.matcher(html);
        while (anchorMatcher.find()) {
            String rawHref = unescapeHtml(anchorMatcher.group(1)).trim();
            ParsedLink link = parseDriveLink(rawHref);
            if (link == null) continue;
            String inner = anchorMatcher.group(2);
            String extracted = "";
            Matcher titleMatcher = FLIP_TITLE_PATTERN.matcher(inner);
            if (titleMatcher.find()) {
                extracted = stripTagsAndDecode(titleMatcher.group(1));
            }
            if (extracted.isEmpty()) {
                extracted = stripTagsAndDecode(inner);
            }
            if (extracted.length() > 300) extracted = extracted.substring(0, 300);
            extracted = extracted.trim();
            if (extracted.isEmpty()) continue;

            if (link.folder) {
                String rel = prefix.isEmpty() ? extracted : prefix + "/" + extracted;
                folders.putIfAbsent(link.id, new FolderTask(link.id, rel, nextDepth, link.resourceKey));
            } else {
                files.putIfAbsent(link.id, link);
                fileNames.putIfAbsent(link.id, extracted);
            }
        }

        Matcher mData = HTML_DATA_ID.matcher(html);
        while (mData.find()) {
            String id = mData.group(1);
            String target = mData.group(2) == null ? "" : mData.group(2).toLowerCase(Locale.ROOT);
            String name = stripTagsAndDecode(mData.group(3));
            if (name.isEmpty()) continue;
            if ("folder".equals(target) || (!name.contains(".") && !isAcceptedClassicFile(name))) {
                String rel = prefix.isEmpty() ? name : prefix + "/" + name;
                folders.putIfAbsent(id, new FolderTask(id, rel, nextDepth, ""));
            } else {
                files.putIfAbsent(id, new ParsedLink(id, false, ""));
                fileNames.putIfAbsent(id, name);
            }
        }

        page.subfolders.addAll(folders.values());
        for (Map.Entry<String, String> entry : fileNames.entrySet()) {
            String name = entry.getValue();
            if (!isAcceptedClassicFile(name)) continue;
            String rel = prefix.isEmpty() ? name : prefix + "/" + name;
            ParsedLink link = files.get(entry.getKey());
            String rk = link == null ? "" : link.resourceKey;
            page.files.add(new CloudGameEntry(
                entry.getKey(),
                name,
                ClassicsRules.cleanTitle(name),
                rel,
                folderId,
                prefix,
                -1L,
                detectSystemHint(rel, name),
                directDownloadUrl(entry.getKey(), rk)
            ));
        }
        return page;
    }

    public static boolean isServiceLoginHtml(String html) {
        return html != null && html.toLowerCase(Locale.ROOT).contains("accounts.google.com/servicelogin");
    }

    public static String extractSingleFileTitle(String html) {
        if (html == null) return "";
        Matcher m = Pattern.compile("<title[^>]*>([\\s\\S]*?)</title>", Pattern.CASE_INSENSITIVE).matcher(html);
        if (!m.find()) return "";
        return stripTagsAndDecode(m.group(1)).replaceFirst("(?i)\\s*[-–]\\s*Google Drive\\s*$", "").trim();
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
            ParsedLink rootLink = parseDriveLink(folderUrlInput);
            if (rootLink == null || rootLink.id.isEmpty()) {
                throw new IllegalArgumentException("Link de pasta do Google Drive inválido (use HTTPS).");
            }
            Map<String, CloudGameEntry> preservedLocal = new LinkedHashMap<>(state.itemsById);
            state.rootUrl = folderUrlInput.trim();
            state.rootFolderId = rootLink.id;
            state.pendingFolders.clear();
            state.visitedFolderIds.clear();
            state.seenFileIds.clear();
            state.completed = false;
            state.totalFoldersRead = 0;
            state.lastError = "";
            state.itemsById.clear();
            state.itemsById.putAll(preservedLocal);
            if (!rootLink.folder) {
                FetchResult singleResp = fetcher.fetch(rootLink.id, rootLink.resourceKey, bearerToken);
                if (singleResp.statusCode == 401 || singleResp.statusCode == 403 || isServiceLoginHtml(singleResp.body)) {
                    throw new IllegalStateException("Pasta privada ou sem permissão no Google Drive.");
                }
                String name = extractSingleFileTitle(singleResp.body);
                if (!isAcceptedClassicFile(name)) {
                    throw new IllegalArgumentException("O link não aponta para um jogo clássico compatível.");
                }
                CloudGameEntry entry = new CloudGameEntry(
                    rootLink.id, name, ClassicsRules.cleanTitle(name), name, rootLink.id, "", -1L,
                    detectSystemHint(name, name), directDownloadUrl(rootLink.id, rootLink.resourceKey)
                );
                CloudGameEntry prev = state.itemsById.get(rootLink.id);
                if (prev != null && isAvailabilityPlayableLocally(prev.downloadedLocalPath)) {
                    entry.downloadedLocalPath = prev.downloadedLocalPath;
                    entry.downloadedBytes = prev.downloadedBytes;
                    entry.downloadStatus = "available";
                }
                state.itemsById.put(rootLink.id, entry);
                state.completed = true;
                state.totalFoldersRead = 1;
                state.updatedAtMs = System.currentTimeMillis();
                return state;
            }
            state.pendingFolders.add(new FolderTask(rootLink.id, "", 0, rootLink.resourceKey));
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
                response = fetcher.fetch(current.id, current.resourceKey, bearerToken);
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

            ParsedFolderPage parsed = parseFolderHtml(response.body, current.relativePath, current.id, current.depth + 1);
            if (isServiceLoginHtml(response.body) && parsed.subfolders.isEmpty() && parsed.files.isEmpty()) {
                state.pendingFolders.add(0, current);
                state.lastError = "Pasta privada ou restrita. Compartilhe como 'Qualquer pessoa com o link' ou informe um token OAuth.";
                state.updatedAtMs = System.currentTimeMillis();
                throw new IllegalStateException(state.lastError);
            }

            state.visitedFolderIds.add(current.id);
            foldersThisBatch++;
            state.totalFoldersRead++;

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

    static String stripTagsAndDecode(String html) {
        if (html == null) return "";
        String stripped = HTML_TAG_PATTERN.matcher(html).replaceAll("");
        return unescapeHtml(stripped).replaceAll("\\s+", " ").trim();
    }

    static String unescapeHtml(String text) {
        if (text == null || text.isEmpty()) return "";
        Matcher m = HTML_ENTITY_PATTERN.matcher(text);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String replacement = "";
            if (m.group(1) != null) {
                try {
                    int cp = Integer.parseInt(m.group(1), 16);
                    if (cp >= 0 && cp <= 0x10ffff) replacement = new String(Character.toChars(cp));
                } catch (Exception ignored) {}
            } else if (m.group(2) != null) {
                try {
                    int cp = Integer.parseInt(m.group(2));
                    if (cp >= 0 && cp <= 0x10ffff) replacement = new String(Character.toChars(cp));
                } catch (Exception ignored) {}
            } else if (m.group(3) != null) {
                switch (m.group(3).toLowerCase(Locale.ROOT)) {
                    case "amp": replacement = "&"; break;
                    case "quot": replacement = "\""; break;
                    case "apos": replacement = "'"; break;
                    case "lt": replacement = "<"; break;
                    case "gt": replacement = ">"; break;
                    case "nbsp": replacement = " "; break;
                    default: replacement = ""; break;
                }
            }
            m.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        m.appendTail(sb);
        return sb.toString();
    }
}

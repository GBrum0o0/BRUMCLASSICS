package com.brumclassics.mobile.extensions;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Pure JDK domain engine for Extensão 001: Pokédex Universal.
 * Intentionally free of Android framework or external JSON library imports so it
 * can be verified directly by javac + java contract tests in CI as well as inside the APK.
 */
public final class PokedexUniversalEngine {
    public static final String UNKNOWN_LOCATION = "Localização desconhecida";
    public static final String UNKNOWN_TEXT = "???";
    public static final String CATEGORY_NORMAL = "normal";
    public static final String CATEGORY_SHINY = "shiny";
    public static final int MAX_NATIONAL_DEX = 802;
    private static final Pattern PROFILE_ID_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]{1,100}$");

    public static String validateProfileId(String raw) {
        String id = (raw == null || raw.trim().isEmpty()) ? "primary" : raw.trim();
        if (!PROFILE_ID_PATTERN.matcher(id).matches()) {
            throw new IllegalArgumentException("Identificador de perfil inválido para o sistema de extensões.");
        }
        return id;
    }

    public static final class SpeciesDefinition {
        public final int nationalDexNumber;
        public final String formattedNumber;
        public final int generation;
        public final String name;
        public final String genus;
        public final String description;
        public final String normalSpriteKey;
        public final String shinySpriteKey;
        public final String silhouetteSpriteKey;

        public SpeciesDefinition(int nationalDexNumber, int generation, String name, String genus, String description) {
            this.nationalDexNumber = nationalDexNumber;
            this.formattedNumber = String.format(Locale.ROOT, "%03d", nationalDexNumber);
            this.generation = generation;
            this.name = name;
            this.genus = genus;
            this.description = description;
            this.normalSpriteKey = "pokedex/normal/" + this.formattedNumber;
            this.shinySpriteKey = "pokedex/shiny/" + this.formattedNumber;
            this.silhouetteSpriteKey = "pokedex/silhouette/" + this.formattedNumber;
        }
    }

    public static final class CaptureRecord {
        public final String captureId;
        public final String ownerProfileId;
        public final int nationalDexNumber;
        public final String formattedNumber;
        public final int generation;
        public final String speciesName;
        public final String speciesDescription;
        public final String category;
        public final boolean isShiny;
        public final String firstCapturedGame;
        public final String firstCapturedGameId;
        public final String systemId;
        public final String capturedAt;
        public final String captureLocation;
        public final String sourceDeviceId;

        public CaptureRecord(
                String captureId,
                String ownerProfileId,
                int nationalDexNumber,
                int generation,
                String speciesName,
                String speciesDescription,
                String category,
                String firstCapturedGame,
                String firstCapturedGameId,
                String systemId,
                String capturedAt,
                String captureLocation,
                String sourceDeviceId
        ) {
            this.ownerProfileId = validateProfileId(ownerProfileId);
            this.nationalDexNumber = nationalDexNumber;
            this.formattedNumber = String.format(Locale.ROOT, "%03d", nationalDexNumber);
            this.generation = generation;
            this.speciesName = speciesName == null ? "" : speciesName;
            this.speciesDescription = speciesDescription == null ? "" : speciesDescription;
            this.category = CATEGORY_SHINY.equals(category) ? CATEGORY_SHINY : CATEGORY_NORMAL;
            this.isShiny = CATEGORY_SHINY.equals(this.category);
            this.firstCapturedGame = (firstCapturedGame == null || firstCapturedGame.trim().isEmpty())
                    ? "Pokémon FireRed Version" : firstCapturedGame.trim();
            this.firstCapturedGameId = firstCapturedGameId == null ? "" : firstCapturedGameId.trim();
            this.systemId = (systemId == null || systemId.trim().isEmpty()) ? "gba" : systemId.trim().toLowerCase(Locale.ROOT);
            this.capturedAt = (capturedAt == null || capturedAt.trim().isEmpty()) ? Instant.now().toString() : capturedAt.trim();
            this.captureLocation = sanitizeLocation(captureLocation);
            this.sourceDeviceId = (sourceDeviceId == null || sourceDeviceId.trim().isEmpty()) ? "android-mobile" : sourceDeviceId.trim();
            this.captureId = (captureId == null || captureId.trim().isEmpty())
                    ? sha256Hex(this.ownerProfileId + "|" + this.nationalDexNumber + "|" + this.category + "|" + this.firstCapturedGame + "|" + this.capturedAt + "|" + this.captureLocation).substring(0, 32)
                    : captureId.trim();
        }

        public String key() {
            return nationalDexNumber + ":" + category;
        }
    }

    public static final class ProjectedEntry {
        public final int nationalDexNumber;
        public final String formattedNumber;
        public final int generation;
        public final boolean discovered;
        public final boolean silhouetteOnly;
        public final String category;
        public final boolean isShiny;
        public final String name;
        public final String description;
        public final String activeSpriteKey;
        public final CaptureRecord capture;

        public ProjectedEntry(
                int nationalDexNumber,
                int generation,
                boolean discovered,
                boolean silhouetteOnly,
                String category,
                String name,
                String description,
                String activeSpriteKey,
                CaptureRecord capture
        ) {
            this.nationalDexNumber = nationalDexNumber;
            this.formattedNumber = String.format(Locale.ROOT, "%03d", nationalDexNumber);
            this.generation = generation;
            this.discovered = discovered;
            this.silhouetteOnly = silhouetteOnly;
            this.category = category;
            this.isShiny = CATEGORY_SHINY.equals(category);
            this.name = name;
            this.description = description;
            this.activeSpriteKey = activeSpriteKey;
            this.capture = capture;
        }
    }

    public static final class DiscoveryNotification {
        public final String eventId;
        public final int nationalDexNumber;
        public final String formattedNumber;
        public final String speciesName;
        public final String category;
        public final boolean isShiny;
        public final String gameTitle;
        public final String title;
        public final String headline;
        public final String subtitle;

        public DiscoveryNotification(CaptureRecord record) {
            this.eventId = "pokedex-discovery:" + record.ownerProfileId + ":" + record.nationalDexNumber + ":" + record.category;
            this.nationalDexNumber = record.nationalDexNumber;
            this.formattedNumber = record.formattedNumber;
            this.speciesName = record.speciesName;
            this.category = record.category;
            this.isShiny = record.isShiny;
            this.gameTitle = record.firstCapturedGame;
            this.title = record.isShiny ? "Novo Pokémon Shiny descoberto!" : "Novo Pokémon descoberto!";
            this.headline = record.formattedNumber + " — " + record.speciesName;
            this.subtitle = "Registrado na Pokédex Universal";
        }
    }

    public static final class RecordOutcome {
        public final boolean recorded;
        public final boolean duplicate;
        public final CaptureRecord record;
        public final DiscoveryNotification notification;

        public RecordOutcome(boolean recorded, boolean duplicate, CaptureRecord record, DiscoveryNotification notification) {
            this.recorded = recorded;
            this.duplicate = duplicate;
            this.record = record;
            this.notification = notification;
        }
    }

    public static final class MergeOutcome {
        public final int addedCount;
        public final int replacedWithEarlierCount;
        public final int preservedCount;
        public final int totalRecords;
        public final String contentSha256;

        public MergeOutcome(int addedCount, int replacedWithEarlierCount, int preservedCount, int totalRecords, String contentSha256) {
            this.addedCount = addedCount;
            this.replacedWithEarlierCount = replacedWithEarlierCount;
            this.preservedCount = preservedCount;
            this.totalRecords = totalRecords;
            this.contentSha256 = contentSha256;
        }
    }

    public static final class BackupBundle {
        public final int schemaVersion;
        public final String backupType;
        public final String ownerProfileId;
        public final int syncRevision;
        public final int recordCount;
        public final String contentSha256;
        public final List<CaptureRecord> records;

        public BackupBundle(int schemaVersion, String backupType, String ownerProfileId, int syncRevision, int recordCount, String contentSha256, List<CaptureRecord> records) {
            this.schemaVersion = schemaVersion;
            this.backupType = backupType;
            this.ownerProfileId = ownerProfileId;
            this.syncRevision = syncRevision;
            this.recordCount = recordCount;
            this.contentSha256 = contentSha256;
            this.records = records == null ? Collections.emptyList() : Collections.unmodifiableList(new ArrayList<>(records));
        }
    }

    public static final class ProjectedView {
        public final List<ProjectedEntry> pokemonTab;
        public final List<ProjectedEntry> shiniesTab;
        public final int normalDiscovered;
        public final int shinyDiscovered;
        public final String contentSha256;

        public ProjectedView(List<ProjectedEntry> pokemonTab, List<ProjectedEntry> shiniesTab, int normalDiscovered, int shinyDiscovered, String contentSha256) {
            this.pokemonTab = Collections.unmodifiableList(pokemonTab);
            this.shiniesTab = Collections.unmodifiableList(shiniesTab);
            this.normalDiscovered = normalDiscovered;
            this.shinyDiscovered = shinyDiscovered;
            this.contentSha256 = contentSha256;
        }
    }

    private final String ownerProfileId;
    private final Map<Integer, SpeciesDefinition> catalogByDex = new HashMap<>(820);
    private final Map<String, CaptureRecord> recordsByKey = new HashMap<>();
    private final Set<Integer> enabledGenerations = new HashSet<>();
    private int syncRevision = 1;

    public PokedexUniversalEngine(String ownerProfileId) {
        this.ownerProfileId = validateProfileId(ownerProfileId);
        this.enabledGenerations.add(1);
        PokedexSpeciesCatalogData.populate(this.catalogByDex);
    }

    public SpeciesDefinition getSpecies(int nationalDexNumber) {
        return catalogByDex.get(nationalDexNumber);
    }

    public static String sanitizeLocation(String raw) {
        if (raw == null) return UNKNOWN_LOCATION;
        String cleaned = raw.replace('\r', ' ').replace('\n', ' ').trim();
        if (cleaned.isEmpty() || "unknown".equalsIgnoreCase(cleaned) || UNKNOWN_TEXT.equals(cleaned)) {
            return UNKNOWN_LOCATION;
        }
        return cleaned.length() > 120 ? cleaned.substring(0, 120) : cleaned;
    }

    public static String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                sb.append(String.format(Locale.ROOT, "%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 indisponível", e);
        }
    }

    public static String canonicalRecordsHash(List<CaptureRecord> records) {
        List<CaptureRecord> sorted = new ArrayList<>(records == null ? Collections.emptyList() : records);
        Collections.sort(sorted, new Comparator<CaptureRecord>() {
            @Override
            public int compare(CaptureRecord a, CaptureRecord b) {
                if (a.nationalDexNumber != b.nationalDexNumber) {
                    return Integer.compare(a.nationalDexNumber, b.nationalDexNumber);
                }
                return a.category.compareTo(b.category);
            }
        });
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < sorted.size(); i++) {
            CaptureRecord r = sorted.get(i);
            if (i > 0) sb.append('\n');
            sb.append(r.nationalDexNumber).append('|')
              .append(r.category).append('|')
              .append(r.speciesName).append('|')
              .append(r.firstCapturedGame).append('|')
              .append(r.firstCapturedGameId).append('|')
              .append(r.systemId).append('|')
              .append(r.capturedAt).append('|')
              .append(r.captureLocation).append('|')
              .append(r.ownerProfileId).append('|')
              .append(r.captureId);
        }
        return sha256Hex(sb.toString());
    }

    public List<CaptureRecord> sortedRecords() {
        List<CaptureRecord> list = new ArrayList<>(recordsByKey.values());
        Collections.sort(list, new Comparator<CaptureRecord>() {
            @Override
            public int compare(CaptureRecord a, CaptureRecord b) {
                if (a.nationalDexNumber != b.nationalDexNumber) {
                    return Integer.compare(a.nationalDexNumber, b.nationalDexNumber);
                }
                return a.category.compareTo(b.category);
            }
        });
        return list;
    }

    public String contentSha256() {
        return canonicalRecordsHash(sortedRecords());
    }

    public RecordOutcome recordCapture(
            int nationalDexNumber,
            boolean isShiny,
            String gameTitle,
            String gameId,
            String systemId,
            String capturedAt,
            String captureLocation,
            String sourceDeviceId
    ) {
        SpeciesDefinition sp = catalogByDex.get(nationalDexNumber);
        if (sp == null) {
            throw new IllegalArgumentException("Espécie inválida na Pokédex Nacional: " + nationalDexNumber);
        }
        String category = isShiny ? CATEGORY_SHINY : CATEGORY_NORMAL;
        String key = nationalDexNumber + ":" + category;
        CaptureRecord existing = recordsByKey.get(key);
        if (existing != null) {
            return new RecordOutcome(false, true, existing, null);
        }

        CaptureRecord created = new CaptureRecord(
                null,
                ownerProfileId,
                sp.nationalDexNumber,
                sp.generation,
                sp.name,
                sp.description,
                category,
                gameTitle,
                gameId,
                systemId,
                capturedAt,
                captureLocation,
                sourceDeviceId
        );
        recordsByKey.put(key, created);
        syncRevision++;
        return new RecordOutcome(true, false, created, new DiscoveryNotification(created));
    }

    private static Long parseIsoEpochMillis(String value) {
        if (value == null || value.isEmpty()) return null;
        try {
            return Instant.parse(value).toEpochMilli();
        } catch (Exception ignored) {
            return null;
        }
    }

    public static boolean isEarlier(CaptureRecord candidate, CaptureRecord existing) {
        Long tCand = parseIsoEpochMillis(candidate.capturedAt);
        Long tExist = parseIsoEpochMillis(existing.capturedAt);
        if (tCand != null && tExist != null && !tCand.equals(tExist)) {
            return tCand < tExist;
        }
        int cmp = candidate.capturedAt.compareTo(existing.capturedAt);
        if (cmp != 0) return cmp < 0;
        return candidate.captureId.compareTo(existing.captureId) < 0;
    }

    public MergeOutcome mergeRecords(List<CaptureRecord> incoming) {
        return mergeRecords(incoming, ownerProfileId);
    }

    public MergeOutcome mergeRecords(List<CaptureRecord> incoming, String incomingOwnerProfileId) {
        if (incomingOwnerProfileId != null && !incomingOwnerProfileId.trim().isEmpty()
                && !ownerProfileId.equals(validateProfileId(incomingOwnerProfileId))) {
            throw new IllegalArgumentException("O perfil da coleção recebida não corresponde ao perfil ativo.");
        }
        int added = 0;
        int replaced = 0;
        int preserved = 0;
        if (incoming != null) {
            for (CaptureRecord item : incoming) {
                if (item == null || !catalogByDex.containsKey(item.nationalDexNumber)) {
                    throw new IllegalArgumentException("Registro inválido na mesclagem da Pokédex.");
                }
                SpeciesDefinition sp = catalogByDex.get(item.nationalDexNumber);
                CaptureRecord normalized = new CaptureRecord(
                        item.captureId,
                        ownerProfileId,
                        sp.nationalDexNumber,
                        sp.generation,
                        sp.name,
                        sp.description,
                        item.category,
                        item.firstCapturedGame,
                        item.firstCapturedGameId,
                        item.systemId,
                        item.capturedAt,
                        item.captureLocation,
                        item.sourceDeviceId
                );
                String key = normalized.key();
                CaptureRecord existing = recordsByKey.get(key);
                if (existing == null) {
                    recordsByKey.put(key, normalized);
                    added++;
                } else if (isEarlier(normalized, existing)) {
                    recordsByKey.put(key, normalized);
                    replaced++;
                } else {
                    preserved++;
                }
            }
        }
        if (added > 0 || replaced > 0) {
            syncRevision++;
        }
        return new MergeOutcome(added, replaced, preserved, recordsByKey.size(), contentSha256());
    }

    public BackupBundle exportBackup() {
        List<CaptureRecord> sorted = sortedRecords();
        return new BackupBundle(
                1,
                "brum.ext.pokedex.backup",
                ownerProfileId,
                syncRevision,
                sorted.size(),
                canonicalRecordsHash(sorted),
                sorted
        );
    }

    public static void verifyBackup(BackupBundle bundle) {
        if (bundle == null || bundle.schemaVersion != 1 || !"brum.ext.pokedex.backup".equals(bundle.backupType)) {
            throw new IllegalArgumentException("Arquivo de backup da Pokédex inválido.");
        }
        if (bundle.records == null || bundle.recordCount != bundle.records.size()) {
            throw new IllegalArgumentException("Contagem de registros divergente no backup da Pokédex.");
        }
        String computed = canonicalRecordsHash(bundle.records);
        if (!computed.equals(bundle.contentSha256)) {
            throw new IllegalArgumentException("A verificação de integridade SHA-256 do backup da Pokédex falhou.");
        }
    }

    public MergeOutcome restoreBackup(BackupBundle bundle) {
        verifyBackup(bundle);
        return mergeRecords(bundle.records, bundle.ownerProfileId);
    }

    public ProjectedView projectView() {
        Set<Integer> discoveredDex = new HashSet<>();
        for (CaptureRecord r : recordsByKey.values()) {
            discoveredDex.add(r.nationalDexNumber);
        }

        List<ProjectedEntry> pokemonTab = new ArrayList<>();
        List<ProjectedEntry> shiniesTab = new ArrayList<>();
        int normalDiscovered = 0;
        int shinyDiscovered = 0;

        for (int dex = 1; dex <= MAX_NATIONAL_DEX; dex++) {
            SpeciesDefinition sp = catalogByDex.get(dex);
            if (sp == null) continue;
            if (!enabledGenerations.contains(sp.generation) && !discoveredDex.contains(dex)) {
                continue;
            }

            CaptureRecord normalRec = recordsByKey.get(dex + ":" + CATEGORY_NORMAL);
            if (normalRec != null) {
                normalDiscovered++;
                pokemonTab.add(new ProjectedEntry(
                        sp.nationalDexNumber,
                        sp.generation,
                        true,
                        false,
                        CATEGORY_NORMAL,
                        sp.name,
                        sp.description,
                        sp.normalSpriteKey,
                        normalRec
                ));
            } else {
                pokemonTab.add(new ProjectedEntry(
                        sp.nationalDexNumber,
                        sp.generation,
                        false,
                        true,
                        CATEGORY_NORMAL,
                        UNKNOWN_TEXT,
                        UNKNOWN_TEXT,
                        sp.silhouetteSpriteKey,
                        null
                ));
            }

            CaptureRecord shinyRec = recordsByKey.get(dex + ":" + CATEGORY_SHINY);
            if (shinyRec != null) {
                shinyDiscovered++;
                shiniesTab.add(new ProjectedEntry(
                        sp.nationalDexNumber,
                        sp.generation,
                        true,
                        false,
                        CATEGORY_SHINY,
                        sp.name,
                        sp.description,
                        sp.shinySpriteKey,
                        shinyRec
                ));
            }
        }

        return new ProjectedView(pokemonTab, shiniesTab, normalDiscovered, shinyDiscovered, contentSha256());
    }

    public int getSyncRevision() {
        return syncRevision;
    }
}

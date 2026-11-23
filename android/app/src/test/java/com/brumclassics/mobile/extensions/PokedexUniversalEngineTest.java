package com.brumclassics.mobile.extensions;

import java.util.Arrays;
import java.util.Collections;

public final class PokedexUniversalEngineTest {
    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("FAIL: " + message);
        }
    }

    private static PokedexUniversalEngine.CaptureRecord fixture(String id, String owner, int dex, String timestamp) {
        return new PokedexUniversalEngine.CaptureRecord(id, owner, dex, 1, "Pikachu", "", "normal",
                "Pokémon FireRed Version", "firered-1", "gba", timestamp, "Route 1", "test");
    }

    private static void regressionMergeIsolationAndAtomicity() {
        PokedexUniversalEngine engine = new PokedexUniversalEngine("primary");
        PokedexUniversalEngine candidate = engine.copy();
        candidate.recordCapture(25, false, "FireRed", "fr", "gba", "2026-11-22T10:00:00Z", "Route 1", "test");
        check(engine.sortedRecords().isEmpty(), "A pending disk transaction must not mutate live engine");
        String emptyHash = engine.contentSha256();
        int revision = engine.getSyncRevision();
        boolean rejected = false;
        try {
            engine.mergeRecords(Arrays.asList(fixture("a", "primary", 25, "2026-11-22T10:00:00Z"),
                    fixture("b", "primary", 9999, "2026-11-22T10:00:00Z")));
        } catch (IllegalArgumentException expected) { rejected = true; }
        check(rejected && engine.sortedRecords().isEmpty() && emptyHash.equals(engine.contentSha256())
                && revision == engine.getSyncRevision(), "Invalid batch must not partially mutate collection or revision");
        rejected = false;
        try { engine.mergeRecords(Collections.singletonList(fixture("c", "other", 25, "2026-11-22T10:00:00Z"))); }
        catch (IllegalArgumentException expected) { rejected = true; }
        check(rejected && engine.sortedRecords().isEmpty(), "Per-record foreign profile must be rejected");
        for (String timestamp : Arrays.asList("2026-11-22T10:00:00Z", "2026-11-22T10:00:00.000Z",
                "2026-11-22T07:00:00-03:00", "2026-11-22T10:00:00.123456789Z")) {
            PokedexUniversalEngine rawEngine = new PokedexUniversalEngine("primary");
            rawEngine.mergeRecords(Collections.singletonList(fixture("raw-id", "primary", 25, timestamp)));
            PokedexUniversalEngine.BackupBundle rawBackup = rawEngine.exportBackup();
            PokedexUniversalEngine restoredEngine = new PokedexUniversalEngine("primary");
            restoredEngine.restoreBackup(rawBackup);
            check(timestamp.equals(restoredEngine.sortedRecords().get(0).capturedAt)
                    && rawBackup.contentSha256.equals(restoredEngine.contentSha256()), "Raw valid ISO timestamp must preserve backup checksum");
        }
        rejected = false;
        try { fixture("bad|id", "primary", 25, "2026-11-22T10:00:00Z"); }
        catch (IllegalArgumentException expected) { rejected = true; }
        check(rejected, "Canonical hash delimiters must be rejected");
        rejected = false;
        try { fixture("id", "primary", 25, "not-a-date"); }
        catch (java.time.DateTimeException expected) { rejected = true; }
        check(rejected, "Invalid timestamp must be rejected before entering canonical hash");
        check(PokedexUniversalEngine.isEarlier(fixture("a", "primary", 25, "2026-11-22T10:00:00Z"),
                fixture("z", "primary", 25, "2026-11-22T10:00:00.000Z")),
                "Equal instants must tie-break by captureId independently of timestamp formatting");
    }

    public static void main(String[] args) {
        regressionMergeIsolationAndAtomicity();
        // 1. Validate Extension Manifest & iOS/Mobile native-only security policy
        BrumExtensionContract.ExtensionManifest manifest = BrumExtensionContract.pokedexManifest();
        check(BrumExtensionContract.POKEDEX_EXTENSION_ID.equals(manifest.id), "Extension ID must be brum.ext.pokedex");
        check(BrumExtensionContract.CODE_EXECUTION_POLICY_NATIVE_ONLY.equals(manifest.codeExecutionPolicy), "Must enforce native-compiled-only");

        boolean rejectedDynamicCode = false;
        try {
            new BrumExtensionContract.ExtensionManifest(
                    "brum.ext.pokedex", "001", 1, "1.0.0", "Pokédex", "Pokédex", "",
                    "remote-dynamic-code", true,
                    Collections.singletonList("brum-core:events.read"),
                    Collections.emptyList(),
                    Arrays.asList("pokemon", "shinies")
            ).validate();
        } catch (SecurityException expected) {
            rejectedDynamicCode = true;
        }
        check(rejectedDynamicCode, "Must reject arbitrary remote code execution");

        // 2. First capture permanence, duplicate rejection, normal & shiny independence
        PokedexUniversalEngine engine = new PokedexUniversalEngine("gusta");

        PokedexUniversalEngine.RecordOutcome cap1 = engine.recordCapture(
                25, false, "Pokémon FireRed Version", "firered-1", "gba",
                "2026-11-22T10:00:00Z", "Viridian Forest", "android-test"
        );
        check(cap1.recorded && !cap1.duplicate, "First Pikachu capture must record");
        check("Pikachu".equals(cap1.record.speciesName), "Dex 25 must resolve to Pikachu");
        check(cap1.notification != null && "025 — Pikachu".equals(cap1.notification.headline), "Must emit discovery notification");

        PokedexUniversalEngine.RecordOutcome cap2 = engine.recordCapture(
                25, false, "Pokémon Platinum Version", "plat-1", "nds",
                "2026-11-22T11:00:00Z", "Trophy Garden", "android-test"
        );
        check(!cap2.recorded && cap2.duplicate && cap2.notification == null, "Second normal Pikachu must not duplicate or notify");
        check("Pokémon FireRed Version".equals(cap2.record.firstCapturedGame), "Must preserve first capture game");

        PokedexUniversalEngine.RecordOutcome capShiny = engine.recordCapture(
                25, true, "Pokémon FireRed Version", "firered-1", "gba",
                "2026-11-22T12:00:00Z", "", "android-test"
        );
        check(capShiny.recorded && capShiny.record.isShiny, "Shiny Pikachu must record independently");
        check(PokedexUniversalEngine.UNKNOWN_LOCATION.equals(capShiny.record.captureLocation), "Empty location must fallback to Localização desconhecida");

        // 3. View projection and strict redaction of undiscovered species (#1 Bulbasaur)
        PokedexUniversalEngine.ProjectedView view = engine.projectView();
        check(view.normalDiscovered == 1, "Normal discovered count must be 1");
        check(view.shinyDiscovered == 1, "Shiny discovered count must be 1");
        check(view.pokemonTab.size() == 151, "Gen 1 enabled tab must have 151 entries");
        check(view.shiniesTab.size() == 1, "Shinies tab must list only discovered shinies");

        PokedexUniversalEngine.ProjectedEntry bulbasaur = view.pokemonTab.get(0);
        check(bulbasaur.nationalDexNumber == 1 && "001".equals(bulbasaur.formattedNumber), "National Dex number must be visible");
        check(!bulbasaur.discovered && bulbasaur.silhouetteOnly, "Undiscovered entry must be silhouetteOnly");
        check("???".equals(bulbasaur.name) && "???".equals(bulbasaur.description), "Undiscovered name and description must be ???");
        check(bulbasaur.capture == null, "Undiscovered capture info must be hidden");
        check("pokedex/silhouette/001".equals(bulbasaur.activeSpriteKey), "Undiscovered sprite must use silhouette key");

        // 4. Deterministic CRDT sync merge (earliest capture wins, cross-generation Starly #396 added)
        PokedexUniversalEngine.CaptureRecord starly = new PokedexUniversalEngine.CaptureRecord(
                null, "gusta", 396, 4, "Starly", "They flock in great numbers.",
                "normal", "Pokémon Platinum Version", "plat-1", "nds",
                "2026-11-22T09:30:00Z", "Route 201", "pc-windows"
        );
        PokedexUniversalEngine.CaptureRecord earlierPikachu = new PokedexUniversalEngine.CaptureRecord(
                null, "gusta", 25, 1, "Pikachu", "Mouse Pokémon",
                "normal", "Pokémon FireRed PC", "firered-pc", "gba",
                "2026-11-21T08:00:00Z", "Power Plant", "pc-windows"
        );
        PokedexUniversalEngine.MergeOutcome merged = engine.mergeRecords(Arrays.asList(starly, earlierPikachu));
        check(merged.addedCount == 1 && merged.replacedWithEarlierCount == 1 && merged.totalRecords == 3,
                "Merge must add Starly and keep earliest Pikachu capture");

        // 5. Full 809-species offline catalog (e.g. #16 Pidgey, #133 Eevee, #802 Marshadow .. #809 Melmetal), fractional ISO-8601 comparison, backup/restore & profile guard
        PokedexUniversalEngine.RecordOutcome pidgey = engine.recordCapture(
                16, false, "Pokémon FireRed Version", "firered-1", "gba",
                "2026-11-22T10:00:00Z", "Route 1", "android-test"
        );
        check(pidgey.recorded && "Pidgey".equals(pidgey.record.speciesName), "Dex 16 must resolve offline to Pidgey (full 809 catalog)");
        check(engine.getSpecies(133) != null && "Eevee".equals(engine.getSpecies(133).name), "Dex 133 must be Eevee");
        check(engine.getSpecies(802) != null && "Marshadow".equals(engine.getSpecies(802).name), "Dex 802 must be Marshadow");
        check(engine.getSpecies(803) != null && "Poipole".equals(engine.getSpecies(803).name), "Dex 803 must be Poipole");
        check(engine.getSpecies(809) != null && "Melmetal".equals(engine.getSpecies(809).name), "Dex 809 must be Melmetal");
        check(engine.projectView("all").pokemonTab.size() == 809, "All G1-G7 scope must list 809 entries");

        // Fractional timestamp .999Z is later than .000Z / Z -> must NOT replace earlier 10:00:00Z capture
        PokedexUniversalEngine.CaptureRecord laterFractionalPidgey = new PokedexUniversalEngine.CaptureRecord(
                "later-id", "gusta", 16, 1, "Pidgey", "Tiny Bird Pokémon",
                "normal", "Pokémon Platinum Version", "plat-1", "nds",
                "2026-11-22T10:00:00.999Z", "Route 229", "pc-windows"
        );
        PokedexUniversalEngine.MergeOutcome fracMerge = engine.mergeRecords(Collections.singletonList(laterFractionalPidgey), "gusta");
        check(fracMerge.replacedWithEarlierCount == 0 && fracMerge.preservedCount == 1,
                "Fractional .999Z timestamp must not overwrite earlier Z timestamp");

        // Profile mismatch must throw
        boolean rejectedWrongProfile = false;
        try {
            engine.mergeRecords(Collections.singletonList(laterFractionalPidgey), "other_profile");
        } catch (IllegalArgumentException expected) {
            rejectedWrongProfile = true;
        }
        check(rejectedWrongProfile, "Must reject sync merge for mismatched ownerProfileId");

        // Backup & restore with SHA-256 verification
        PokedexUniversalEngine.BackupBundle backup = engine.exportBackup();
        check(backup.recordCount == 4, "Backup must contain all 4 records");
        PokedexUniversalEngine freshEngine = new PokedexUniversalEngine("gusta");
        PokedexUniversalEngine.MergeOutcome restored = freshEngine.restoreBackup(backup);
        check(restored.totalRecords == 4 && backup.contentSha256.equals(restored.contentSha256),
                "Restored backup must match exact record count and canonical SHA-256");
    }
}

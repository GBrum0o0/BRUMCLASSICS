package com.brumclassics.mobile.extensions;

import java.util.Arrays;
import java.util.Collections;

public final class PokedexUniversalEngineTest {
    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("FAIL: " + message);
        }
    }

    public static void main(String[] args) {
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
    }
}

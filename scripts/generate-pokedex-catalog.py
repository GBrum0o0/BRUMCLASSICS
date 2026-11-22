#!/usr/bin/env python3
"""
Generates deterministic, versioned Pokédex Universal data files:
1. pokedex-species-catalog-v1.json (National Dex #001..#802, Gen 1..7 up to Sun & Moon)
   sourced from PokeAPI/pokeapi CSV tables (BSD-3-Clause).
2. pokedex-compatibility-v1.json (Separate Windows, iOS, and Android matrices).
3. Optional C++ lookup table dump for pret/pokefirered species -> National Dex and MAPSEC names.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import urllib.request
from pathlib import Path

POKEAPI_BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv"
POKEFIRERED_BASE = "https://raw.githubusercontent.com/pret/pokefirered/master"
MAX_NATIONAL_DEX = 802
MAX_GENERATION = 7


def fetch_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "BrumClassicsPokedexCatalogGenerator/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8")


def clean_flavor_text(raw: str) -> str:
    text = raw.replace("\f", " ").replace("\r", " ").replace("\n", " ").replace("\u00ad", "")
    text = re.sub(r"\s+", " ", text).strip()
    text = text.replace("POKéMON", "Pokémon").replace("POKEMON", "Pokémon")
    return text


def build_species_catalog() -> dict:
    species_csv = fetch_text(f"{POKEAPI_BASE}/pokemon_species.csv")
    names_csv = fetch_text(f"{POKEAPI_BASE}/pokemon_species_names.csv")
    flavor_csv = fetch_text(f"{POKEAPI_BASE}/pokemon_species_flavor_text.csv")

    species_meta: dict[int, dict] = {}
    for row in csv.DictReader(io.StringIO(species_csv)):
        dex_num = int(row["id"])
        if 1 <= dex_num <= MAX_NATIONAL_DEX:
            gen_id = int(row["generation_id"])
            species_meta[dex_num] = {
                "nationalDexNumber": dex_num,
                "generation": gen_id,
                "slug": row["identifier"].strip(),
                "isLegendary": row.get("is_legendary") == "1",
                "isMythical": row.get("is_mythical") == "1",
            }

    if len(species_meta) != MAX_NATIONAL_DEX:
        raise RuntimeError(f"Expected {MAX_NATIONAL_DEX} species, found {len(species_meta)}")

    # Language 9 = English official name & genus in PokeAPI
    names_en: dict[int, tuple[str, str]] = {}
    for row in csv.DictReader(io.StringIO(names_csv)):
        dex_num = int(row["pokemon_species_id"])
        lang_id = int(row["local_language_id"])
        if 1 <= dex_num <= MAX_NATIONAL_DEX and lang_id == 9:
            names_en[dex_num] = (row["name"].strip(), row.get("genus", "").strip())

    # Prefer FireRed (version_id=10) or LeafGreen (11) or Ruby/Sapphire/Emerald/Sun/Moon English (language_id=9) flavor text
    preferred_versions = {10: 0, 11: 1, 7: 2, 23: 3, 25: 4, 27: 5, 28: 6}
    flavors_en: dict[int, tuple[int, str]] = {}
    for row in csv.DictReader(io.StringIO(flavor_csv)):
        dex_num = int(row["species_id"])
        lang_id = int(row["language_id"])
        ver_id = int(row["version_id"])
        if 1 <= dex_num <= MAX_NATIONAL_DEX and lang_id == 9:
            cleaned = clean_flavor_text(row["flavor_text"])
            if not cleaned:
                continue
            rank = preferred_versions.get(ver_id, 100 + ver_id)
            prev = flavors_en.get(dex_num)
            if prev is None or rank < prev[0]:
                flavors_en[dex_num] = (rank, cleaned)

    entries = []
    for dex_num in range(1, MAX_NATIONAL_DEX + 1):
        meta = species_meta[dex_num]
        name, genus = names_en.get(dex_num, (meta["slug"].title(), "Pokémon"))
        description = flavors_en.get(dex_num, (999, f"{genus or 'Pokémon'} (#{dex_num:03d})."))[1]
        dex_code = f"{dex_num:03d}"
        entries.append(
            {
                "nationalDexNumber": dex_num,
                "generation": meta["generation"],
                "slug": meta["slug"],
                "name": name,
                "genus": genus or "Pokémon",
                "description": description,
                "isLegendary": meta["isLegendary"],
                "isMythical": meta["isMythical"],
                "spriteAsset": {
                    "normalKey": f"pokedex/normal/{dex_code}",
                    "shinyKey": f"pokedex/shiny/{dex_code}",
                    "silhouetteKey": f"pokedex/silhouette/{dex_code}",
                },
            }
        )

    return {
        "schemaVersion": 1,
        "catalogVersion": "1.0.0",
        "extensionId": "brum.ext.pokedex",
        "maxNationalDex": MAX_NATIONAL_DEX,
        "maxGeneration": MAX_GENERATION,
        "extensible": True,
        "source": {
            "provider": "PokeAPI/pokeapi",
            "license": "BSD-3-Clause",
            "repository": "https://github.com/PokeAPI/pokeapi",
            "generationsCovered": [
                {"generation": 1, "region": "Kanto", "minNationalDex": 1, "maxNationalDex": 151},
                {"generation": 2, "region": "Johto", "minNationalDex": 152, "maxNationalDex": 251},
                {"generation": 3, "region": "Hoenn", "minNationalDex": 252, "maxNationalDex": 386},
                {"generation": 4, "region": "Sinnoh", "minNationalDex": 387, "maxNationalDex": 493},
                {"generation": 5, "region": "Unova", "minNationalDex": 494, "maxNationalDex": 649},
                {"generation": 6, "region": "Kalos", "minNationalDex": 650, "maxNationalDex": 721},
                {"generation": 7, "region": "Alola (Sun & Moon)", "minNationalDex": 722, "maxNationalDex": 802},
            ],
        },
        "species": entries,
    }


def build_compatibility_matrix() -> dict:
    return {
        "schemaVersion": 1,
        "matrixVersion": "1.0.0",
        "extensionId": "brum.ext.pokedex",
        "schemaSupportedGenerations": [1, 2, 3, 4, 5, 6, 7],
        "maxNationalDexInSchema": MAX_NATIONAL_DEX,
        "rules": {
            "separatePlatforms": True,
            "corePresenceIsNotCompatibilityProof": True,
            "libraryPresenceIsNotCompatibilityProof": True,
            "windows3dsDoesNotImplyMobile3ds": True,
            "requireRealValidationBeforeEnabling": True,
        },
        "platforms": {
            "windows": {
                "platform": "windows",
                "enabledGenerations": [1],
                "pilotCaptureMaxNationalDex": 386,
                "native3dsAvailable": True,
                "games": [
                    {
                        "gameKey": "pokemon-firered-gba",
                        "title": "Pokémon FireRed Version",
                        "systemId": "gba",
                        "primaryGeneration": 1,
                        "engineGeneration": 3,
                        "supportedNationalDexRange": [1, 386],
                        "romCodes": ["BPRE"],
                        "supportedRevisions": [0, 1],
                        "backends": ["mgba_libretro.dll"],
                        "adapterId": "firered-gba-v1",
                        "adapterImplemented": True,
                        "automatedValidationStatus": "verified",
                        "realRomBootAndCaptureVerified": True,
                        "interactivePlaythroughPendingUser": True,
                        "status": "enabled_pilot",
                    },
                    {
                        "gameKey": "pokemon-red-gb",
                        "title": "Pokémon Red / Blue / Yellow",
                        "systemId": "gb",
                        "primaryGeneration": 1,
                        "engineGeneration": 1,
                        "supportedNationalDexRange": [1, 151],
                        "romCodes": [],
                        "backends": ["gambatte_libretro.dll", "sameboy_libretro.dll"],
                        "adapterId": "gen1-gb-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-crystal-gbc",
                        "title": "Pokémon Gold / Silver / Crystal",
                        "systemId": "gbc",
                        "primaryGeneration": 2,
                        "engineGeneration": 2,
                        "supportedNationalDexRange": [1, 251],
                        "romCodes": [],
                        "backends": ["gambatte_libretro.dll", "sameboy_libretro.dll"],
                        "adapterId": "gen2-gbc-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-emerald-gba",
                        "title": "Pokémon Ruby / Sapphire / Emerald / LeafGreen",
                        "systemId": "gba",
                        "primaryGeneration": 3,
                        "engineGeneration": 3,
                        "supportedNationalDexRange": [1, 386],
                        "romCodes": ["BPEE", "AXVE", "AXPE", "BPGE"],
                        "backends": ["mgba_libretro.dll"],
                        "adapterId": "gen3-gba-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-platinum-nds",
                        "title": "Pokémon Diamond / Pearl / Platinum / HeartGold / SoulSilver",
                        "systemId": "nds",
                        "primaryGeneration": 4,
                        "engineGeneration": 4,
                        "supportedNationalDexRange": [1, 493],
                        "romCodes": ["CPUE", "IPKE", "IPGE"],
                        "backends": ["melonds_libretro.dll"],
                        "adapterId": "gen4-nds-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-black2-nds",
                        "title": "Pokémon Black / White / Black 2 / White 2",
                        "systemId": "nds",
                        "primaryGeneration": 5,
                        "engineGeneration": 5,
                        "supportedNationalDexRange": [1, 649],
                        "romCodes": ["IRBO", "IRDO"],
                        "backends": ["melonds_libretro.dll"],
                        "adapterId": "gen5-nds-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-xy-oras-3ds",
                        "title": "Pokémon X / Y / Omega Ruby / Alpha Sapphire",
                        "systemId": "3ds",
                        "primaryGeneration": 6,
                        "engineGeneration": 6,
                        "supportedNationalDexRange": [1, 721],
                        "romCodes": [],
                        "backends": ["citra_libretro.dll"],
                        "adapterId": "gen6-3ds-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                    {
                        "gameKey": "pokemon-sun-moon-3ds",
                        "title": "Pokémon Sun / Moon",
                        "systemId": "3ds",
                        "primaryGeneration": 7,
                        "engineGeneration": 7,
                        "supportedNationalDexRange": [1, 802],
                        "romCodes": [],
                        "backends": ["citra_libretro.dll"],
                        "adapterId": "gen7-3ds-planned",
                        "adapterImplemented": False,
                        "automatedValidationStatus": "planned_phase_4",
                        "realRomBootAndCaptureVerified": False,
                        "status": "awaiting_adapter",
                    },
                ],
            },
            "ios": {
                "platform": "ios",
                "enabledGenerations": [1],
                "pilotCaptureMaxNationalDex": 386,
                "native3dsAvailable": False,
                "native3dsNote": "3DS no iOS requer build experimental sem JIT; não habilitado no canal pessoal estável.",
                "games": [
                    {
                        "gameKey": "pokemon-firered-gba",
                        "title": "Pokémon FireRed Version",
                        "systemId": "gba",
                        "primaryGeneration": 1,
                        "engineGeneration": 3,
                        "supportedNationalDexRange": [1, 386],
                        "romCodes": ["BPRE"],
                        "supportedRevisions": [0, 1],
                        "backends": ["mGBA arm64"],
                        "adapterId": "firered-gba-v1",
                        "adapterImplemented": True,
                        "automatedValidationStatus": "verified_ci_simulator",
                        "realRomBootAndCaptureVerified": False,
                        "deviceGameplayValidated": False,
                        "status": "enabled_pilot_pending_device_test",
                    }
                ],
            },
            "android": {
                "platform": "android",
                "enabledGenerations": [1],
                "pilotCaptureMaxNationalDex": 386,
                "native3dsAvailable": True,
                "native3dsNote": "Azahar ARM64 presente no Android, mas jogos Pokémon de 6ª/7ª geração aguardam adaptador dedicado e validação em aparelho físico.",
                "games": [
                    {
                        "gameKey": "pokemon-firered-gba",
                        "title": "Pokémon FireRed Version",
                        "systemId": "gba",
                        "primaryGeneration": 1,
                        "engineGeneration": 3,
                        "supportedNationalDexRange": [1, 386],
                        "romCodes": ["BPRE"],
                        "supportedRevisions": [0, 1],
                        "backends": ["libmgba_libretro.so"],
                        "adapterId": "firered-gba-v1",
                        "adapterImplemented": True,
                        "automatedValidationStatus": "verified_ci_unit",
                        "realRomBootAndCaptureVerified": False,
                        "deviceGameplayValidated": False,
                        "status": "enabled_pilot_pending_device_test",
                    }
                ],
            },
        },
    }


def extract_firered_tables() -> dict:
    species_h = fetch_text(f"{POKEFIRERED_BASE}/include/constants/species.h")
    pokedex_h = fetch_text(f"{POKEFIRERED_BASE}/include/constants/pokedex.h")
    mapsec_json = json.loads(fetch_text(f"{POKEFIRERED_BASE}/src/data/region_map/region_map_sections.json"))

    species_by_name: dict[str, int] = {}
    for line in species_h.splitlines():
        m = re.match(r"^#define\s+SPECIES_([A-Z0-9_]+)\s+(\d+)\b", line.strip())
        if m:
            species_by_name[m.group(1)] = int(m.group(2))

    nat_by_name: dict[str, int] = {}
    in_enum = False
    current_val = -1
    for line in pokedex_h.splitlines():
        s = line.strip()
        if s.startswith("enum") or "NATIONAL_DEX_NONE" in s:
            in_enum = True
        if not in_enum:
            continue
        m = re.match(r"^NATIONAL_DEX_([A-Z0-9_]+)(?:\s*=\s*(\d+))?\s*,?", s)
        if m:
            name = m.group(1)
            if m.group(2) is not None:
                current_val = int(m.group(2))
            else:
                current_val += 1
            nat_by_name[name] = current_val
        if s.startswith("};") and nat_by_name:
            break

    max_internal = 412  # SPECIES_CHIMECHO = 411, SPECIES_EGG = 412
    internal_to_nat = [0] * (max_internal + 1)
    for sp_name, sp_id in species_by_name.items():
        if 1 <= sp_id <= 411 and not sp_name.startswith("OLD_UNOWN_"):
            nat_id = nat_by_name.get(sp_name, 0)
            if 1 <= nat_id <= 386:
                internal_to_nat[sp_id] = nat_id

    def format_map_name(raw_name: str) -> str:
        raw_name = raw_name.strip()
        if not raw_name:
            return ""
        words = []
        for w in raw_name.split(" "):
            if w.upper() in ("S.S.", "MT."):
                words.append("S.S." if w.upper() == "S.S." else "Mt.")
            elif w.isdigit():
                words.append(w)
            else:
                words.append(w.capitalize())
        return " ".join(words)

    mapsec_list = mapsec_json.get("map_sections", [])
    locations = [""] * 256
    for idx, entry in enumerate(mapsec_list):
        if idx < 256:
            locations[idx] = format_map_name(entry.get("name", ""))
    locations[0xFD] = "Gift / Event"
    locations[0xFE] = "In-game Trade"
    locations[0xFF] = "Fateful Encounter"

    return {
        "internalToNational": internal_to_nat,
        "locations": locations,
        "mapsecCount": len(mapsec_list),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog-out", required=True, type=Path)
    parser.add_argument("--compat-out", required=True, type=Path)
    parser.add_argument("--firered-json-out", type=Path, default=None)
    args = parser.parse_args()

    catalog = build_species_catalog()
    compat = build_compatibility_matrix()

    args.catalog_out.parent.mkdir(parents=True, exist_ok=True)
    args.compat_out.parent.mkdir(parents=True, exist_ok=True)

    args.catalog_out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    args.compat_out.write_text(json.dumps(compat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.firered_json_out:
        fr = extract_firered_tables()
        args.firered_json_out.parent.mkdir(parents=True, exist_ok=True)
        args.firered_json_out.write_text(json.dumps(fr, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(
        json.dumps(
            {
                "ok": True,
                "speciesCount": len(catalog["species"]),
                "first": catalog["species"][0]["name"],
                "pikachu": catalog["species"][24]["name"],
                "last": catalog["species"][-1]["name"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()

#include "PokemonFireRedAdapter.hpp"

#include <array>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <vector>

namespace {

unsigned g_checks = 0;

void require(bool condition, const char *message) {
    ++g_checks;
    if (!condition) {
        std::cerr << "FAIL [" << g_checks << "]: " << message << "\n";
        std::exit(1);
    }
}

void writeU16LE(uint8_t *p, uint16_t v) {
    p[0] = static_cast<uint8_t>(v & 0xFFu);
    p[1] = static_cast<uint8_t>((v >> 8u) & 0xFFu);
}

void writeU32LE(uint8_t *p, uint32_t v) {
    p[0] = static_cast<uint8_t>(v & 0xFFu);
    p[1] = static_cast<uint8_t>((v >> 8u) & 0xFFu);
    p[2] = static_cast<uint8_t>((v >> 16u) & 0xFFu);
    p[3] = static_cast<uint8_t>((v >> 24u) & 0xFFu);
}

uint32_t readU32LE(const uint8_t *p) {
    return static_cast<uint32_t>(p[0]) |
           (static_cast<uint32_t>(p[1]) << 8u) |
           (static_cast<uint32_t>(p[2]) << 16u) |
           (static_cast<uint32_t>(p[3]) << 24u);
}

void setOwnedBit(uint8_t *owned52, uint16_t nationalDex) {
    const std::size_t bitIndex = static_cast<std::size_t>(nationalDex - 1u);
    owned52[bitIndex >> 3u] |= static_cast<uint8_t>(1u << (bitIndex & 7u));
}

uint16_t computeSectorChecksum(const uint8_t *data, uint16_t lengthBytes) {
    uint32_t sum = 0;
    const uint16_t wordCount = static_cast<uint16_t>(lengthBytes / 4u);
    for (uint16_t i = 0; i < wordCount; ++i) {
        sum += readU32LE(data + static_cast<std::size_t>(i) * 4u);
    }
    return static_cast<uint16_t>((sum & 0xFFFFu) + (sum >> 16u));
}

void buildSyntheticFireRedSaveSlot(uint8_t *slot56K,
                                   uint32_t saveCounter,
                                   uint32_t trainerId,
                                   const std::vector<uint16_t> &ownedDexList,
                                   const std::vector<std::array<uint8_t, 80>> &partyMons,
                                   const std::vector<std::pair<std::size_t, std::array<uint8_t, 80>>> &boxMons) {
    constexpr uint32_t kSectorSize = 0x1000u;
    constexpr uint32_t kSectorDataSize = 3968u;
    constexpr uint16_t kValidationSizes[14] = {
        3884u, 3968u, 3968u, 3968u, 3848u,
        3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 2000u
    };

    std::memset(slot56K, 0, 14u * kSectorSize);

    // Sector 0: SaveBlock2
    uint8_t *sb2 = slot56K + 0u * kSectorSize;
    sb2[0] = 0xCCu; // 'R' in Gen 3 charmap
    sb2[1] = 0xBFu; // 'E'
    sb2[2] = 0xBEu; // 'D'
    sb2[3] = 0xFFu;
    writeU32LE(sb2 + 0x00Au, trainerId);
    for (uint16_t dex : ownedDexList) {
        setOwnedBit(sb2 + 0x028u, dex);
    }

    // Sectors 1..4: SaveBlock1
    std::vector<uint8_t> sb1(4u * kSectorDataSize, 0u);
    sb1[0x0034u] = static_cast<uint8_t>(partyMons.size());
    for (std::size_t i = 0; i < partyMons.size() && i < 6u; ++i) {
        std::memcpy(sb1.data() + 0x0038u + i * 100u, partyMons[i].data(), 80u);
    }
    for (std::size_t s = 0; s < 4u; ++s) {
        std::memcpy(slot56K + (1u + s) * kSectorSize, sb1.data() + s * kSectorDataSize, kSectorDataSize);
    }

    // Sectors 5..13: PokemonStorage
    std::vector<uint8_t> storage(9u * kSectorDataSize, 0u);
    for (const auto &entry : boxMons) {
        const std::size_t offset = 0x0004u + entry.first * 80u;
        if (offset + 80u <= storage.size()) {
            std::memcpy(storage.data() + offset, entry.second.data(), 80u);
        }
    }
    for (std::size_t s = 0; s < 9u; ++s) {
        std::memcpy(slot56K + (5u + s) * kSectorSize, storage.data() + s * kSectorDataSize, kSectorDataSize);
    }

    // Write sector footers
    for (uint16_t secId = 0; secId < 14u; ++secId) {
        uint8_t *secPtr = slot56K + static_cast<std::size_t>(secId) * kSectorSize;
        writeU16LE(secPtr + 0xFF4u, secId);
        const uint16_t csum = computeSectorChecksum(secPtr, kValidationSizes[secId]);
        writeU16LE(secPtr + 0xFF6u, csum);
        writeU32LE(secPtr + 0xFF8u, 0x08012025u);
        writeU32LE(secPtr + 0xFFCu, saveCounter);
    }
}

} // namespace

int main() {
    using namespace brum::pokedex;

    // 1. ROM identification tests
    {
        std::vector<uint8_t> header(0xC0, 0u);
        std::memcpy(header.data() + 0xA0, "POKEMON FIRE", 12);
        std::memcpy(header.data() + 0xAC, "BPRE", 4);
        header[0xB2] = 0x96u;
        header[0xBC] = 0u;

        FireRedRomInfo info0 = identifyFireRedRom(header.data(), header.size());
        require(info0.isFireRed && info0.supportedRamLayout && info0.gameCode == "BPRE" && info0.revision == 0u,
                "Should identify FireRed BPRE v1.0");

        header[0xBC] = 1u;
        FireRedRomInfo info1 = identifyFireRedRom(header.data(), header.size());
        require(info1.isFireRed && info1.supportedRamLayout && info1.revision == 1u,
                "Should identify FireRed BPRE v1.1");

        std::memcpy(header.data() + 0xA0, "POKEMON EMER", 12);
        std::memcpy(header.data() + 0xAC, "BPEE", 4);
        FireRedRomInfo emerald = identifyFireRedRom(header.data(), header.size());
        require(!emerald.isFireRed && !emerald.supportedRamLayout,
                "Must not misidentify Emerald as FireRed");
    }

    // 2. Internal species -> National Dex mapping tests
    {
        require(internalSpeciesToNationalDex(0) == 0, "Species 0 -> 0");
        require(internalSpeciesToNationalDex(1) == 1, "Bulbasaur -> #1");
        require(internalSpeciesToNationalDex(4) == 4, "Charmander -> #4");
        require(internalSpeciesToNationalDex(25) == 25, "Pikachu -> #25");
        require(internalSpeciesToNationalDex(151) == 151, "Mew -> #151");
        require(internalSpeciesToNationalDex(251) == 251, "Celebi -> #251");
        for (uint16_t oldUnown = 252; oldUnown <= 276; ++oldUnown) {
            require(internalSpeciesToNationalDex(oldUnown) == 0, "Old Unown slots 252..276 must return 0");
        }
        require(internalSpeciesToNationalDex(277) == 252, "Treecko (277) -> #252");
        require(internalSpeciesToNationalDex(410) == 386, "Deoxys (410) -> #386");
        require(internalSpeciesToNationalDex(411) == 358, "Chimecho (411) -> #358");
        require(internalSpeciesToNationalDex(412) == 0, "Egg (412) -> 0");
    }

    // 3. Location lookup & fallback
    {
        require(fireRedLocationName(0x58) == "Pallet Town", "0x58 -> Pallet Town");
        require(fireRedLocationName(0x59) == "Viridian City", "0x59 -> Viridian City");
        require(fireRedLocationName(0x65) == "Route 1", "0x65 -> Route 1");
        require(fireRedLocationName(0x7F) == "Mt. Moon", "0x7F -> Mt. Moon");
        require(fireRedLocationName(0xFE) == "In-game Trade", "0xFE -> In-game Trade");
        require(fireRedLocationName(0xDF) == "Localização desconhecida", "Unmapped location must fallback safely");
    }

    // 4. All 24 substructure permutations + shiny boundary + egg/badEgg/corrupt rejection
    {
        const uint32_t otId = 0x12345678u; // tid=0x5678, sid=0x1234 -> tid^sid = 0x444C
        for (uint32_t mod = 0; mod < 24u; ++mod) {
            const uint32_t pid = 240000u + mod;
            require((pid % 24u) == mod, "PID permutation check");
            uint8_t raw[80]{};
            encodeBoxPokemonForTest(raw, pid, otId, 277u /* Treecko -> #252 */, 0x65u /* Route 1 */);
            DecodedGen3Pokemon d = decodeBoxPokemon(raw);
            require(d.valid && d.nationalDexNumber == 252u && d.metLocationName == "Route 1",
                    "Should decode valid BoxPokemon for every permutation 0..23");
        }

        // Exact shiny boundaries: shinyVal = tid ^ sid ^ pidLo ^ pidHi
        // With otId = 0x00000000, shinyVal = pidLo ^ pidHi
        uint8_t rawShiny[80]{};
        encodeBoxPokemonForTest(rawShiny, 0x00000007u /* xor = 7 < 8 -> shiny */, 0u, 25u, 0x58u);
        DecodedGen3Pokemon dShiny = decodeBoxPokemon(rawShiny);
        require(dShiny.valid && dShiny.isShiny && dShiny.nationalDexNumber == 25u, "shinyVal=7 must be shiny");

        uint8_t rawNormal[80]{};
        encodeBoxPokemonForTest(rawNormal, 0x00000008u /* xor = 8 >= 8 -> normal */, 0u, 25u, 0x58u);
        DecodedGen3Pokemon dNormal = decodeBoxPokemon(rawNormal);
        require(dNormal.valid && !dNormal.isShiny && dNormal.nationalDexNumber == 25u, "shinyVal=8 must be normal");

        uint8_t rawEgg[80]{};
        encodeBoxPokemonForTest(rawEgg, 0x11223344u, otId, 25u, 0x58u, /*isEgg=*/true);
        require(!decodeBoxPokemon(rawEgg).valid, "Egg must not decode as captured species");

        uint8_t rawBadEgg[80]{};
        encodeBoxPokemonForTest(rawBadEgg, 0x11223344u, otId, 25u, 0x58u, false, /*isBadEgg=*/true);
        require(!decodeBoxPokemon(rawBadEgg).valid, "Bad egg must be rejected");

        uint8_t rawCorrupt[80]{};
        encodeBoxPokemonForTest(rawCorrupt, 0x11223344u, otId, 25u, 0x58u, false, false, /*corruptChecksum=*/true);
        require(!decodeBoxPokemon(rawCorrupt).valid, "Corrupted checksum must be rejected");
    }

    // 5. Live RAM FireRedCaptureTracker state machine tests
    {
        std::vector<uint8_t> ewram(0x40000u, 0u);
        std::vector<uint8_t> iwram(0x8000u, 0u);

        constexpr uint32_t kSb2Offset = 0x03B000u;     // EWRAM 0x0203B000
        constexpr uint32_t kStorageOffset = 0x029000u; // EWRAM 0x02029000
        writeU32LE(iwram.data() + 0x500Cu, 0x02000000u + kSb2Offset);
        writeU32LE(iwram.data() + 0x5010u, 0x02000000u + kStorageOffset);

        // Initialize active trainer in SaveBlock2 with Charmander (#4) already in party on load
        uint8_t *sb2 = ewram.data() + kSb2Offset;
        sb2[0] = 0xCCu; // playerName[0] != 0 and != 0xFF
        const uint32_t trainerId = 0x00420099u;
        writeU32LE(sb2 + 0x00Au, trainerId);
        setOwnedBit(sb2 + 0x028u, 4u); // Charmander owned

        ewram[0x024029u] = 1u; // gPlayerPartyCount = 1
        encodeBoxPokemonForTest(ewram.data() + 0x024284u, 0xAABBCC01u, trainerId, 4u /* Charmander */, 0x58u /* Pallet Town */);

        // Also populate enemy party (0x0202402C) & pokedex.seen (sb2 + 0x05C) with Mewtwo (#150) & Pidgey (#16)
        setOwnedBit(sb2 + 0x05Cu, 150u); // seen bit for Mewtwo
        setOwnedBit(sb2 + 0x05Cu, 16u);  // seen bit for Pidgey
        encodeBoxPokemonForTest(ewram.data() + 0x02402Cu, 0xDEAD1500u, 0x99999999u, 150u /* Mewtwo */, 0x65u);

        std::vector<GbaMemoryDescriptor> descs = {
            {ewram.data(), 0x02000000u, ewram.size()},
            {iwram.data(), 0x03000000u, iwram.size()},
        };
        FireRedRomInfo romInfo{true, true, "POKEMON FIRE", "BPRE", 0};

        std::vector<FireRedCaptureEvent> events;
        FireRedCaptureTracker tracker(
            romInfo,
            makeDescriptorBusReader(descs),
            [&](const FireRedCaptureEvent &ev) { events.push_back(ev); },
            /*scanIntervalFrames=*/1);

        // First 2 frames anchor baseline (existing Charmander must NOT emit a capture; enemy Mewtwo & seen Pidgey must NOT emit)
        tracker.doFrame();
        tracker.doFrame();
        require(tracker.isBaselineAnchored(), "Baseline must anchor after 2 stable frames");
        require(events.empty(), "Existing save Pokémon, enemy battle Pokémon, and seen-only species must emit 0 captures");

        // Now simulate catching normal Pikachu (#25) in Viridian Forest (0x8D = Viridian Forest in FireRed MAPSEC)
        // Wait: first test that if Pikachu is in party WITHOUT pokedex.owned bit set yet, it is NOT emitted prematurely
        ewram[0x024029u] = 2u;
        encodeBoxPokemonForTest(ewram.data() + 0x024284u + 100u, 0x00000008u /* normal */, 0u, 25u /* Pikachu */, 0x65u /* Route 1 */);
        tracker.doFrame();
        tracker.doFrame();
        require(events.empty(), "Party struct without pokedex.owned bit must not trigger capture");

        // Now game sets pokedex.owned bit for Pikachu (#25)
        setOwnedBit(sb2 + 0x028u, 25u);
        tracker.doFrame();
        require(events.empty(), "Single scan must wait for debounce stability (2 scans)");
        tracker.doFrame();
        require(events.size() == 1u, "Second stable scan must confirm Pikachu capture");
        require(events[0].nationalDexNumber == 25u && !events[0].isShiny &&
                    events[0].metLocationName == "Route 1" && events[0].storageSource == "party",
                "Captured Pikachu metadata must match exact species, normal category, location, and party source");

        // Running additional frames must NOT re-emit the same Pikachu
        tracker.doFrame();
        tracker.doFrame();
        require(events.size() == 1u, "Same Pikachu instance must never re-emit");

        // Now simulate catching a SHINY Pikachu sent directly to PC Box 1 Slot 0 (e.g. when party is full)
        encodeBoxPokemonForTest(ewram.data() + kStorageOffset + 0x0004u,
                                0x00000003u /* shinyVal = 3 < 8 -> shiny */,
                                0u,
                                25u /* Pikachu */,
                                0xDFu /* unknown location -> fallback */);
        tracker.doFrame();
        tracker.doFrame();
        require(events.size() == 2u, "Shiny Pikachu in PC Box must be detected");
        require(events[1].nationalDexNumber == 25u && events[1].isShiny &&
                    events[1].storageSource == "pc_box" &&
                    events[1].metLocationName == "Localização desconhecida",
                "Shiny PC Box Pikachu must report shiny=true, pc_box, and unknown location fallback");
    }

    // Incomplete RAM snapshots must neither anchor old captures nor bridge debounce gaps.
    {
        std::vector<uint8_t> ewram(0x40000u, 0u), iwram(0x8000u, 0u);
        const uint32_t sb = 0x3B000u, storage = 0x29000u;
        writeU32LE(iwram.data() + 0x500Cu, 0x02000000u + sb);
        writeU32LE(iwram.data() + 0x5010u, 0x02000000u + storage);
        ewram[sb] = 0xCCu;
        writeU32LE(ewram.data() + sb + 0xAu, 0x00420099u);
        setOwnedBit(ewram.data() + sb + 0x28u, 25u);
        encodeBoxPokemonForTest(ewram.data() + storage + 4u, 8u, 0u, 25u, 0x65u);
        auto read = makeDescriptorBusReader({{ewram.data(), 0x02000000u, ewram.size()},
                                           {iwram.data(), 0x03000000u, iwram.size()}});
        bool failBoxes = true;
        int events = 0;
        FireRedCaptureTracker tracker({true, true, "POKEMON FIRE", "BPRE", 0},
            [&](uint32_t address, uint8_t *out, std::size_t size) {
                return !(failBoxes && address == 0x02000000u + storage + 4u) && read(address, out, size);
            }, [&](const FireRedCaptureEvent &) { ++events; }, 1u);
        tracker.doFrame(); tracker.doFrame();
        require(!tracker.isBaselineAnchored(), "Incomplete box snapshot must not anchor baseline");
        failBoxes = false;
        tracker.doFrame(); tracker.doFrame();
        require(tracker.isBaselineAnchored() && events == 0, "Recovered old box must baseline without discoveries");
        encodeBoxPokemonForTest(ewram.data() + storage + 84u, 9u, 0u, 25u, 0x65u);
        tracker.doFrame();
        failBoxes = true; tracker.doFrame(); failBoxes = false;
        tracker.doFrame();
        require(events == 0, "Read failure must interrupt candidate debounce");
        tracker.doFrame();
        require(events == 1, "Two complete scans after read recovery confirm new capture");
    }

    // 6. 128KB Flash Save inspection & save-diff tests
    {
        const uint32_t trainerId = 0xCAFE1234u;
        std::array<uint8_t, 80> charmander{};
        encodeBoxPokemonForTest(charmander.data(), 0x10101010u, trainerId, 4u, 0x58u);

        std::array<uint8_t, 80> pikachuNormal{};
        encodeBoxPokemonForTest(pikachuNormal.data(), 0x00000008u, 0u, 25u, 0x65u);

        std::array<uint8_t, 80> pikachuShiny{};
        encodeBoxPokemonForTest(pikachuShiny.data(), 0x00000002u, 0u, 25u, 0x7Fu);

        std::vector<uint8_t> saveBefore(0x20000u, 0xFFu);
        buildSyntheticFireRedSaveSlot(saveBefore.data(),
                                      /*saveCounter=*/1u,
                                      trainerId,
                                      {4u},
                                      {charmander},
                                      {});

        FireRedSaveSnapshot snapBefore = inspectFireRedSave128K(saveBefore.data(), saveBefore.size());
        require(snapBefore.valid && snapBefore.saveCounter == 1u && snapBefore.partyPokemon.size() == 1u,
                "Should parse Slot A (counter=1) with Charmander");

        // Write newer save (counter=2) into Slot B (offset 14 * 0x1000 = 0xE000) with Pikachu in party & shiny Pikachu in box
        std::vector<uint8_t> saveAfter = saveBefore;
        buildSyntheticFireRedSaveSlot(saveAfter.data() + 14u * 0x1000u,
                                      /*saveCounter=*/2u,
                                      trainerId,
                                      {4u, 25u},
                                      {charmander, pikachuNormal},
                                      {{5u, pikachuShiny}});

        FireRedSaveSnapshot snapAfter = inspectFireRedSave128K(saveAfter.data(), saveAfter.size());
        require(snapAfter.valid && snapAfter.activeSlot == 1u && snapAfter.saveCounter == 2u &&
                    snapAfter.partyPokemon.size() == 2u && snapAfter.boxPokemon.size() == 1u,
                "Should select newer Slot B (counter=2) with 2 party Pokémon and 1 box Pokémon");

        auto diff = diffFireRedSaveSnapshots(snapBefore, snapAfter, "BPRE", 0u);
        require(diff.size() == 2u, "Diff between saveBefore and saveAfter must yield 2 newly captured Pikachu instances");
        require(diff[0].nationalDexNumber == 25u && !diff[0].isShiny && diff[0].storageSource == "party",
                "First diff event must be normal party Pikachu");
        require(diff[1].nationalDexNumber == 25u && diff[1].isShiny && diff[1].storageSource == "pc_box" &&
                    diff[1].metLocationName == "Mt. Moon",
                "Second diff event must be shiny box Pikachu at Mt. Moon");
    }

    std::cout << "pokedex_tests passed (" << g_checks << " checks)\n";
    return 0;
}

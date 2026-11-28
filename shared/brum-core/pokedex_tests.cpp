#include "PokemonFireRedAdapter.hpp"
#include "PokemonPlatinumAdapter.hpp"

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

    // 5b. Pre-Pokédex starter & Evolution (Normal and Shiny independence) FireRed tests
    {
        std::vector<uint8_t> ewram(0x40000u, 0u);
        std::vector<uint8_t> iwram(0x8000u, 0u);

        constexpr uint32_t kSb2Offset = 0x03B000u;
        constexpr uint32_t kStorageOffset = 0x029000u;
        writeU32LE(iwram.data() + 0x500Cu, 0x02000000u + kSb2Offset);
        writeU32LE(iwram.data() + 0x5010u, 0x02000000u + kStorageOffset);

        uint8_t *sb2 = ewram.data() + kSb2Offset;
        sb2[0] = 0xCCu; // Valid player name after New Game start
        const uint32_t trainerId = 0x00123456u;
        writeU32LE(sb2 + 0x00Au, trainerId);
        ewram[0x024029u] = 0u; // Before choosing starter in Oak's Lab

        // Also test non-zero descriptor offset in makeDescriptorBusReader
        std::vector<uint8_t> prefixedEwram(0x100u + ewram.size(), 0u);
        std::vector<GbaMemoryDescriptor> offsetDescs = {
            {prefixedEwram.data(), 0x02000000u, ewram.size(), 0x100u},
            {iwram.data(), 0x03000000u, iwram.size(), 0u},
        };
        auto syncEwram = [&]() {
            std::memcpy(prefixedEwram.data() + 0x100u, ewram.data(), ewram.size());
        };
        syncEwram();

        std::vector<FireRedCaptureEvent> starterEvents;
        FireRedCaptureTracker tracker(
            {true, true, "POKEMON FIRE", "BPRE", 0},
            makeDescriptorBusReader(offsetDescs),
            [&](const FireRedCaptureEvent &ev) { starterEvents.push_back(ev); },
            1u);

        // Baseline anchors with empty party while owned52 is all zero
        tracker.doFrame();
        tracker.doFrame();
        require(tracker.isBaselineAnchored(), "New Game baseline must anchor cleanly with 0 party Pokemon");
        require(starterEvents.empty(), "Empty New Game party must emit 0 events");

        // Foreign OT in pre-Pokédex phase without owned bit must be ignored
        ewram[0x024029u] = 1u;
        encodeBoxPokemonForTest(ewram.data() + 0x024284u, 0x00000008u, 0x99999999u, 150u /* Mewtwo */, 0x58u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.empty(), "Foreign OT mon without pokedex.owned bit must never trigger capture");

        // Player chooses Squirtle (#007) in Oak's Lab BEFORE receiving the Pokédex (owned52 still all 0!)
        const uint32_t squirtlePid = 0x10200008u; // 0x1020 ^ 0x0008 = 0x1028; with trainerId 0x00123456 -> normal
        encodeBoxPokemonForTest(ewram.data() + 0x024284u, squirtlePid, trainerId, 7u /* Squirtle */, 0x58u /* Pallet Town */);
        syncEwram();
        tracker.doFrame();
        require(starterEvents.empty(), "Starter waits for 2-scan stability");
        tracker.doFrame();
        require(starterEvents.size() == 1u && starterEvents[0].nationalDexNumber == 7u &&
                    !starterEvents[0].isShiny && starterEvents[0].metLocationName == "Pallet Town",
                "Normal Squirtle starter must be detected immediately before receiving Pokedex");

        // Receiving the Pokédex later and setting owned bit #007 must NOT duplicate Squirtle
        setOwnedBit(sb2 + 0x028u, 7u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.size() == 1u, "Setting owned bit after pre-Pokedex starter must never duplicate");

        // Catch Normal Pidgey (#016) -> then evolve same PID/OT into Normal Pidgeotto (#017)
        const uint32_t pidgeyPid = 0x20000008u; // (tid^sid = 0x3444) ^ (0x2000^0x0008) >= 8 -> normal
        ewram[0x024029u] = 2u;
        encodeBoxPokemonForTest(ewram.data() + 0x024284u + 100u, pidgeyPid, trainerId, 16u /* Pidgey */, 0x65u /* Route 1 */);
        setOwnedBit(sb2 + 0x028u, 16u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.size() == 2u && starterEvents[1].nationalDexNumber == 16u && !starterEvents[1].isShiny,
                "Captured normal Pidgey must be detected");

        // Evolve Pidgey -> Pidgeotto (same PID/OT, species becomes 17, owned bit 17 set)
        encodeBoxPokemonForTest(ewram.data() + 0x024284u + 100u, pidgeyPid, trainerId, 17u /* Pidgeotto */, 0x65u /* Route 1 */);
        setOwnedBit(sb2 + 0x028u, 17u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.size() == 3u && starterEvents[2].nationalDexNumber == 17u && !starterEvents[2].isShiny,
                "Evolving Pidgey into Pidgeotto (same PID/OT, new species) must detect Pidgeotto");

        // Catch Shiny Rattata (#019) -> evolve same shiny PID/OT into Shiny Raticate (#020)
        // Compute shiny PID matching trainerId: tid^sid = 0x0012 ^ 0x3456 = 0x3444 -> pid = 0x00003444 makes xor == 0 < 8
        const uint32_t shinyPid = (trainerId & 0xFFFFu) ^ ((trainerId >> 16u) & 0xFFFFu);
        ewram[0x024029u] = 3u;
        encodeBoxPokemonForTest(ewram.data() + 0x024284u + 200u, shinyPid, trainerId, 19u /* Rattata */, 0x65u);
        setOwnedBit(sb2 + 0x028u, 19u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.size() == 4u && starterEvents[3].nationalDexNumber == 19u && starterEvents[3].isShiny,
                "Shiny Rattata capture must be detected with isShiny=true");

        encodeBoxPokemonForTest(ewram.data() + 0x024284u + 200u, shinyPid, trainerId, 20u /* Raticate */, 0x65u);
        setOwnedBit(sb2 + 0x028u, 20u);
        syncEwram();
        tracker.doFrame();
        tracker.doFrame();
        require(starterEvents.size() == 5u && starterEvents[4].nationalDexNumber == 20u && starterEvents[4].isShiny,
                "Shiny Rattata evolving into Shiny Raticate must detect Raticate with isShiny=true");

        // Verify save inspection & diff also support pre-Pokédex Squirtle starter
        std::array<uint8_t, 80> squirtleRaw{};
        encodeBoxPokemonForTest(squirtleRaw.data(), squirtlePid, trainerId, 7u, 0x58u);
        std::vector<uint8_t> saveEmpty(0x20000u, 0xFFu);
        buildSyntheticFireRedSaveSlot(saveEmpty.data(), 1u, trainerId, {}, {}, {});
        std::vector<uint8_t> saveWithStarter(0x20000u, 0xFFu);
        buildSyntheticFireRedSaveSlot(saveWithStarter.data(), 2u, trainerId, {}, {squirtleRaw}, {});
        auto emptySnap = inspectFireRedSave128K(saveEmpty.data(), saveEmpty.size());
        auto starterSnap = inspectFireRedSave128K(saveWithStarter.data(), saveWithStarter.size());
        auto starterDiff = diffFireRedSaveSnapshots(emptySnap, starterSnap, "BPRE", 0u);
        require(starterDiff.size() == 1u && starterDiff[0].nationalDexNumber == 7u && !starterDiff[0].isShiny,
                "Pre-Pokedex starter must also be detected across 128K save snapshots");
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

    // 7. Pokémon Platinum (CPUE) Gen 4 Adapter Tests
    {
        std::vector<uint8_t> platRom(0x200u, 0u);
        std::memcpy(platRom.data(), "POKEMON PL\0\0", 12u);
        std::memcpy(platRom.data() + 0x0Cu, "CPUE", 4u);
        platRom[0x1Eu] = 1u;
        PlatinumRomInfo platInfo = identifyPlatinumRom(platRom.data(), platRom.size());
        require(platInfo.isPlatinum && platInfo.supportedRamLayout &&
                    platInfo.gameCode == "CPUE" && platInfo.revision == 1u,
                "identifyPlatinumRom must recognize CPUE header");

        std::vector<uint8_t> wrongNdsRom = platRom;
        std::memcpy(wrongNdsRom.data() + 0x0Cu, "ADAE", 4u);
        PlatinumRomInfo diamondInfo = identifyPlatinumRom(wrongNdsRom.data(), wrongNdsRom.size());
        require(!diamondInfo.isPlatinum && !diamondInfo.supportedRamLayout,
                "identifyPlatinumRom must reject non-CPUE NDS ROMs");

        // Verify Gen 4 PRNG decryption across all 24 block permutations
        const uint32_t platOtId = 0x12345678u;
        for (uint32_t perm = 0u; perm < 24u; ++perm) {
            const uint32_t pid = (perm << 13u) | 0x0001u;
            uint8_t raw136[136]{};
            encodeGen4PokemonForTest(raw136, pid, platOtId, static_cast<uint16_t>(396u + (perm % 10u)), 16u /* Route 201 */);
            DecodedGen4Pokemon dec = decodeGen4Pokemon(raw136);
            require(dec.valid && dec.nationalDexNumber == static_cast<uint16_t>(396u + (perm % 10u)) &&
                        dec.metLocationName == "Route 201" && !dec.isEgg,
                    "Gen 4 136-byte decryption must unshuffle all 24 permutations cleanly");
        }

        // Gen 4 shiny vs corrupt vs out-of-range vs egg
        {
            uint8_t shinyRaw[136]{};
            encodeGen4PokemonForTest(shinyRaw, 0x00020000u, 0x00000001u, 487u /* Giratina */, 85u /* Distortion World */);
            DecodedGen4Pokemon shinyDec = decodeGen4Pokemon(shinyRaw);
            require(shinyDec.valid && shinyDec.isShiny && shinyDec.nationalDexNumber == 487u &&
                        shinyDec.metLocationName == "Distortion World",
                    "Gen 4 shiny Giratina in Distortion World must decode accurately");

            uint8_t eggRaw[136]{};
            encodeGen4PokemonForTest(eggRaw, 0x00100008u, 0u, 175u, 4u, /*isEgg=*/true);
            DecodedGen4Pokemon eggDec = decodeGen4Pokemon(eggRaw);
            require(eggDec.valid && eggDec.isEgg, "Gen 4 egg flag must be identified");

            uint8_t badSum[136]{};
            encodeGen4PokemonForTest(badSum, 0x00100008u, 0u, 396u, 16u, false, /*corruptChecksum=*/true);
            require(!decodeGen4Pokemon(badSum).valid, "Corrupted Gen 4 checksum must be rejected");

            uint8_t badSpecies[136]{};
            encodeGen4PokemonForTest(badSpecies, 0x00100008u, 0u, 650u /* > 493 */, 16u);
            require(!decodeGen4Pokemon(badSpecies).valid, "Gen 4 species > 493 must be rejected");
        }

        // Live PlatinumCaptureTracker tests (3-frame stability, baseline suppression, boot/corrupt RAM ignored, wrong game rejected)
        {
            std::vector<uint8_t> ndsRam(0x400000u, 0u);
            constexpr uint32_t kSaveOffset = 0x120000u; // 0x02120000 in 4 MiB NDS Main RAM
            PlatinumRamLayout layout;
            std::vector<NdsMemoryDescriptor> descs = {{ndsRam.data(), 0x02000000u, ndsRam.size()}};
            std::vector<PlatinumCaptureEvent> platEvents;

            // Wrong ROM tracker must ignore identical RAM cleanly
            PlatinumCaptureTracker wrongTracker(diamondInfo, makeNdsDescriptorBusReader(descs),
                                                [&](const PlatinumCaptureEvent &ev) { platEvents.push_back(ev); }, 1u, layout);
            wrongTracker.doFrame();
            require(!wrongTracker.isBaselineAnchored() && platEvents.empty(),
                    "Wrong game code tracker must do nothing");

            PlatinumCaptureTracker platTracker(platInfo, makeNdsDescriptorBusReader(descs),
                                               [&](const PlatinumCaptureEvent &ev) { platEvents.push_back(ev); }, 1u, layout);

            // Corrupt / zero boot RAM must never crash or anchor baseline
            platTracker.doFrame();
            platTracker.doFrame();
            platTracker.doFrame();
            require(!platTracker.isBaselineAnchored() && platEvents.empty(),
                    "Zero/boot RAM must not anchor baseline");

            // Initialize valid SaveData pointer + starter Chimchar (#390) in Party Slot 0
            writeU32LE(ndsRam.data() + (layout.saveBlockPtrAddress - 0x02000000u), 0x02000000u + kSaveOffset);
            writeU32LE(ndsRam.data() + kSaveOffset + layout.partyCountOffset, 1u);
            encodeGen4PokemonForTest(ndsRam.data() + kSaveOffset + layout.partyArrayOffset,
                                     0x00000020u, platOtId, 390u /* Chimchar */, 46u /* Lake Verity */);

            platTracker.doFrame();
            platTracker.doFrame();
            require(!platTracker.isBaselineAnchored(), "Platinum baseline requires 3 stable scans");
            platTracker.doFrame();
            require(platTracker.isBaselineAnchored() && platEvents.empty(),
                    "Platinum baseline must anchor on 3rd stable scan without emitting starter");

            // Catch Starly (#396) in Route 201 into Party Slot 1 -> requires 3 stable frames
            writeU32LE(ndsRam.data() + kSaveOffset + layout.partyCountOffset, 2u);
            encodeGen4PokemonForTest(ndsRam.data() + kSaveOffset + layout.partyArrayOffset + 236u,
                                     0x00000020u, 0u, 396u /* Starly */, 16u /* Route 201 */);
            platTracker.doFrame();
            platTracker.doFrame();
            require(platEvents.empty(), "Starly capture must wait for 3rd stable scan");
            platTracker.doFrame();
            require(platEvents.size() == 1u && platEvents[0].nationalDexNumber == 396u &&
                        !platEvents[0].isShiny && platEvents[0].metLocationName == "Route 201" &&
                        platEvents[0].storageSource == "party" && platEvents[0].gameCode == "CPUE",
                    "Starly capture must emit cleanly on 3rd stable scan");

            // Corrupt Slot 1 checksum mid-play -> scan aborts safely without duplicate/crash
            encodeGen4PokemonForTest(ndsRam.data() + kSaveOffset + layout.partyArrayOffset + 236u,
                                     0x00000020u, 0u, 396u, 16u, false, /*corruptChecksum=*/true);
            platTracker.doFrame();
            require(platEvents.size() == 1u, "Corrupt RAM mid-session must be ignored safely");

            // Restore Starly & place shiny Shinx (#403) in PC Box 0 -> emits after 3 stable scans
            encodeGen4PokemonForTest(ndsRam.data() + kSaveOffset + layout.partyArrayOffset + 236u,
                                     0x00000020u, 0u, 396u, 16u);
            encodeGen4PokemonForTest(ndsRam.data() + kSaveOffset + layout.boxStorageOffset,
                                     0x00020000u, 0x00000001u, 403u /* Shinx */, 17u /* Route 202 */);
            platTracker.doFrame();
            platTracker.doFrame();
            require(platEvents.size() == 1u, "PC Box shiny Shinx waits 3 frames");
            platTracker.doFrame();
            require(platEvents.size() == 2u && platEvents[1].nationalDexNumber == 403u &&
                        platEvents[1].isShiny && platEvents[1].metLocationName == "Route 202" &&
                        platEvents[1].storageSource == "pc_box",
                    "Shiny PC Box Shinx must be detected after 3 stable scans");
        }
    }

    std::cout << "pokedex_tests passed (" << g_checks << " checks)\n";
    return 0;
}

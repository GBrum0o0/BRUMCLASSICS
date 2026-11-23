#include "PokemonFireRedAdapter.hpp"

#include <algorithm>
#include <cstring>

namespace brum {
namespace pokedex {

namespace {

constexpr uint32_t kEwramStart = 0x02000000u;
constexpr uint32_t kEwramEnd = 0x02040000u;
constexpr uint32_t kIwramSaveBlock2Ptr = 0x0300500Cu;
constexpr uint32_t kIwramPokemonStoragePtr = 0x03005010u;
constexpr uint32_t kEwramPlayerPartyCount = 0x02024029u;
constexpr uint32_t kEwramPlayerParty = 0x02024284u;

constexpr uint32_t kSaveBlock2TrainerIdOffset = 0x00Au;
constexpr uint32_t kSaveBlock2PokedexOwnedOffset = 0x028u;
constexpr uint32_t kSaveBlock2MinSize = 0x090u;

constexpr uint32_t kSaveBlock1PartyCountOffset = 0x0034u;
constexpr uint32_t kSaveBlock1PartyOffset = 0x0038u;

constexpr uint32_t kPokemonStorageBoxesOffset = 0x0004u;
constexpr uint32_t kTotalBoxesCount = 14u;
constexpr uint32_t kInBoxCount = 30u;
constexpr uint32_t kBoxPokemonSize = 80u;
constexpr uint32_t kPartyPokemonSize = 100u;
constexpr uint32_t kPokemonStorageBoxesBytes = kTotalBoxesCount * kInBoxCount * kBoxPokemonSize;

constexpr uint32_t kSectorSize = 0x1000u;
constexpr uint32_t kSectorDataSize = 3968u;
constexpr uint32_t kSectorsPerSlot = 14u;
constexpr uint32_t kSectorSignature = 0x08012025u;

constexpr const char *kUnknownLocationLabel = "Localização desconhecida";

inline uint16_t readU16LE(const uint8_t *p) {
    return static_cast<uint16_t>(static_cast<uint16_t>(p[0]) |
                                 (static_cast<uint16_t>(p[1]) << 8u));
}

inline uint32_t readU32LE(const uint8_t *p) {
    return static_cast<uint32_t>(p[0]) |
           (static_cast<uint32_t>(p[1]) << 8u) |
           (static_cast<uint32_t>(p[2]) << 16u) |
           (static_cast<uint32_t>(p[3]) << 24u);
}

inline void writeU16LE(uint8_t *p, uint16_t v) {
    p[0] = static_cast<uint8_t>(v & 0xFFu);
    p[1] = static_cast<uint8_t>((v >> 8u) & 0xFFu);
}

inline void writeU32LE(uint8_t *p, uint32_t v) {
    p[0] = static_cast<uint8_t>(v & 0xFFu);
    p[1] = static_cast<uint8_t>((v >> 8u) & 0xFFu);
    p[2] = static_cast<uint8_t>((v >> 16u) & 0xFFu);
    p[3] = static_cast<uint8_t>((v >> 24u) & 0xFFu);
}

struct SubstructSlots {
    uint8_t growth;
    uint8_t attacks;
    uint8_t evs;
    uint8_t misc;
};

constexpr SubstructSlots kSubstructOrder[24] = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 3, 1, 2},
    {0, 2, 3, 1}, {0, 3, 2, 1}, {1, 0, 2, 3}, {1, 0, 3, 2},
    {2, 0, 1, 3}, {3, 0, 1, 2}, {2, 0, 3, 1}, {3, 0, 2, 1},
    {1, 2, 0, 3}, {1, 3, 0, 2}, {2, 1, 0, 3}, {3, 1, 0, 2},
    {2, 3, 0, 1}, {3, 2, 0, 1}, {1, 2, 3, 0}, {1, 3, 2, 0},
    {2, 1, 3, 0}, {3, 1, 2, 0}, {2, 3, 1, 0}, {3, 2, 1, 0},
};

constexpr uint16_t kInternalToNationalDex[413] = {
      0u,   1u,   2u,   3u,   4u,   5u,   6u,   7u,   8u,   9u,  10u,  11u,  12u,  13u,  14u,  15u,
     16u,  17u,  18u,  19u,  20u,  21u,  22u,  23u,  24u,  25u,  26u,  27u,  28u,  29u,  30u,  31u,
     32u,  33u,  34u,  35u,  36u,  37u,  38u,  39u,  40u,  41u,  42u,  43u,  44u,  45u,  46u,  47u,
     48u,  49u,  50u,  51u,  52u,  53u,  54u,  55u,  56u,  57u,  58u,  59u,  60u,  61u,  62u,  63u,
     64u,  65u,  66u,  67u,  68u,  69u,  70u,  71u,  72u,  73u,  74u,  75u,  76u,  77u,  78u,  79u,
     80u,  81u,  82u,  83u,  84u,  85u,  86u,  87u,  88u,  89u,  90u,  91u,  92u,  93u,  94u,  95u,
     96u,  97u,  98u,  99u, 100u, 101u, 102u, 103u, 104u, 105u, 106u, 107u, 108u, 109u, 110u, 111u,
    112u, 113u, 114u, 115u, 116u, 117u, 118u, 119u, 120u, 121u, 122u, 123u, 124u, 125u, 126u, 127u,
    128u, 129u, 130u, 131u, 132u, 133u, 134u, 135u, 136u, 137u, 138u, 139u, 140u, 141u, 142u, 143u,
    144u, 145u, 146u, 147u, 148u, 149u, 150u, 151u, 152u, 153u, 154u, 155u, 156u, 157u, 158u, 159u,
    160u, 161u, 162u, 163u, 164u, 165u, 166u, 167u, 168u, 169u, 170u, 171u, 172u, 173u, 174u, 175u,
    176u, 177u, 178u, 179u, 180u, 181u, 182u, 183u, 184u, 185u, 186u, 187u, 188u, 189u, 190u, 191u,
    192u, 193u, 194u, 195u, 196u, 197u, 198u, 199u, 200u, 201u, 202u, 203u, 204u, 205u, 206u, 207u,
    208u, 209u, 210u, 211u, 212u, 213u, 214u, 215u, 216u, 217u, 218u, 219u, 220u, 221u, 222u, 223u,
    224u, 225u, 226u, 227u, 228u, 229u, 230u, 231u, 232u, 233u, 234u, 235u, 236u, 237u, 238u, 239u,
    240u, 241u, 242u, 243u, 244u, 245u, 246u, 247u, 248u, 249u, 250u, 251u,   0u,   0u,   0u,   0u,
      0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,   0u,
      0u,   0u,   0u,   0u,   0u, 252u, 253u, 254u, 255u, 256u, 257u, 258u, 259u, 260u, 261u, 262u,
    263u, 264u, 265u, 266u, 267u, 268u, 269u, 270u, 271u, 272u, 273u, 274u, 275u, 290u, 291u, 292u,
    276u, 277u, 285u, 286u, 327u, 278u, 279u, 283u, 284u, 320u, 321u, 300u, 301u, 352u, 343u, 344u,
    299u, 324u, 302u, 339u, 340u, 370u, 341u, 342u, 349u, 350u, 318u, 319u, 328u, 329u, 330u, 296u,
    297u, 309u, 310u, 322u, 323u, 363u, 364u, 365u, 331u, 332u, 361u, 362u, 337u, 338u, 298u, 325u,
    326u, 311u, 312u, 303u, 307u, 308u, 333u, 334u, 360u, 355u, 356u, 315u, 287u, 288u, 289u, 316u,
    317u, 357u, 293u, 294u, 295u, 366u, 367u, 368u, 359u, 353u, 354u, 336u, 335u, 369u, 304u, 305u,
    306u, 351u, 313u, 314u, 345u, 346u, 347u, 348u, 280u, 281u, 282u, 371u, 372u, 373u, 374u, 375u,
    376u, 377u, 378u, 379u, 382u, 383u, 384u, 380u, 381u, 385u, 386u, 358u,   0u,
};

constexpr const char *kFireRedLocationNames[256] = {
    "", // 0x00
    "", // 0x01
    "", // 0x02
    "", // 0x03
    "", // 0x04
    "", // 0x05
    "", // 0x06
    "", // 0x07
    "", // 0x08
    "", // 0x09
    "", // 0x0A
    "", // 0x0B
    "", // 0x0C
    "", // 0x0D
    "", // 0x0E
    "", // 0x0F
    "", // 0x10
    "", // 0x11
    "", // 0x12
    "", // 0x13
    "", // 0x14
    "", // 0x15
    "", // 0x16
    "", // 0x17
    "", // 0x18
    "", // 0x19
    "", // 0x1A
    "", // 0x1B
    "", // 0x1C
    "", // 0x1D
    "", // 0x1E
    "", // 0x1F
    "", // 0x20
    "", // 0x21
    "", // 0x22
    "", // 0x23
    "", // 0x24
    "", // 0x25
    "", // 0x26
    "", // 0x27
    "", // 0x28
    "", // 0x29
    "", // 0x2A
    "", // 0x2B
    "", // 0x2C
    "", // 0x2D
    "", // 0x2E
    "", // 0x2F
    "", // 0x30
    "", // 0x31
    "", // 0x32
    "", // 0x33
    "", // 0x34
    "", // 0x35
    "", // 0x36
    "", // 0x37
    "", // 0x38
    "", // 0x39
    "", // 0x3A
    "", // 0x3B
    "", // 0x3C
    "", // 0x3D
    "", // 0x3E
    "", // 0x3F
    "", // 0x40
    "", // 0x41
    "", // 0x42
    "", // 0x43
    "", // 0x44
    "", // 0x45
    "", // 0x46
    "", // 0x47
    "", // 0x48
    "", // 0x49
    "", // 0x4A
    "", // 0x4B
    "", // 0x4C
    "", // 0x4D
    "", // 0x4E
    "", // 0x4F
    "", // 0x50
    "", // 0x51
    "", // 0x52
    "", // 0x53
    "", // 0x54
    "", // 0x55
    "", // 0x56
    "", // 0x57
    "Pallet Town", // 0x58
    "Viridian City", // 0x59
    "Pewter City", // 0x5A
    "Cerulean City", // 0x5B
    "Lavender Town", // 0x5C
    "Vermilion City", // 0x5D
    "Celadon City", // 0x5E
    "Fuchsia City", // 0x5F
    "Cinnabar Island", // 0x60
    "Indigo Plateau", // 0x61
    "Saffron City", // 0x62
    "Route 4", // 0x63
    "Route 10", // 0x64
    "Route 1", // 0x65
    "Route 2", // 0x66
    "Route 3", // 0x67
    "Route 4", // 0x68
    "Route 5", // 0x69
    "Route 6", // 0x6A
    "Route 7", // 0x6B
    "Route 8", // 0x6C
    "Route 9", // 0x6D
    "Route 10", // 0x6E
    "Route 11", // 0x6F
    "Route 12", // 0x70
    "Route 13", // 0x71
    "Route 14", // 0x72
    "Route 15", // 0x73
    "Route 16", // 0x74
    "Route 17", // 0x75
    "Route 18", // 0x76
    "Route 19", // 0x77
    "Route 20", // 0x78
    "Route 21", // 0x79
    "Route 22", // 0x7A
    "Route 23", // 0x7B
    "Route 24", // 0x7C
    "Route 25", // 0x7D
    "Viridian Forest", // 0x7E
    "Mt. Moon", // 0x7F
    "S.S. Anne", // 0x80
    "Underground Path", // 0x81
    "Underground Path", // 0x82
    "Diglett's Cave", // 0x83
    "Victory Road", // 0x84
    "Rocket Hideout", // 0x85
    "Silph Co.", // 0x86
    "Pokémon Mansion", // 0x87
    "Safari Zone", // 0x88
    "Pokémon League", // 0x89
    "Rock Tunnel", // 0x8A
    "Seafoam Islands", // 0x8B
    "Pokémon Tower", // 0x8C
    "Cerulean Cave", // 0x8D
    "Power Plant", // 0x8E
    "One Island", // 0x8F
    "Two Island", // 0x90
    "Three Island", // 0x91
    "Four Island", // 0x92
    "Five Island", // 0x93
    "Seven Island", // 0x94
    "Six Island", // 0x95
    "Kindle Road", // 0x96
    "Treasure Beach", // 0x97
    "Cape Brink", // 0x98
    "Bond Bridge", // 0x99
    "Three Isle Port", // 0x9A
    "Sevii Isle 6", // 0x9B
    "Sevii Isle 7", // 0x9C
    "Sevii Isle 8", // 0x9D
    "Sevii Isle 9", // 0x9E
    "Resort Gorgeous", // 0x9F
    "Water Labyrinth", // 0xA0
    "Five Isle Meadow", // 0xA1
    "Memorial Pillar", // 0xA2
    "Outcast Island", // 0xA3
    "Green Path", // 0xA4
    "Water Path", // 0xA5
    "Ruin Valley", // 0xA6
    "Trainer Tower", // 0xA7
    "Canyon Entrance", // 0xA8
    "Sevault Canyon", // 0xA9
    "Tanoby Ruins", // 0xAA
    "Sevii Isle 22", // 0xAB
    "Sevii Isle 23", // 0xAC
    "Sevii Isle 24", // 0xAD
    "Navel Rock", // 0xAE
    "Mt. Ember", // 0xAF
    "Berry Forest", // 0xB0
    "Icefall Cave", // 0xB1
    "Rocket Warehouse", // 0xB2
    "Trainer Tower", // 0xB3
    "Dotted Hole", // 0xB4
    "Lost Cave", // 0xB5
    "Pattern Bush", // 0xB6
    "Altering Cave", // 0xB7
    "Tanoby Chambers", // 0xB8
    "Three Isle Path", // 0xB9
    "Tanoby Key", // 0xBA
    "Birth Island", // 0xBB
    "Monean Chamber", // 0xBC
    "Liptoo Chamber", // 0xBD
    "Weepth Chamber", // 0xBE
    "Dilford Chamber", // 0xBF
    "Scufib Chamber", // 0xC0
    "Rixy Chamber", // 0xC1
    "Viapois Chamber", // 0xC2
    "Ember Spa", // 0xC3
    "Celadon Dept.", // 0xC4
    "", // 0xC5
    "", // 0xC6
    "", // 0xC7
    "", // 0xC8
    "", // 0xC9
    "", // 0xCA
    "", // 0xCB
    "", // 0xCC
    "", // 0xCD
    "", // 0xCE
    "", // 0xCF
    "", // 0xD0
    "", // 0xD1
    "", // 0xD2
    "", // 0xD3
    "", // 0xD4
    "", // 0xD5
    "", // 0xD6
    "", // 0xD7
    "", // 0xD8
    "", // 0xD9
    "", // 0xDA
    "", // 0xDB
    "", // 0xDC
    "", // 0xDD
    "", // 0xDE
    "", // 0xDF
    "", // 0xE0
    "", // 0xE1
    "", // 0xE2
    "", // 0xE3
    "", // 0xE4
    "", // 0xE5
    "", // 0xE6
    "", // 0xE7
    "", // 0xE8
    "", // 0xE9
    "", // 0xEA
    "", // 0xEB
    "", // 0xEC
    "", // 0xED
    "", // 0xEE
    "", // 0xEF
    "", // 0xF0
    "", // 0xF1
    "", // 0xF2
    "", // 0xF3
    "", // 0xF4
    "", // 0xF5
    "", // 0xF6
    "", // 0xF7
    "", // 0xF8
    "", // 0xF9
    "", // 0xFA
    "", // 0xFB
    "", // 0xFC
    "Gift / Event", // 0xFD
    "In-game Trade", // 0xFE
    "Fateful Encounter", // 0xFF
};

constexpr uint16_t kSectorValidationSizes[kSectorsPerSlot] = {
    3884u, 3968u, 3968u, 3968u, 3848u,
    3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 3968u, 2000u
};

uint16_t computeGen3SectorChecksum(const uint8_t *data, uint16_t lengthBytes) {
    uint32_t sum = 0;
    const uint16_t wordCount = static_cast<uint16_t>(lengthBytes / 4u);
    for (uint16_t i = 0; i < wordCount; ++i) {
        sum += readU32LE(data + static_cast<std::size_t>(i) * 4u);
    }
    return static_cast<uint16_t>((sum & 0xFFFFu) + (sum >> 16u));
}

} // namespace

FireRedRomInfo identifyFireRedRom(const uint8_t *romData, std::size_t romSize) {
    FireRedRomInfo info{};
    if (!romData || romSize < 0xC0u) {
        return info;
    }
    if (romData[0xB2] != 0x96u) {
        return info;
    }
    char titleBuf[13]{};
    std::memcpy(titleBuf, romData + 0xA0, 12);
    std::string title(titleBuf);
    while (!title.empty() && (title.back() == '\0' || title.back() == ' ')) {
        title.pop_back();
    }
    char codeBuf[5]{};
    std::memcpy(codeBuf, romData + 0xAC, 4);
    std::string code(codeBuf);

    info.gameTitle = title;
    info.gameCode = code;
    info.revision = romData[0xBC];

    const bool titleMatches = (title == "POKEMON FIRE");
    const bool codeMatches = (code == "BPRE" || code == "BPRJ" || code == "BPRD" ||
                              code == "BPRF" || code == "BPRI" || code == "BPRS");
    if (titleMatches && codeMatches) {
        info.isFireRed = true;
        info.supportedRamLayout = (code == "BPRE" && (info.revision == 0u || info.revision == 1u));
    }
    return info;
}

uint16_t internalSpeciesToNationalDex(uint16_t internalSpecies) {
    if (internalSpecies == 0u || internalSpecies >= static_cast<uint16_t>(sizeof(kInternalToNationalDex) / sizeof(kInternalToNationalDex[0]))) {
        return 0u;
    }
    return kInternalToNationalDex[internalSpecies];
}

std::string fireRedLocationName(uint8_t metLocationId) {
    const char *raw = kFireRedLocationNames[metLocationId];
    if (!raw || raw[0] == '\0') {
        return kUnknownLocationLabel;
    }
    return std::string(raw);
}

bool isGen3Shiny(uint32_t otId, uint32_t personality) {
    const uint16_t tid = static_cast<uint16_t>(otId & 0xFFFFu);
    const uint16_t sid = static_cast<uint16_t>((otId >> 16u) & 0xFFFFu);
    const uint16_t pidLo = static_cast<uint16_t>(personality & 0xFFFFu);
    const uint16_t pidHi = static_cast<uint16_t>((personality >> 16u) & 0xFFFFu);
    const uint16_t shinyVal = static_cast<uint16_t>(tid ^ sid ^ pidLo ^ pidHi);
    return shinyVal < 8u;
}

bool isPokedexOwnedBitSet(const uint8_t owned52[52], uint16_t nationalDexNumber) {
    if (!owned52 || nationalDexNumber == 0u || nationalDexNumber > 416u) {
        return false;
    }
    const std::size_t bitIndex = static_cast<std::size_t>(nationalDexNumber - 1u);
    const std::size_t byteIndex = bitIndex >> 3u;
    const uint8_t bitOffset = static_cast<uint8_t>(bitIndex & 7u);
    return ((owned52[byteIndex] >> bitOffset) & 0x01u) != 0u;
}

DecodedGen3Pokemon decodeBoxPokemon(const uint8_t raw80[80]) {
    DecodedGen3Pokemon out{};
    if (!raw80) {
        return out;
    }
    const uint32_t personality = readU32LE(raw80 + 0x00);
    const uint32_t otId = readU32LE(raw80 + 0x04);
    const uint8_t flags = raw80[0x13];
    const bool isBadEgg = (flags & 0x01u) != 0u;
    const bool hasSpecies = (flags & 0x02u) != 0u;
    const bool isEggFlag = (flags & 0x04u) != 0u;

    if ((personality == 0u && otId == 0u) || !hasSpecies || isBadEgg || isEggFlag) {
        return out;
    }

    const uint16_t storedChecksum = readU16LE(raw80 + 0x1C);
    const uint32_t key = personality ^ otId;

    uint32_t decryptedWords[12]{};
    uint16_t computedChecksum = 0u;
    for (std::size_t i = 0; i < 12u; ++i) {
        decryptedWords[i] = readU32LE(raw80 + 0x20 + i * 4u) ^ key;
        computedChecksum = static_cast<uint16_t>(computedChecksum + static_cast<uint16_t>(decryptedWords[i] & 0xFFFFu));
        computedChecksum = static_cast<uint16_t>(computedChecksum + static_cast<uint16_t>((decryptedWords[i] >> 16u) & 0xFFFFu));
    }

    if (computedChecksum != storedChecksum) {
        return out;
    }

    const SubstructSlots slots = kSubstructOrder[personality % 24u];
    const uint32_t *growth = &decryptedWords[static_cast<std::size_t>(slots.growth) * 3u];
    const uint32_t *misc = &decryptedWords[static_cast<std::size_t>(slots.misc) * 3u];

    const uint16_t internalSpecies = static_cast<uint16_t>(growth[0] & 0xFFFFu);
    const uint16_t nationalDex = internalSpeciesToNationalDex(internalSpecies);
    if (nationalDex == 0u || nationalDex > 386u) {
        return out;
    }

    const bool isEggSubstruct = ((misc[1] >> 30u) & 0x01u) != 0u;
    if (isEggSubstruct) {
        return out;
    }

    const uint8_t metLocationId = static_cast<uint8_t>((misc[0] >> 8u) & 0xFFu);
    const uint16_t originsInfo = static_cast<uint16_t>((misc[0] >> 16u) & 0xFFFFu);
    const uint8_t metLevel = static_cast<uint8_t>(originsInfo & 0x7Fu);

    out.valid = true;
    out.personality = personality;
    out.otId = otId;
    out.internalSpecies = internalSpecies;
    out.nationalDexNumber = nationalDex;
    out.checksum = storedChecksum;
    out.metLocationId = metLocationId;
    out.metLevel = metLevel;
    out.isShiny = isGen3Shiny(otId, personality);
    out.isEgg = false;
    out.metLocationName = fireRedLocationName(metLocationId);
    return out;
}

void encodeBoxPokemonForTest(uint8_t outRaw80[80],
                             uint32_t personality,
                             uint32_t otId,
                             uint16_t internalSpecies,
                             uint8_t metLocationId,
                             bool isEgg,
                             bool isBadEgg,
                             bool corruptChecksum) {
    std::memset(outRaw80, 0, 80);
    writeU32LE(outRaw80 + 0x00, personality);
    writeU32LE(outRaw80 + 0x04, otId);
    outRaw80[0x12] = 0x02u;
    uint8_t flags = 0x02u;
    if (isBadEgg) flags |= 0x01u;
    if (isEgg) flags |= 0x04u;
    outRaw80[0x13] = flags;

    const SubstructSlots slots = kSubstructOrder[personality % 24u];
    uint32_t words[12]{};

    words[static_cast<std::size_t>(slots.growth) * 3u + 0u] = static_cast<uint32_t>(internalSpecies);
    words[static_cast<std::size_t>(slots.growth) * 3u + 1u] = 100u;

    const uint16_t origins = 5u;
    words[static_cast<std::size_t>(slots.misc) * 3u + 0u] =
        (static_cast<uint32_t>(metLocationId) << 8u) | (static_cast<uint32_t>(origins) << 16u);
    if (isEgg) {
        words[static_cast<std::size_t>(slots.misc) * 3u + 1u] = (1u << 30u);
    }

    uint16_t checksum = 0u;
    for (std::size_t i = 0; i < 12u; ++i) {
        checksum = static_cast<uint16_t>(checksum + static_cast<uint16_t>(words[i] & 0xFFFFu));
        checksum = static_cast<uint16_t>(checksum + static_cast<uint16_t>((words[i] >> 16u) & 0xFFFFu));
    }
    if (corruptChecksum) {
        checksum = static_cast<uint16_t>(checksum ^ 0x1234u);
    }
    writeU16LE(outRaw80 + 0x1C, checksum);

    const uint32_t key = personality ^ otId;
    for (std::size_t i = 0; i < 12u; ++i) {
        writeU32LE(outRaw80 + 0x20 + i * 4u, words[i] ^ key);
    }
}

GbaBusReadFn makeDescriptorBusReader(const std::vector<GbaMemoryDescriptor> &descriptors,
                                     const void *fallbackEwram,
                                     std::size_t fallbackEwramSize) {
    return [descriptors, fallbackEwram, fallbackEwramSize](uint32_t gbaAddress, uint8_t *outBuffer, std::size_t length) -> bool {
        if (!outBuffer || length == 0u) {
            return false;
        }
        for (const auto &desc : descriptors) {
            if (!desc.ptr || desc.len == 0u) {
                continue;
            }
            const std::size_t addr = static_cast<std::size_t>(gbaAddress);
            if (addr >= desc.start && addr <= desc.start + desc.len && length <= (desc.start + desc.len - addr)) {
                const auto *base = static_cast<const uint8_t *>(desc.ptr);
                std::memcpy(outBuffer, base + (addr - desc.start), length);
                return true;
            }
        }
        if (fallbackEwram && fallbackEwramSize >= 0x40000u) {
            if (gbaAddress >= kEwramStart && gbaAddress < kEwramEnd &&
                length <= static_cast<std::size_t>(kEwramEnd - gbaAddress)) {
                const auto *base = static_cast<const uint8_t *>(fallbackEwram);
                std::memcpy(outBuffer, base + (gbaAddress - kEwramStart), length);
                return true;
            }
            if (fallbackEwramSize >= 0x48000u && gbaAddress >= 0x03000000u && gbaAddress < 0x03008000u &&
                length <= static_cast<std::size_t>(0x03008000u - gbaAddress)) {
                const auto *base = static_cast<const uint8_t *>(fallbackEwram) + 0x40000u;
                std::memcpy(outBuffer, base + (gbaAddress - 0x03000000u), length);
                return true;
            }
        }
        return false;
    };
}

FireRedSaveSnapshot inspectFireRedSave128K(const uint8_t *saveData, std::size_t saveSize) {
    FireRedSaveSnapshot result{};
    if (!saveData || saveSize < kSectorSize * kSectorsPerSlot) {
        return result;
    }

    const std::size_t maxSlots = (saveSize >= kSectorSize * kSectorsPerSlot * 2u) ? 2u : 1u;
    bool bestSlotValid = false;
    uint32_t bestSlotIndex = 0u;
    uint32_t bestCounter = 0u;
    std::array<const uint8_t *, kSectorsPerSlot> bestSectors{};

    for (std::size_t slot = 0; slot < maxSlots; ++slot) {
        std::array<const uint8_t *, kSectorsPerSlot> slotSectors{};
        uint32_t slotCounter = 0u;
        bool allPresent = true;

        for (std::size_t secIdx = 0; secIdx < kSectorsPerSlot; ++secIdx) {
            const uint8_t *secPtr = saveData + (slot * kSectorsPerSlot + secIdx) * kSectorSize;
            const uint16_t secId = readU16LE(secPtr + 0xFF4u);
            const uint16_t secChecksum = readU16LE(secPtr + 0xFF6u);
            const uint32_t secSig = readU32LE(secPtr + 0xFF8u);
            const uint32_t secCounter = readU32LE(secPtr + 0xFFCu);

            if (secSig != kSectorSignature || secId >= kSectorsPerSlot || slotSectors[secId] != nullptr) {
                allPresent = false;
                break;
            }
            const uint16_t expectedChecksum = computeGen3SectorChecksum(secPtr, kSectorValidationSizes[secId]);
            if (expectedChecksum != secChecksum) {
                allPresent = false;
                break;
            }
            slotSectors[secId] = secPtr;
            slotCounter = secCounter;
        }

        if (allPresent) {
            if (!bestSlotValid || slotCounter >= bestCounter) {
                bestSlotValid = true;
                bestSlotIndex = static_cast<uint32_t>(slot);
                bestCounter = slotCounter;
                bestSectors = slotSectors;
            }
        }
    }

    if (!bestSlotValid) {
        return result;
    }

    const uint8_t *saveBlock2 = bestSectors[0];
    const uint32_t trainerId = readU32LE(saveBlock2 + kSaveBlock2TrainerIdOffset);
    if (trainerId == 0u) {
        return result;
    }

    result.valid = true;
    result.activeSlot = bestSlotIndex;
    result.saveCounter = bestCounter;
    result.trainerId = trainerId;
    std::memcpy(result.pokedexOwned.data(), saveBlock2 + kSaveBlock2PokedexOwnedOffset, 52u);

    std::vector<uint8_t> saveBlock1(kSectorDataSize * 4u, 0u);
    for (std::size_t i = 0; i < 4u; ++i) {
        std::memcpy(saveBlock1.data() + i * kSectorDataSize, bestSectors[1u + i], kSectorDataSize);
    }
    const uint8_t partyCount = saveBlock1[kSaveBlock1PartyCountOffset];
    if (partyCount <= 6u) {
        for (uint8_t i = 0; i < partyCount; ++i) {
            const uint8_t *monPtr = saveBlock1.data() + kSaveBlock1PartyOffset + static_cast<std::size_t>(i) * kPartyPokemonSize;
            DecodedGen3Pokemon decoded = decodeBoxPokemon(monPtr);
            if (decoded.valid && isPokedexOwnedBitSet(result.pokedexOwned.data(), decoded.nationalDexNumber)) {
                result.partyPokemon.push_back(std::move(decoded));
            }
        }
    }

    std::vector<uint8_t> storageBlock(kSectorDataSize * 9u, 0u);
    for (std::size_t i = 0; i < 9u; ++i) {
        std::memcpy(storageBlock.data() + i * kSectorDataSize, bestSectors[5u + i], kSectorDataSize);
    }
    const std::size_t totalBoxPokemon = kTotalBoxesCount * kInBoxCount;
    for (std::size_t i = 0; i < totalBoxPokemon; ++i) {
        const std::size_t offset = kPokemonStorageBoxesOffset + i * kBoxPokemonSize;
        if (offset + kBoxPokemonSize <= storageBlock.size()) {
            DecodedGen3Pokemon decoded = decodeBoxPokemon(storageBlock.data() + offset);
            if (decoded.valid && isPokedexOwnedBitSet(result.pokedexOwned.data(), decoded.nationalDexNumber)) {
                result.boxPokemon.push_back(std::move(decoded));
            }
        }
    }

    return result;
}

std::vector<FireRedCaptureEvent> diffFireRedSaveSnapshots(const FireRedSaveSnapshot &before,
                                                          const FireRedSaveSnapshot &after,
                                                          const std::string &gameCode,
                                                          uint8_t romRevision) {
    std::vector<FireRedCaptureEvent> events;
    if (!after.valid) {
        return events;
    }

    auto makeKey = [](const DecodedGen3Pokemon &mon) -> uint64_t {
        return (static_cast<uint64_t>(mon.personality) << 32u) ^
               (static_cast<uint64_t>(mon.otId) << 1u) ^
               static_cast<uint64_t>(mon.nationalDexNumber);
    };

    std::unordered_set<uint64_t> baselineKeys;
    if (before.valid && before.trainerId == after.trainerId) {
        for (const auto &m : before.partyPokemon) baselineKeys.insert(makeKey(m));
        for (const auto &m : before.boxPokemon) baselineKeys.insert(makeKey(m));
    }

    auto checkAndAppend = [&](const DecodedGen3Pokemon &mon, const char *source) {
        const uint64_t k = makeKey(mon);
        if (baselineKeys.find(k) == baselineKeys.end()) {
            baselineKeys.insert(k);
            FireRedCaptureEvent ev{};
            ev.nationalDexNumber = mon.nationalDexNumber;
            ev.internalSpecies = mon.internalSpecies;
            ev.isShiny = mon.isShiny;
            ev.personality = mon.personality;
            ev.otId = mon.otId;
            ev.metLocationId = mon.metLocationId;
            ev.metLocationName = mon.metLocationName;
            ev.storageSource = source;
            ev.gameCode = gameCode;
            ev.romRevision = romRevision;
            events.push_back(std::move(ev));
        }
    };

    for (const auto &m : after.partyPokemon) checkAndAppend(m, "party");
    for (const auto &m : after.boxPokemon) checkAndAppend(m, "pc_box");
    return events;
}

FireRedCaptureTracker::FireRedCaptureTracker(FireRedRomInfo romInfo,
                                             GbaBusReadFn busReader,
                                             CaptureCallback onCapture,
                                             uint32_t scanIntervalFrames)
    : romInfo_(std::move(romInfo)),
      busReader_(std::move(busReader)),
      onCapture_(std::move(onCapture)),
      scanIntervalFrames_(scanIntervalFrames == 0u ? 1u : scanIntervalFrames) {}

uint64_t FireRedCaptureTracker::instanceKey(uint32_t personality, uint32_t otId, uint16_t nationalDex) {
    return (static_cast<uint64_t>(personality) << 32u) ^
           (static_cast<uint64_t>(otId) << 1u) ^
           static_cast<uint64_t>(nationalDex);
}

void FireRedCaptureTracker::reset() {
    frameCounter_ = 0u;
    baselineAnchored_ = false;
    anchoredTrainerId_ = 0u;
    pendingBaselineTrainerId_ = 0u;
    pendingBaselineStability_ = 0u;
    pendingBaselineSet_.clear();
    anchoredInstances_.clear();
    pendingCandidates_.clear();
}

void FireRedCaptureTracker::seedBaselineFromSave(const FireRedSaveSnapshot &snapshot) {
    if (!snapshot.valid || snapshot.trainerId == 0u) {
        return;
    }
    baselineAnchored_ = true;
    anchoredTrainerId_ = snapshot.trainerId;
    anchoredInstances_.clear();
    for (const auto &mon : snapshot.partyPokemon) {
        anchoredInstances_.insert(instanceKey(mon.personality, mon.otId, mon.nationalDexNumber));
    }
    for (const auto &mon : snapshot.boxPokemon) {
        anchoredInstances_.insert(instanceKey(mon.personality, mon.otId, mon.nationalDexNumber));
    }
    pendingCandidates_.clear();
}

void FireRedCaptureTracker::doFrame() {
    if (!romInfo_.isFireRed || !romInfo_.supportedRamLayout || !busReader_) {
        return;
    }
    ++frameCounter_;
    if ((frameCounter_ % scanIntervalFrames_) != 0u) {
        return;
    }
    performScan();
}

void FireRedCaptureTracker::performScan() {
    const auto abandonScan = [this]() {
        pendingBaselineTrainerId_ = 0u;
        pendingBaselineStability_ = 0u;
        pendingBaselineSet_.clear();
        pendingCandidates_.clear();
    };
    uint8_t ptrBuf[4]{};
    if (!busReader_(kIwramSaveBlock2Ptr, ptrBuf, 4u)) {
        abandonScan();
        return;
    }
    const uint32_t saveBlock2Ptr = readU32LE(ptrBuf);
    if (saveBlock2Ptr < kEwramStart || saveBlock2Ptr + kSaveBlock2MinSize > kEwramEnd) {
        abandonScan();
        return;
    }

    if (!busReader_(kIwramPokemonStoragePtr, ptrBuf, 4u)) {
        abandonScan();
        return;
    }
    const uint32_t storagePtr = readU32LE(ptrBuf);
    const bool storagePtrValid = (storagePtr >= kEwramStart &&
                                  storagePtr <= kEwramEnd - kPokemonStorageBoxesOffset - kPokemonStorageBoxesBytes);
    if (!storagePtrValid) {
        abandonScan();
        return;
    }

    uint8_t sb2Header[kSaveBlock2MinSize]{};
    if (!busReader_(saveBlock2Ptr, sb2Header, sizeof(sb2Header))) {
        abandonScan();
        return;
    }
    if (sb2Header[0] == 0x00u || sb2Header[0] == 0xFFu) {
        abandonScan();
        return;
    }
    const uint32_t trainerId = readU32LE(sb2Header + kSaveBlock2TrainerIdOffset);
    if (trainerId == 0u) {
        abandonScan();
        return;
    }
    const uint8_t *owned52 = sb2Header + kSaveBlock2PokedexOwnedOffset;

    uint8_t partyCount = 0u;
    if (!busReader_(kEwramPlayerPartyCount, &partyCount, 1u) || partyCount > 6u) {
        abandonScan();
        return;
    }

    std::vector<FireRedCaptureEvent> currentValidPokemon;
    currentValidPokemon.reserve(16u);
    std::unordered_set<uint64_t> currentKeys;

    if (partyCount > 0u) {
        uint8_t partyBuf[6u * kPartyPokemonSize]{};
        const std::size_t bytesToRead = static_cast<std::size_t>(partyCount) * kPartyPokemonSize;
        if (!busReader_(kEwramPlayerParty, partyBuf, bytesToRead)) {
            abandonScan();
            return;
        }
        for (uint8_t slot = 0u; slot < partyCount; ++slot) {
            const uint8_t *monRaw = partyBuf + static_cast<std::size_t>(slot) * kPartyPokemonSize;
            DecodedGen3Pokemon decoded = decodeBoxPokemon(monRaw);
            if (!decoded.valid || !isPokedexOwnedBitSet(owned52, decoded.nationalDexNumber)) {
                continue;
            }
            const uint64_t key = instanceKey(decoded.personality, decoded.otId, decoded.nationalDexNumber);
            if (currentKeys.insert(key).second) {
                FireRedCaptureEvent ev{};
                ev.nationalDexNumber = decoded.nationalDexNumber;
                ev.internalSpecies = decoded.internalSpecies;
                ev.isShiny = decoded.isShiny;
                ev.personality = decoded.personality;
                ev.otId = decoded.otId;
                ev.metLocationId = decoded.metLocationId;
                ev.metLocationName = decoded.metLocationName;
                ev.storageSource = "party";
                ev.gameCode = romInfo_.gameCode;
                ev.romRevision = romInfo_.revision;
                currentValidPokemon.push_back(std::move(ev));
            }
        }
    }

    if (storagePtrValid) {
        uint8_t boxMonRaw[kBoxPokemonSize]{};
        const uint32_t boxesBase = storagePtr + kPokemonStorageBoxesOffset;
        const uint32_t totalSlots = kTotalBoxesCount * kInBoxCount;
        for (uint32_t slot = 0u; slot < totalSlots; ++slot) {
            const uint32_t slotAddr = boxesBase + slot * kBoxPokemonSize;
            uint8_t header8[8]{};
            if (!busReader_(slotAddr, header8, 8u)) {
                abandonScan();
            return;
            }
            if (readU32LE(header8) == 0u && readU32LE(header8 + 4u) == 0u) {
                continue;
            }
            if (!busReader_(slotAddr, boxMonRaw, kBoxPokemonSize)) {
                abandonScan();
            return;
            }
            DecodedGen3Pokemon decoded = decodeBoxPokemon(boxMonRaw);
            if (!decoded.valid || !isPokedexOwnedBitSet(owned52, decoded.nationalDexNumber)) {
                continue;
            }
            const uint64_t key = instanceKey(decoded.personality, decoded.otId, decoded.nationalDexNumber);
            if (currentKeys.insert(key).second) {
                FireRedCaptureEvent ev{};
                ev.nationalDexNumber = decoded.nationalDexNumber;
                ev.internalSpecies = decoded.internalSpecies;
                ev.isShiny = decoded.isShiny;
                ev.personality = decoded.personality;
                ev.otId = decoded.otId;
                ev.metLocationId = decoded.metLocationId;
                ev.metLocationName = decoded.metLocationName;
                ev.storageSource = "pc_box";
                ev.gameCode = romInfo_.gameCode;
                ev.romRevision = romInfo_.revision;
                currentValidPokemon.push_back(std::move(ev));
            }
        }
    }

    if (!baselineAnchored_ || trainerId != anchoredTrainerId_) {
        if (trainerId == pendingBaselineTrainerId_ && currentKeys == pendingBaselineSet_) {
            ++pendingBaselineStability_;
        } else {
            pendingBaselineTrainerId_ = trainerId;
            pendingBaselineSet_ = currentKeys;
            pendingBaselineStability_ = 1u;
        }
        if (pendingBaselineStability_ >= 2u) {
            baselineAnchored_ = true;
            anchoredTrainerId_ = trainerId;
            anchoredInstances_ = currentKeys;
            pendingCandidates_.clear();
        }
        return;
    }

    for (auto it = pendingCandidates_.begin(); it != pendingCandidates_.end();) {
        if (currentKeys.find(it->first) == currentKeys.end()) {
            it = pendingCandidates_.erase(it);
        } else {
            ++it;
        }
    }

    for (const auto &ev : currentValidPokemon) {
        const uint64_t key = instanceKey(ev.personality, ev.otId, ev.nationalDexNumber);
        if (anchoredInstances_.find(key) != anchoredInstances_.end()) {
            continue;
        }
        auto &obs = pendingCandidates_[key];
        obs.event = ev;
        ++obs.consecutiveScans;
        if (obs.consecutiveScans >= 2u) {
            anchoredInstances_.insert(key);
            const FireRedCaptureEvent confirmed = obs.event;
            pendingCandidates_.erase(key);
            if (onCapture_) {
                onCapture_(confirmed);
            }
        }
    }
}

} // namespace pokedex
} // namespace brum

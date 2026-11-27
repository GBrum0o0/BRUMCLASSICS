#include "PokemonPlatinumAdapter.hpp"

#include <algorithm>
#include <array>
#include <cstring>

namespace brum {
namespace pokedex {

namespace {

constexpr uint32_t kNdsMainRamStart = 0x02000000u;
constexpr uint32_t kNdsMainRamEnd = 0x02400000u;
constexpr uint32_t kGen4BoxPokemonSize = 136u;
constexpr uint32_t kGen4PartyPokemonSize = 236u;
constexpr uint16_t kMaxSinnohNationalDex = 493u;
constexpr uint32_t kRequiredStableScans = 3u;
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

struct BlockSlots {
    uint8_t a;
    uint8_t b;
    uint8_t c;
    uint8_t d;
};

constexpr BlockSlots kBlockOrder[24] = {
    {0, 1, 2, 3}, {0, 1, 3, 2}, {0, 2, 1, 3}, {0, 3, 1, 2},
    {0, 2, 3, 1}, {0, 3, 2, 1}, {1, 0, 2, 3}, {1, 0, 3, 2},
    {2, 0, 1, 3}, {3, 0, 1, 2}, {2, 0, 3, 1}, {3, 0, 2, 1},
    {1, 2, 0, 3}, {1, 3, 0, 2}, {2, 1, 0, 3}, {3, 1, 0, 2},
    {2, 3, 0, 1}, {3, 2, 0, 1}, {1, 2, 3, 0}, {1, 3, 2, 0},
    {2, 1, 3, 0}, {3, 1, 2, 0}, {2, 3, 1, 0}, {3, 2, 1, 0},
};

uint32_t gen4StepPrng(uint32_t &seed) {
    seed = seed * 0x41C64E6Du + 0x6073u;
    return (seed >> 16u) & 0xFFFFu;
}

uint64_t makeInstanceKey(uint32_t pid, uint32_t otId, uint16_t species) {
    return (static_cast<uint64_t>(pid ^ species) << 32u) | static_cast<uint64_t>(otId);
}

uint32_t makeCategoryKey(uint16_t nationalDexNumber, bool isShiny) {
    return (static_cast<uint32_t>(nationalDexNumber) << 1u) | (isShiny ? 1u : 0u);
}

bool readU32Bus(const NdsBusReadFn &reader, uint32_t addr, uint32_t &out) {
    uint8_t buf[4]{};
    if (!reader || !reader(addr, buf, 4u)) {
        return false;
    }
    out = readU32LE(buf);
    return true;
}

} // namespace

PlatinumRomInfo identifyPlatinumRom(const uint8_t *romData, std::size_t romSize) {
    PlatinumRomInfo info;
    if (!romData || romSize < 0x100u) {
        return info;
    }
    std::string title;
    title.reserve(12u);
    for (std::size_t i = 0; i < 12u; ++i) {
        const char ch = static_cast<char>(romData[i]);
        if (ch == '\0') break;
        if (ch >= 0x20 && ch <= 0x7E) title.push_back(ch);
    }
    std::string code(4u, '\0');
    for (std::size_t i = 0; i < 4u; ++i) {
        code[i] = static_cast<char>(romData[0x0Cu + i]);
    }
    info.gameTitle = title;
    info.gameCode = code;
    info.revision = romData[0x1Eu];
    info.isPlatinum = (code == "CPUE");
    info.supportedRamLayout = info.isPlatinum;
    return info;
}

bool isGen4Shiny(uint32_t otId, uint32_t pid) {
    const uint32_t tid = otId & 0xFFFFu;
    const uint32_t sid = (otId >> 16u) & 0xFFFFu;
    const uint32_t pLo = pid & 0xFFFFu;
    const uint32_t pHi = (pid >> 16u) & 0xFFFFu;
    return ((tid ^ sid) ^ (pLo ^ pHi)) < 8u;
}

std::string sinnohLocationName(uint16_t metLocationId) {
    switch (metLocationId) {
        case 1u: return "Twinleaf Town";
        case 2u: return "Sandgem Town";
        case 3u: return "Floaroma Town";
        case 4u: return "Solaceon Town";
        case 5u: return "Celestic Town";
        case 6u: return "Jubilife City";
        case 7u: return "Canalave City";
        case 8u: return "Oreburgh City";
        case 9u: return "Eterna City";
        case 10u: return "Hearthome City";
        case 11u: return "Pastoria City";
        case 12u: return "Veilstone City";
        case 13u: return "Sunyshore City";
        case 14u: return "Snowpoint City";
        case 15u: return "Pokémon League";
        case 16u: return "Route 201";
        case 17u: return "Route 202";
        case 18u: return "Route 203";
        case 19u: return "Route 204";
        case 20u: return "Route 205";
        case 21u: return "Route 206";
        case 22u: return "Route 207";
        case 23u: return "Route 208";
        case 24u: return "Route 209";
        case 25u: return "Route 210";
        case 26u: return "Route 211";
        case 27u: return "Route 212";
        case 28u: return "Route 213";
        case 29u: return "Route 214";
        case 30u: return "Route 215";
        case 31u: return "Route 216";
        case 32u: return "Route 217";
        case 33u: return "Route 218";
        case 34u: return "Route 219";
        case 35u: return "Route 220";
        case 36u: return "Route 221";
        case 37u: return "Route 222";
        case 38u: return "Route 223";
        case 39u: return "Route 224";
        case 40u: return "Route 225";
        case 41u: return "Route 226";
        case 42u: return "Route 227";
        case 43u: return "Route 228";
        case 44u: return "Route 229";
        case 45u: return "Route 230";
        case 46u: return "Lake Verity";
        case 47u: return "Lake Valor";
        case 48u: return "Lake Acuity";
        case 49u: return "Spear Pillar";
        case 50u: return "Mt. Coronet";
        case 51u: return "Stark Mountain";
        case 53u: return "Great Marsh";
        case 66u: return "Eterna Forest";
        case 67u: return "Fuego Ironworks";
        case 68u: return "Floaroma Meadow";
        case 81u: return "Valley Windworks";
        case 85u: return "Distortion World";
        case 114u: return "Sendoff Spring";
        case 115u: return "Turnback Cave";
        default: return kUnknownLocationLabel;
    }
}

DecodedGen4Pokemon decodeGen4Pokemon(const uint8_t raw136[136]) {
    DecodedGen4Pokemon result;
    if (!raw136) {
        return result;
    }
    const uint32_t pid = readU32LE(raw136 + 0x00u);
    const uint16_t reserved = readU16LE(raw136 + 0x04u);
    const uint16_t checksum = readU16LE(raw136 + 0x06u);
    if ((pid == 0u && checksum == 0u) || reserved != 0u) {
        return result;
    }

    uint8_t decrypted[128]{};
    uint32_t seed = checksum;
    uint32_t sum = 0u;
    for (std::size_t i = 0; i < 64u; ++i) {
        const uint16_t encWord = readU16LE(raw136 + 0x08u + i * 2u);
        const uint16_t keyWord = static_cast<uint16_t>(gen4StepPrng(seed));
        const uint16_t decWord = static_cast<uint16_t>(encWord ^ keyWord);
        writeU16LE(decrypted + i * 2u, decWord);
        sum += decWord;
    }
    if ((sum & 0xFFFFu) != checksum) {
        return result;
    }

    const uint32_t shiftVal = ((pid & 0x3E000u) >> 13u) % 24u;
    const BlockSlots &order = kBlockOrder[shiftVal];
    const uint8_t *blockA = decrypted + static_cast<std::size_t>(order.a) * 32u;
    const uint8_t *blockB = decrypted + static_cast<std::size_t>(order.b) * 32u;
    const uint8_t *blockD = decrypted + static_cast<std::size_t>(order.d) * 32u;

    const uint16_t species = readU16LE(blockA + 0x00u);
    if (species == 0u || species > kMaxSinnohNationalDex) {
        return result;
    }
    const uint32_t otId = readU32LE(blockA + 0x04u);
    const uint32_t iv32 = readU32LE(blockB + 0x10u);
    const bool isEgg = ((iv32 >> 30u) & 1u) != 0u;

    const uint16_t ptMetLoc = readU16LE(blockB + 0x1Eu);
    const uint16_t dpMetLoc = readU16LE(blockD + 0x18u);
    const uint16_t metLoc = ptMetLoc != 0u ? ptMetLoc : dpMetLoc;

    result.valid = true;
    result.pid = pid;
    result.otId = otId;
    result.nationalDexNumber = species;
    result.checksum = checksum;
    result.metLocationId = metLoc;
    result.isEgg = isEgg;
    result.isShiny = isGen4Shiny(otId, pid);
    result.metLocationName = sinnohLocationName(metLoc);
    return result;
}

void encodeGen4PokemonForTest(uint8_t outRaw136[136],
                              uint32_t pid,
                              uint32_t otId,
                              uint16_t nationalDexNumber,
                              uint16_t metLocationId,
                              bool isEgg,
                              bool corruptChecksum) {
    std::memset(outRaw136, 0, kGen4BoxPokemonSize);
    writeU32LE(outRaw136 + 0x00u, pid);
    writeU16LE(outRaw136 + 0x04u, 0u);

    uint8_t plainBlocks[128]{};
    const uint32_t shiftVal = ((pid & 0x3E000u) >> 13u) % 24u;
    const BlockSlots &order = kBlockOrder[shiftVal];

    uint8_t *blockA = plainBlocks + static_cast<std::size_t>(order.a) * 32u;
    uint8_t *blockB = plainBlocks + static_cast<std::size_t>(order.b) * 32u;
    uint8_t *blockD = plainBlocks + static_cast<std::size_t>(order.d) * 32u;

    writeU16LE(blockA + 0x00u, nationalDexNumber);
    writeU32LE(blockA + 0x04u, otId);
    writeU32LE(blockB + 0x10u, isEgg ? (1u << 30u) : 0u);
    writeU16LE(blockB + 0x1Eu, metLocationId);
    writeU16LE(blockD + 0x18u, metLocationId);

    uint32_t sum = 0u;
    for (std::size_t i = 0; i < 64u; ++i) {
        sum += readU16LE(plainBlocks + i * 2u);
    }
    const uint16_t checksum = static_cast<uint16_t>(sum & 0xFFFFu);
    const uint16_t storedChecksum = corruptChecksum ? static_cast<uint16_t>(checksum ^ 0x5555u) : checksum;
    writeU16LE(outRaw136 + 0x06u, storedChecksum);

    uint32_t seed = checksum;
    for (std::size_t i = 0; i < 64u; ++i) {
        const uint16_t word = readU16LE(plainBlocks + i * 2u);
        const uint16_t keyWord = static_cast<uint16_t>(gen4StepPrng(seed));
        writeU16LE(outRaw136 + 0x08u + i * 2u, static_cast<uint16_t>(word ^ keyWord));
    }
}

NdsBusReadFn makeNdsDescriptorBusReader(const std::vector<NdsMemoryDescriptor> &descriptors,
                                        const void *fallbackMainRam,
                                        std::size_t fallbackMainRamSize) {
    return [descriptors, fallbackMainRam, fallbackMainRamSize](uint32_t ndsAddress, uint8_t *outBuffer, std::size_t length) -> bool {
        if (!outBuffer || length == 0u) return true;
        for (const auto &desc : descriptors) {
            if (!desc.ptr || desc.len == 0u) continue;
            if (ndsAddress >= desc.start && ndsAddress - desc.start <= desc.len &&
                length <= desc.len - (ndsAddress - desc.start)) {
                const auto *src = static_cast<const uint8_t *>(desc.ptr) + (ndsAddress - desc.start);
                std::memcpy(outBuffer, src, length);
                return true;
            }
        }
        if (fallbackMainRam && fallbackMainRamSize > 0u && ndsAddress >= kNdsMainRamStart) {
            const std::size_t off = static_cast<std::size_t>(ndsAddress - kNdsMainRamStart);
            if (off < fallbackMainRamSize && length <= fallbackMainRamSize - off) {
                std::memcpy(outBuffer, static_cast<const uint8_t *>(fallbackMainRam) + off, length);
                return true;
            }
        }
        return false;
    };
}

PlatinumCaptureTracker::PlatinumCaptureTracker(PlatinumRomInfo romInfo,
                                               NdsBusReadFn busReader,
                                               CaptureCallback callback,
                                               uint32_t scanIntervalFrames,
                                               PlatinumRamLayout layout)
    : romInfo_(std::move(romInfo)),
      busReader_(std::move(busReader)),
      callback_(std::move(callback)),
      scanIntervalFrames_(scanIntervalFrames == 0u ? 1u : scanIntervalFrames),
      layout_(layout) {}

void PlatinumCaptureTracker::reset() {
    frameCounter_ = 0;
    baselineStableCount_ = 0;
    lastTrainerId_ = 0;
    lastBaselineFingerprint_ = 0;
    baselineAnchored_ = false;
    seenInstances_.clear();
    reportedCategoryKeys_.clear();
    pendingCandidates_.clear();
}

void PlatinumCaptureTracker::doFrame() {
    if (!romInfo_.isPlatinum || !romInfo_.supportedRamLayout || !busReader_ || !callback_) {
        return;
    }
    ++frameCounter_;
    if (frameCounter_ == 1u || (frameCounter_ % scanIntervalFrames_) == 0u) {
        performScan();
    }
}

void PlatinumCaptureTracker::performScan() {
    uint32_t saveBase = 0u;
    if (!readU32Bus(busReader_, layout_.saveBlockPtrAddress, saveBase)) {
        return;
    }
    if (saveBase < kNdsMainRamStart || saveBase >= kNdsMainRamEnd) {
        return;
    }

    uint32_t partyCount = 0u;
    if (!readU32Bus(busReader_, saveBase + layout_.partyCountOffset, partyCount)) {
        return;
    }
    if (partyCount == 0u || partyCount > 6u) {
        return;
    }

    struct FoundMon {
        DecodedGen4Pokemon mon;
        std::string source;
    };
    std::vector<FoundMon> activeMons;
    std::vector<uint8_t> monBuf(kGen4PartyPokemonSize);
    std::size_t fingerprint = static_cast<std::size_t>(partyCount) * 1315423911u;

    for (uint32_t i = 0; i < partyCount; ++i) {
        const uint32_t addr = saveBase + layout_.partyArrayOffset + i * kGen4PartyPokemonSize;
        if (!busReader_(addr, monBuf.data(), kGen4BoxPokemonSize)) {
            return;
        }
        DecodedGen4Pokemon dec = decodeGen4Pokemon(monBuf.data());
        if (!dec.valid) {
            return;
        }
        fingerprint ^= static_cast<std::size_t>(dec.pid ^ dec.checksum) + 0x9e3779b9u + (fingerprint << 6u) + (fingerprint >> 2u);
        if (!dec.isEgg) {
            activeMons.push_back({std::move(dec), "party"});
        }
    }

    if (layout_.boxStorageOffset != 0u && layout_.boxCount > 0u && layout_.boxSlots > 0u) {
        const uint32_t boxTotal = layout_.boxCount * layout_.boxSlots;
        std::vector<uint8_t> boxBuf(kGen4BoxPokemonSize);
        for (uint32_t slot = 0; slot < boxTotal; ++slot) {
            const uint32_t addr = saveBase + layout_.boxStorageOffset + slot * kGen4BoxPokemonSize;
            if (!busReader_(addr, boxBuf.data(), kGen4BoxPokemonSize)) {
                continue;
            }
            DecodedGen4Pokemon dec = decodeGen4Pokemon(boxBuf.data());
            if (!dec.valid || dec.isEgg) {
                continue;
            }
            fingerprint ^= static_cast<std::size_t>(dec.pid ^ dec.checksum) + 0x9e3779b9u + (fingerprint << 6u) + (fingerprint >> 2u);
            activeMons.push_back({std::move(dec), "pc_box"});
        }
    }

    if (activeMons.empty()) {
        return;
    }

    if (!baselineAnchored_) {
        if (lastBaselineFingerprint_ == fingerprint) {
            ++baselineStableCount_;
        } else {
            lastBaselineFingerprint_ = fingerprint;
            baselineStableCount_ = 1u;
        }
        if (baselineStableCount_ < kRequiredStableScans) {
            return;
        }
        lastTrainerId_ = activeMons[0].mon.otId;
        for (const auto &entry : activeMons) {
            seenInstances_.insert(makeInstanceKey(entry.mon.pid, entry.mon.otId, entry.mon.nationalDexNumber));
            reportedCategoryKeys_.insert(makeCategoryKey(entry.mon.nationalDexNumber, entry.mon.isShiny));
        }
        baselineAnchored_ = true;
        pendingCandidates_.clear();
        return;
    }

    std::unordered_set<uint64_t> activeInstanceKeys;
    for (const auto &entry : activeMons) {
        const uint64_t instKey = makeInstanceKey(entry.mon.pid, entry.mon.otId, entry.mon.nationalDexNumber);
        activeInstanceKeys.insert(instKey);
        if (seenInstances_.count(instKey)) {
            continue;
        }
        const uint32_t catKey = makeCategoryKey(entry.mon.nationalDexNumber, entry.mon.isShiny);
        if (reportedCategoryKeys_.count(catKey)) {
            seenInstances_.insert(instKey);
            continue;
        }
        auto it = pendingCandidates_.find(instKey);
        if (it == pendingCandidates_.end()) {
            PlatinumCaptureEvent ev;
            ev.nationalDexNumber = entry.mon.nationalDexNumber;
            ev.isShiny = entry.mon.isShiny;
            ev.pid = entry.mon.pid;
            ev.otId = entry.mon.otId;
            ev.metLocationId = entry.mon.metLocationId;
            ev.metLocationName = entry.mon.metLocationName;
            ev.storageSource = entry.source;
            ev.gameCode = romInfo_.gameCode;
            ev.romRevision = romInfo_.revision;
            pendingCandidates_.emplace(instKey, PendingCandidate{std::move(ev), 1u});
        } else {
            ++it->second.stableCount;
            if (it->second.stableCount >= kRequiredStableScans) {
                PlatinumCaptureEvent confirmed = it->second.event;
                seenInstances_.insert(instKey);
                reportedCategoryKeys_.insert(catKey);
                pendingCandidates_.erase(it);
                callback_(confirmed);
            }
        }
    }

    for (auto it = pendingCandidates_.begin(); it != pendingCandidates_.end();) {
        if (!activeInstanceKeys.count(it->first)) {
            it = pendingCandidates_.erase(it);
        } else {
            ++it;
        }
    }
}

} // namespace pokedex
} // namespace brum

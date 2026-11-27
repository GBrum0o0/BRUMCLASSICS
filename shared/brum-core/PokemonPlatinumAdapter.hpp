#ifndef BRUM_POKEMON_PLATINUM_ADAPTER_HPP
#define BRUM_POKEMON_PLATINUM_ADAPTER_HPP

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace brum {
namespace pokedex {

struct NdsMemoryDescriptor {
    const void *ptr = nullptr;
    std::size_t start = 0;
    std::size_t len = 0;
};

using NdsBusReadFn = std::function<bool(uint32_t ndsAddress, uint8_t *outBuffer, std::size_t length)>;

struct PlatinumRomInfo {
    bool isPlatinum = false;
    bool supportedRamLayout = false;
    std::string gameTitle;
    std::string gameCode;
    uint8_t revision = 0;
};

struct DecodedGen4Pokemon {
    bool valid = false;
    uint32_t pid = 0;
    uint32_t otId = 0;
    uint16_t nationalDexNumber = 0;
    uint16_t checksum = 0;
    uint16_t metLocationId = 0;
    bool isShiny = false;
    bool isEgg = false;
    std::string metLocationName;
};

struct PlatinumCaptureEvent {
    uint16_t nationalDexNumber = 0;
    bool isShiny = false;
    uint32_t pid = 0;
    uint32_t otId = 0;
    uint16_t metLocationId = 0;
    std::string metLocationName;
    std::string storageSource; // "party" | "pc_box"
    std::string gameCode;
    uint8_t romRevision = 0;
};

struct PlatinumRamLayout {
    uint32_t saveBlockPtrAddress = 0x02101D40u; // US Platinum (CPUE) SaveData global pointer
    uint32_t partyCountOffset = 0xD094u;        // Party count uint32 relative to SaveData
    uint32_t partyArrayOffset = 0xD098u;        // 6 * 236-byte Gen 4 Party structs relative to SaveData
    uint32_t boxStorageOffset = 0x0CF04u;       // Optional PC storage base relative to SaveData (or 0 if disabled)
    uint32_t boxCount = 18u;
    uint32_t boxSlots = 30u;
};

PlatinumRomInfo identifyPlatinumRom(const uint8_t *romData, std::size_t romSize);
bool isGen4Shiny(uint32_t otId, uint32_t pid);
std::string sinnohLocationName(uint16_t metLocationId);

DecodedGen4Pokemon decodeGen4Pokemon(const uint8_t raw136[136]);
void encodeGen4PokemonForTest(uint8_t outRaw136[136],
                              uint32_t pid,
                              uint32_t otId,
                              uint16_t nationalDexNumber,
                              uint16_t metLocationId,
                              bool isEgg = false,
                              bool corruptChecksum = false);

NdsBusReadFn makeNdsDescriptorBusReader(const std::vector<NdsMemoryDescriptor> &descriptors,
                                        const void *fallbackMainRam = nullptr,
                                        std::size_t fallbackMainRamSize = 0);

class PlatinumCaptureTracker {
public:
    using CaptureCallback = std::function<void(const PlatinumCaptureEvent &)>;

    PlatinumCaptureTracker(PlatinumRomInfo romInfo,
                           NdsBusReadFn busReader,
                           CaptureCallback callback,
                           uint32_t scanIntervalFrames = 30u,
                           PlatinumRamLayout layout = PlatinumRamLayout{});

    void doFrame();
    void reset();

    bool isBaselineAnchored() const { return baselineAnchored_; }

private:
    struct PendingCandidate {
        PlatinumCaptureEvent event;
        uint32_t stableCount = 0;
    };

    void performScan();

    PlatinumRomInfo romInfo_;
    NdsBusReadFn busReader_;
    CaptureCallback callback_;
    uint32_t scanIntervalFrames_ = 30u;
    PlatinumRamLayout layout_{};
    uint32_t frameCounter_ = 0;
    uint32_t baselineStableCount_ = 0;
    uint32_t lastTrainerId_ = 0;
    std::size_t lastBaselineFingerprint_ = 0;
    bool baselineAnchored_ = false;
    std::unordered_set<uint64_t> seenInstances_;
    std::unordered_set<uint32_t> reportedCategoryKeys_;
    std::unordered_map<uint64_t, PendingCandidate> pendingCandidates_;
};

} // namespace pokedex
} // namespace brum

#endif // BRUM_POKEMON_PLATINUM_ADAPTER_HPP

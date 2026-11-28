#ifndef BRUM_POKEMON_FIRERED_ADAPTER_HPP
#define BRUM_POKEMON_FIRERED_ADAPTER_HPP

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace brum {
namespace pokedex {

struct GbaMemoryDescriptor {
    const void *ptr = nullptr;
    std::size_t start = 0;
    std::size_t len = 0;
    std::size_t offset = 0;
};

using GbaBusReadFn = std::function<bool(uint32_t gbaAddress, uint8_t *outBuffer, std::size_t length)>;

struct FireRedRomInfo {
    bool isFireRed = false;
    bool supportedRamLayout = false;
    std::string gameTitle;
    std::string gameCode;
    uint8_t revision = 0;
};

struct DecodedGen3Pokemon {
    bool valid = false;
    uint32_t personality = 0;
    uint32_t otId = 0;
    uint16_t internalSpecies = 0;
    uint16_t nationalDexNumber = 0;
    uint16_t checksum = 0;
    uint8_t metLocationId = 0;
    uint8_t metLevel = 0;
    bool isShiny = false;
    bool isEgg = false;
    std::string metLocationName;
};

struct FireRedCaptureEvent {
    uint16_t nationalDexNumber = 0;
    uint16_t internalSpecies = 0;
    bool isShiny = false;
    uint32_t personality = 0;
    uint32_t otId = 0;
    uint8_t metLocationId = 0;
    std::string metLocationName;
    std::string storageSource; // "party" | "pc_box" | "save_diff"
    std::string gameCode;
    uint8_t romRevision = 0;
};

struct FireRedSaveSnapshot {
    bool valid = false;
    uint32_t activeSlot = 0;
    uint32_t saveCounter = 0;
    uint32_t trainerId = 0;
    std::array<uint8_t, 52> pokedexOwned{};
    std::vector<DecodedGen3Pokemon> partyPokemon;
    std::vector<DecodedGen3Pokemon> boxPokemon;
};

FireRedRomInfo identifyFireRedRom(const uint8_t *romData, std::size_t romSize);
uint16_t internalSpeciesToNationalDex(uint16_t internalSpecies);
std::string fireRedLocationName(uint8_t metLocationId);
bool isGen3Shiny(uint32_t otId, uint32_t personality);
bool isPokedexOwnedBitSet(const uint8_t owned52[52], uint16_t nationalDexNumber);

DecodedGen3Pokemon decodeBoxPokemon(const uint8_t raw80[80]);
void encodeBoxPokemonForTest(uint8_t outRaw80[80],
                             uint32_t personality,
                             uint32_t otId,
                             uint16_t internalSpecies,
                             uint8_t metLocationId,
                             bool isEgg = false,
                             bool isBadEgg = false,
                             bool corruptChecksum = false);

GbaBusReadFn makeDescriptorBusReader(const std::vector<GbaMemoryDescriptor> &descriptors,
                                     const void *fallbackEwram = nullptr,
                                     std::size_t fallbackEwramSize = 0);

FireRedSaveSnapshot inspectFireRedSave128K(const uint8_t *saveData, std::size_t saveSize);
std::vector<FireRedCaptureEvent> diffFireRedSaveSnapshots(const FireRedSaveSnapshot &before,
                                                          const FireRedSaveSnapshot &after,
                                                          const std::string &gameCode = "BPRE",
                                                          uint8_t romRevision = 0);

class FireRedCaptureTracker {
public:
    using CaptureCallback = std::function<void(const FireRedCaptureEvent &)>;

    FireRedCaptureTracker(FireRedRomInfo romInfo,
                          GbaBusReadFn busReader,
                          CaptureCallback onCapture,
                          uint32_t scanIntervalFrames = 15);

    void doFrame();
    void reset();

    bool isBaselineAnchored() const { return baselineAnchored_; }
    uint32_t anchoredTrainerId() const { return anchoredTrainerId_; }
    std::size_t knownInstanceCount() const { return anchoredInstances_.size(); }

    // Seeds baseline from an existing 128KB save snapshot prior to gameplay so that
    // newly added Pokémon in RAM are detected even on the very first frame.
    void seedBaselineFromSave(const FireRedSaveSnapshot &snapshot);

private:
    struct CandidateObservation {
        FireRedCaptureEvent event;
        uint32_t consecutiveScans = 0;
    };

    static uint64_t instanceKey(uint32_t personality, uint32_t otId, uint16_t nationalDex);
    void performScan();

    FireRedRomInfo romInfo_;
    GbaBusReadFn busReader_;
    CaptureCallback onCapture_;
    uint32_t scanIntervalFrames_ = 15;
    uint64_t frameCounter_ = 0;

    bool baselineAnchored_ = false;
    uint32_t anchoredTrainerId_ = 0;
    uint32_t pendingBaselineTrainerId_ = 0;
    uint32_t pendingBaselineStability_ = 0;
    std::unordered_set<uint64_t> pendingBaselineSet_;
    std::unordered_set<uint64_t> anchoredInstances_;
    std::unordered_map<uint64_t, CandidateObservation> pendingCandidates_;
};

} // namespace pokedex
} // namespace brum

#endif // BRUM_POKEMON_FIRERED_ADAPTER_HPP

#pragma once
#include <array>
#include <optional>
#include <string_view>

namespace brum {
enum class VirtualFace { one, two, four, sony, segaSix, n64, neoGeo, wonderSwan, arcadeSix };
struct VirtualControlProfile {
    std::string_view systemID;
    VirtualFace face;
    bool leftStick = false;
    bool rightStick = false;
    bool select = true;
    bool shoulders = false;
    bool triggers = false;
};

// These are known BRUM Core system IDs, not a generic fallback. A new system must
// receive an explicit profile before its virtual controls can be shown.
inline std::optional<VirtualControlProfile> virtualControlProfile(std::string_view systemID) {
    static constexpr std::array<VirtualControlProfile, 25> profiles {{
        {"gb", VirtualFace::two}, {"gbc", VirtualFace::two},
        {"gba", VirtualFace::two, false, false, true, true},
        {"nds", VirtualFace::four, false, false, true, true},
        {"neogeo", VirtualFace::neoGeo},
        {"sms", VirtualFace::two, false, false, false},
        {"gg", VirtualFace::two, false, false, false},
        {"nes", VirtualFace::two},
        {"pce", VirtualFace::two},
        {"sfc", VirtualFace::four, false, false, true, true},
        {"ws", VirtualFace::wonderSwan},
        {"wsc", VirtualFace::wonderSwan},
        {"n64", VirtualFace::n64, true, false, true, true},
        {"md", VirtualFace::segaSix}, {"segacd", VirtualFace::segaSix},
        {"32x", VirtualFace::segaSix},
        {"psx", VirtualFace::sony, false, false, true, true, true},
        {"psp", VirtualFace::sony, true, false, true, true},
        {"dreamcast", VirtualFace::four, true, false, false, false, true},
        {"saturn", VirtualFace::segaSix, false, false, true, true},
        {"arcade", VirtualFace::arcadeSix, false, false, true},
        {"atari2600", VirtualFace::one},
        {"3ds", VirtualFace::four, true, true, true, true, true},
        {"gamecube", VirtualFace::four, true, true, false, false, true},
        {"ps2", VirtualFace::sony, true, true, true, true, true}
    }};
    for (const auto& profile : profiles) if (profile.systemID == systemID) return profile;
    return std::nullopt;
}
} // namespace brum

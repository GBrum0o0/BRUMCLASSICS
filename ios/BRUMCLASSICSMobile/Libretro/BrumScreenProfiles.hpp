#pragma once
#include "../../../shared/brum-core/ScreenManager.hpp"

namespace brum {
// Atlas layouts belong to adapters, never to ScreenManager. Unrecognized output
// stays a single surface rather than guessing and sending touch to the wrong area.
inline std::vector<Screen> libretroScreens(const std::string& core, unsigned width, unsigned height) {
    if (core == "skyemu" && width == 256 && height == 384)
        return {{"primary", "video", {0, 0, 1, 0.5}, 256, 192, false},
                {"secondary", "video", {0, 0.5, 1, 0.5}, 256, 192, true}};
    // Citra adapter must fix Default Top-Bottom Screen + native resolution.
    if (core == "citra" && width == 400 && height == 480)
        return {{"primary", "video", {0, 0, 1, 0.5}, 400, 240, false},
                {"secondary", "video", {0.1, 0.5, 0.8, 0.5}, 320, 240, true}};
    return {{"primary", "video", {0, 0, 1, 1}, static_cast<double>(width), static_cast<double>(height), false}};
}
}

#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace brum {

struct StickPosition { double x; double y; };

// Coordinates use Libretro's convention: right/down are positive. Keep the
// virtual stick circular and rescale a small touch dead zone for fine motion.
inline StickPosition virtualStick(double x, double y, double radius, double deadZone = 0.08) {
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(radius) || radius <= 0 ||
        !std::isfinite(deadZone) || deadZone < 0 || deadZone >= 1) return {0, 0};
    const double nx = x / radius;
    const double ny = y / radius;
    const double magnitude = std::hypot(nx, ny);
    if (magnitude <= deadZone) return {0, 0};
    const double scaled = (std::min(1.0, magnitude) - deadZone) / (1.0 - deadZone);
    return {nx / magnitude * scaled, ny / magnitude * scaled};
}

enum N64CButton : uint8_t { cUp = 1, cDown = 2, cLeft = 4, cRight = 8 };

// This pinned Mupen64Plus-Next revision interprets positive right-stick X as
// C-left and negative X as C-right; Y follows Libretro's down-positive axis.
inline StickPosition n64CButtons(uint8_t held) {
    return {double(bool(held & cLeft)) - double(bool(held & cRight)),
            double(bool(held & cDown)) - double(bool(held & cUp))};
}

} // namespace brum

#pragma once
#include <cmath>
#include <cstdint>

namespace brum {
enum DPadDirection : uint8_t { up = 1, down = 2, left = 4, right = 8 };

// One continuous touch surface, not four isolated buttons. The caller owns
// pointer identity; this function only maps its current local displacement.
inline uint8_t dpadDirections(double x, double y, double radius, double deadZone = 0.16) {
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(radius) || radius <= 0 ||
        !std::isfinite(deadZone) || deadZone < 0 || deadZone >= 1) return 0;
    const double threshold = radius * deadZone;
    uint8_t mask = 0;
    if (x < -threshold) mask |= left;
    if (x > threshold) mask |= right;
    if (y < -threshold) mask |= up;
    if (y > threshold) mask |= down;
    return mask;
}
} // namespace brum

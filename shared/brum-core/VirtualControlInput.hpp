#pragma once
#include <cmath>
#include <cstdint>

namespace brum {
enum DPadDirection : uint8_t { up = 1, down = 2, left = 4, right = 8 };

// One continuous touch surface, not four isolated buttons. The caller owns
// pointer identity; this function only maps its current local displacement.
inline uint8_t dpadDirections(double x, double y, double radius, double deadZone = 0.16,
                              uint8_t previous = 0) {
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(radius) || radius <= 0 ||
        !std::isfinite(deadZone) || deadZone < 0 || deadZone >= 1) return 0;
    const double distance = std::hypot(x, y);
    // A smaller release zone prevents jitter around the centre from repeating
    // a held direction. Scale both zones with the actual on-screen control.
    const double threshold = radius * deadZone * (previous ? 0.75 : 1.0);
    if (distance <= threshold || distance > radius * 1.5) return 0;
    const uint8_t horizontal = x < 0 ? left : right;
    const uint8_t vertical = y < 0 ? up : down;
    const double angle = std::atan2(std::abs(y), std::abs(x)) * (180.0 / 3.14159265358979323846);
    // Cardinal sectors span 60 degrees; deliberate diagonals span 30 degrees.
    // Keep a five-degree margin around the previous sector to avoid flicker.
    if (previous == horizontal && angle <= 35.0) return horizontal;
    if (previous == vertical && angle >= 55.0) return vertical;
    if (previous == (horizontal | vertical) && angle >= 25.0 && angle <= 65.0)
        return horizontal | vertical;
    if (angle <= 30.0) return horizontal;
    if (angle >= 60.0) return vertical;
    return horizontal | vertical;
}
} // namespace brum

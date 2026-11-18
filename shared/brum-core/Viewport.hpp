#pragma once
#include <algorithm>
#include <cmath>
#include <optional>

namespace brum {
struct Point { double x = 0, y = 0; };
struct Rect {
    double x = 0, y = 0, width = 0, height = 0;
    bool contains(Point point) const {
        return width > 0 && height > 0 && point.x >= x && point.y >= y &&
            point.x < x + width && point.y < y + height;
    }
};
enum class ScaleMode { fit, crop, integer };
struct Viewport {
    Rect available;
    Rect frame;
    double scale = 0;
    double contentWidth = 0, contentHeight = 0;

    bool valid() const { return scale > 0 && frame.width > 0 && frame.height > 0; }
    // Reject letterbox and clipped-off content. Coordinates are normalized to
    // the unrotated native image and remain independent of display density.
    std::optional<Point> toContent(Point point) const {
        if (!valid() || !available.contains(point) || !frame.contains(point)) return std::nullopt;
        return Point {(point.x - frame.x) / frame.width, (point.y - frame.y) / frame.height};
    }
    Point toDisplay(Point normalized) const {
        return {frame.x + normalized.x * frame.width, frame.y + normalized.y * frame.height};
    }
};
inline Viewport calculateViewport(Rect available, double contentWidth, double contentHeight,
                                  ScaleMode mode = ScaleMode::fit) {
    Viewport result {available, {}, 0, contentWidth, contentHeight};
    if (!std::isfinite(available.x) || !std::isfinite(available.y) ||
        !std::isfinite(available.width) || !std::isfinite(available.height) ||
        !std::isfinite(contentWidth) || !std::isfinite(contentHeight) ||
        available.width <= 0 || available.height <= 0 || contentWidth <= 0 || contentHeight <= 0) return result;
    const double sx = available.width / contentWidth, sy = available.height / contentHeight;
    double scale = mode == ScaleMode::crop ? std::max(sx, sy) : std::min(sx, sy);
    if (mode == ScaleMode::integer && scale >= 1) scale = std::floor(scale);
    if (!std::isfinite(scale) || scale <= 0) return result;
    const double width = contentWidth * scale, height = contentHeight * scale;
    if (!std::isfinite(width) || !std::isfinite(height)) return result;
    result.scale = scale;
    result.frame = {available.x + (available.width - width) / 2,
                    available.y + (available.height - height) / 2, width, height};
    return result;
}
} // namespace brum

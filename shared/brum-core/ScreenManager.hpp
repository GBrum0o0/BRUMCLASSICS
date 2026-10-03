#pragma once
#include <algorithm>
#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>

namespace brum {
struct Point { double x = 0, y = 0; };
struct Rect {
    double x = 0, y = 0, width = 0, height = 0;
    bool contains(Point p) const {
        return width > 0 && height > 0 && p.x >= x && p.y >= y && p.x <= x + width && p.y <= y + height;
    }
};
// An adapter supplies an atlas crop (normalized), native dimensions and a stable
// screen ID. Separate textures can use a full crop and their own surface ID.
struct Screen {
    std::string id, surfaceID;
    Rect crop;
    double width = 0, height = 0;
    bool touch = false;
};
enum class Layout { vertical, verticalReverse, horizontal, horizontalReverse, primaryOnly, secondaryOnly };
struct Placement {
    Screen screen;
    Rect frame;
    unsigned quarterTurns = 0;
};
struct Touch {
    bool pressed = false;
    std::string screenID;
    Point local; // 0..1 in the original, unrotated screen
    Point atlas;
};
class ScreenManager {
public:
    std::vector<Screen> screens;
    Layout layout = Layout::vertical;
    unsigned quarterTurns = 0;
    double scale = 1;
    // Routing is local metadata, not a streaming implementation. Unassigned
    // screens belong to "local"; transports may consume placements by display.
    std::string displayID = "local";
    std::unordered_map<std::string, std::string> screenDisplays;

    std::vector<Placement> place(Rect viewport) const {
        if (!std::isfinite(viewport.x) || !std::isfinite(viewport.y) ||
            !std::isfinite(viewport.width) || !std::isfinite(viewport.height) ||
            !std::isfinite(scale) || viewport.width <= 0 || viewport.height <= 0) return {};
        std::vector<Screen> selected = screens;
        if (layout == Layout::primaryOnly && selected.size() > 1) selected.resize(1);
        if (layout == Layout::secondaryOnly) {
            if (selected.size() < 2) return {};
            selected = {selected[1]};
        }
        selected.erase(std::remove_if(selected.begin(), selected.end(), [this](const Screen& s) {
            const auto destination = screenDisplays.find(s.id);
            return (destination == screenDisplays.end() ? "local" : destination->second) != displayID;
        }), selected.end());
        if (layout == Layout::horizontalReverse || layout == Layout::verticalReverse)
            std::reverse(selected.begin(), selected.end());
        const bool horizontal = layout == Layout::horizontal || layout == Layout::horizontalReverse;
        const bool rotated = quarterTurns % 2 != 0;
        double totalW = 0, totalH = 0;
        for (const auto& s : selected) {
            if (!std::isfinite(s.width) || !std::isfinite(s.height) || s.width <= 0 || s.height <= 0 ||
                !std::isfinite(s.crop.x) || !std::isfinite(s.crop.y) ||
                !std::isfinite(s.crop.width) || !std::isfinite(s.crop.height) ||
                s.crop.x < 0 || s.crop.y < 0 || s.crop.width <= 0 || s.crop.height <= 0 ||
                s.crop.x + s.crop.width > 1 || s.crop.y + s.crop.height > 1) return {};
            const double w = rotated ? s.height : s.width, h = rotated ? s.width : s.height;
            totalW = horizontal ? totalW + w : std::max(totalW, w);
            totalH = horizontal ? std::max(totalH, h) : totalH + h;
        }
        if (totalW == 0 || totalH == 0) return {};
        const double factor = std::min(viewport.width / totalW, viewport.height / totalH) * std::clamp(scale, 0.25, 1.0);
        double offset = 0;
        std::vector<Placement> result;
        for (const auto& s : selected) {
            const double w = (rotated ? s.height : s.width) * factor;
            const double h = (rotated ? s.width : s.height) * factor;
            Rect frame {viewport.x + (viewport.width - (horizontal ? totalW * factor : w)) / 2 + (horizontal ? offset : 0),
                        viewport.y + (viewport.height - (horizontal ? h : totalH * factor)) / 2 + (horizontal ? 0 : offset), w, h};
            result.push_back({s, frame, quarterTurns % 4});
            offset += horizontal ? w : h;
        }
        return result;
    }

    static Touch hitTest(Point point, const std::vector<Placement>& placements) {
        for (const auto& p : placements) {
            if (!p.screen.touch || !p.frame.contains(point)) continue;
            double u = (point.x - p.frame.x) / p.frame.width;
            double v = (point.y - p.frame.y) / p.frame.height;
            Point local;
            switch (p.quarterTurns % 4) {
                case 1: local = {v, 1 - u}; break;
                case 2: local = {1 - u, 1 - v}; break;
                case 3: local = {1 - v, u}; break;
                default: local = {u, v}; break;
            }
            const Rect crop = p.screen.crop;
            return {true, p.screen.id, local, {crop.x + local.x * crop.width, crop.y + local.y * crop.height}};
        }
        return {};
    }
};
}

#pragma once
#include <array>
#include <cstdint>
#include <algorithm>
#include <cmath>

namespace brum {
enum class InputSource : unsigned { virtualPad, controller, keyboard, remote, count };
// Session-thread only. Platform/network producers must dispatch to that thread.
class InputState {
    std::array<uint16_t, static_cast<unsigned>(InputSource::count)> buttons {};
    std::array<std::array<int16_t, 4>, static_cast<unsigned>(InputSource::count)> axes {};
public:
    void setAxis(InputSource source, unsigned stick, unsigned axis, double value) {
        const auto index = static_cast<unsigned>(source);
        if (index >= axes.size() || stick > 1 || axis > 1) return;
        axes[index][stick * 2 + axis] = std::isfinite(value)
            ? static_cast<int16_t>(std::lround(std::clamp(value, -1.0, 1.0) * 32767)) : 0;
    }
    int16_t analog(unsigned stick, unsigned axis) const {
        if (stick > 1 || axis > 1) return 0;
        int16_t result = 0;
        for (const auto& source : axes) {
            const int16_t value = source[stick * 2 + axis];
            if (std::abs(static_cast<int>(value)) > std::abs(static_cast<int>(result))) result = value;
        }
        return result;
    }
    void set(InputSource source, unsigned button, bool pressed) {
        const auto index = static_cast<unsigned>(source);
        if (index >= buttons.size() || button >= 16) return;
        const uint16_t bit = static_cast<uint16_t>(1u << button);
        if (pressed) buttons[index] |= bit; else buttons[index] &= ~bit;
    }
    bool pressed(unsigned button) const {
        if (button >= 16) return false;
        for (const auto mask : buttons) if (mask & (1u << button)) return true;
        return false;
    }
    void release(InputSource source) {
        const auto index = static_cast<unsigned>(source);
        if (index < buttons.size()) { buttons[index] = 0; axes[index].fill(0); }
    }
    void clear() { buttons.fill(0); for (auto& source : axes) source.fill(0); }
};
}

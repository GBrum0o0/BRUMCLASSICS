#pragma once
#include <array>
#include <cstdint>

namespace brum {
enum class InputSource : unsigned { virtualPad, controller, keyboard, remote, count };
// Session-thread only. Platform/network producers must dispatch to that thread.
class InputState {
    std::array<uint16_t, static_cast<unsigned>(InputSource::count)> buttons {};
public:
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
        if (index < buttons.size()) buttons[index] = 0;
    }
    void clear() { buttons.fill(0); }
};
}

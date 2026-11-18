#pragma once

#include <algorithm>
#include <cmath>
#include <cctype>
#include <string>
#include <string_view>

namespace brum {
// The loaded core is authoritative. Folder/extension routing only selects a
// candidate; it must never override the formats advertised by that candidate.
inline bool acceptsContentExtension(std::string_view advertised, std::string extension) {
    if (advertised.empty() || extension.empty()) return false;
    if (extension.front() == '.') extension.erase(extension.begin());
    auto normalize = [](std::string value) {
        const auto first = value.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) return std::string{};
        value = value.substr(first, value.find_last_not_of(" \t\r\n") - first + 1);
        std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
            return static_cast<char>(std::tolower(c));
        });
        return value;
    };
    extension = normalize(extension);
    if (extension.empty()) return false;
    for (std::size_t start = 0; start < advertised.size();) {
        const auto end = advertised.find('|', start);
        const auto token = advertised.substr(start, end == std::string_view::npos ? end : end - start);
        if (normalize(std::string(token)) == extension) return true;
        if (end == std::string_view::npos) break;
        start = end + 1;
    }
    return false;
}

inline bool validAVTiming(double fps, double sampleRate) {
    // Reject invalid contracts, without assigning a common FPS to all systems.
    return std::isfinite(fps) && fps > 0 && std::isfinite(sampleRate) && sampleRate > 0;
}
} // namespace brum

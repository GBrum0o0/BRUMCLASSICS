#ifndef BRUM_ACHIEVEMENT_DEDUPLICATOR_HPP
#define BRUM_ACHIEVEMENT_DEDUPLICATOR_HPP

#include <cctype>
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <unordered_set>

namespace brum {

class AchievementDeduplicator {
public:
    explicit AchievementDeduplicator(std::size_t capacity = 512)
        : capacity_(capacity == 0 ? 1 : capacity) {}

    static std::string canonicalKey(const std::string &eventId,
                                    uint32_t gameId,
                                    const std::string &achievementId,
                                    const std::string &title = {}) {
        const auto trimLower = [](const std::string &input) {
            std::size_t start = 0;
            while (start < input.size() && std::isspace(static_cast<unsigned char>(input[start]))) ++start;
            std::size_t end = input.size();
            while (end > start && std::isspace(static_cast<unsigned char>(input[end - 1]))) --end;
            std::string out;
            out.reserve(end - start);
            for (std::size_t i = start; i < end; ++i) {
                out.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(input[i]))));
            }
            return out;
        };

        const std::string cleanEvent = trimLower(eventId);
        if (!cleanEvent.empty()) {
            return "evt:" + cleanEvent;
        }
        const std::string cleanAch = trimLower(achievementId);
        if (!cleanAch.empty()) {
            return "ra:" + std::to_string(gameId) + ":" + cleanAch;
        }
        return "title:" + std::to_string(gameId) + ":" + trimLower(title);
    }

    bool markIfNew(const std::string &eventId,
                   uint32_t gameId,
                   const std::string &achievementId,
                   const std::string &title = {}) {
        const std::string key = canonicalKey(eventId, gameId, achievementId, title);
        std::lock_guard<std::mutex> lock(mutex_);
        if (seen_.find(key) != seen_.end()) {
            return false;
        }
        if (order_.size() >= capacity_) {
            const std::string &oldest = order_.front();
            seen_.erase(oldest);
            order_.pop_front();
        }
        order_.push_back(key);
        seen_.insert(key);
        return true;
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        seen_.clear();
        order_.clear();
    }

private:
    std::size_t capacity_;
    std::mutex mutex_;
    std::deque<std::string> order_;
    std::unordered_set<std::string> seen_;
};

} // namespace brum

#endif

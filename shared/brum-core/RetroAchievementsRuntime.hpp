#ifndef BRUM_RETROACHIEVEMENTS_RUNTIME_HPP
#define BRUM_RETROACHIEVEMENTS_RUNTIME_HPP

#include "AchievementDeduplicator.hpp"
#include "rc_client.h"
#include "rc_libretro.h"

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace brum {

struct ConfirmedAchievementUnlock {
    std::string eventId;
    uint32_t gameId = 0;
    uint32_t achievementId = 0;
    std::string title;
    std::string description;
    std::string badgeUrl;
    std::string gameTitle;
    std::string consoleName;
    std::string hash;
    uint32_t points = 0;
    bool hardcore = false;
};

struct RetroAchievementsStatus {
    std::string state = "disabled"; // disabled | unsupported | logging_in | identifying | active | error
    std::string message;
    std::string username;
    std::string token;
    std::string gameTitle;
    std::string hash;
    std::string richPresence;
    uint32_t consoleId = 0;
    uint32_t gameId = 0;
    uint32_t unlockedCount = 0;
    uint32_t totalAchievements = 0;
    bool hardcore = false;
    bool disconnected = false;
};

struct RetroAchievementsCallbacks {
    using HttpDoneFn = std::function<void(int httpStatus, const std::string &responseBody)>;
    using HttpPostFn = std::function<void(const std::string &url,
                                          const std::string &postData,
                                          const std::string &contentType,
                                          HttpDoneFn done)>;
    using CoreMemoryFn = std::function<void(uint32_t id, void **data, size_t *size)>;
    using ConfirmedUnlockFn = std::function<void(const ConfirmedAchievementUnlock &)>;
    using StatusChangedFn = std::function<void(const RetroAchievementsStatus &)>;
    using LoginCompletedFn = std::function<void(bool success,
                                                const std::string &username,
                                                const std::string &token,
                                                const std::string &errorMessage)>;

    std::string userAgent = "BRUMCLASSICS/1.0";
    HttpPostFn httpPost;
    CoreMemoryFn getCoreMemory;
    ConfirmedUnlockFn onConfirmedUnlock;
    StatusChangedFn onStatusChanged;
    LoginCompletedFn onLoginCompleted;
};

class RetroAchievementsRuntime {
public:
    explicit RetroAchievementsRuntime(RetroAchievementsCallbacks callbacks);
    ~RetroAchievementsRuntime();

    RetroAchievementsRuntime(const RetroAchievementsRuntime &) = delete;
    RetroAchievementsRuntime &operator=(const RetroAchievementsRuntime &) = delete;

    // Supports testing against a custom mock/local server in automated verification.
    void setHost(const std::string &hostname);
    void setHardcoreEnabled(bool enabled);

    void loginWithPassword(const std::string &username, const std::string &password);
    void loginWithToken(const std::string &username, const std::string &token);

    void configureMemoryMap(const struct retro_memory_map *mmap, uint32_t consoleId);
    void startGame(uint32_t consoleId,
                   const std::string &filePath,
                   const uint8_t *romData = nullptr,
                   size_t romSize = 0,
                   const struct retro_memory_map *mmap = nullptr);

    // Evaluates active triggers for a single emulated frame (must also run during fast-forward).
    void doFrame();
    void idle();
    void reset();
    void unloadGame();

    RetroAchievementsStatus status() const;

    // Marks an external bridge/stream achievement key as seen so native & remote overlays never double-pop.
    bool markExternalEventSeen(const std::string &eventId, uint32_t gameId, const std::string &achievementId, const std::string &title = {});

    // Official HTTP server return helper usable directly by unit tests or platform adapters.
    static bool isAwardResponseConfirmed(int httpStatus, const std::string &responseBody, uint32_t *outAchievementId = nullptr);

private:
    static uint32_t RC_CCONV readMemoryBridge(uint32_t address, uint8_t *buffer, uint32_t numBytes, rc_client_t *client);
    static void RC_CCONV serverCallBridge(const rc_api_request_t *request,
                                          rc_client_server_callback_t callback,
                                          void *callbackData,
                                          rc_client_t *client);
    static void RC_CCONV eventHandlerBridge(const rc_client_event_t *event, rc_client_t *client);
    static rc_clock_t RC_CCONV timeMillisBridge(const rc_client_t *client);
    static void RC_CCONV logMessageBridge(const char *message, const rc_client_t *client);
    static void RC_CCONV loginCallbackBridge(int result, const char *errorMessage, rc_client_t *client, void *userdata);
    static void RC_CCONV loadGameCallbackBridge(int result, const char *errorMessage, rc_client_t *client, void *userdata);
    static void RC_CCONV memoryInfoTrampoline(uint32_t id, rc_libretro_core_memory_info_t *info);

    void handleEvent(const rc_client_event_t *event);
    void handleLoginResult(int result, const char *errorMessage);
    void handleLoadGameResult(int result, const char *errorMessage);
    void handleAwardConfirmed(uint32_t achievementId);
    void maybeEmitConfirmed(uint32_t achievementId);
    void updateSummaryLocked();
    void notifyStatus(const RetroAchievementsStatus &snapshot);

    struct LifetimeGuard { std::recursive_mutex mutex; bool alive = true; };

    RetroAchievementsCallbacks callbacks_;
    std::shared_ptr<LifetimeGuard> lifetime_;
    mutable std::recursive_mutex mutex_;
    rc_client_t *client_ = nullptr;
    rc_libretro_memory_regions_t regions_{};
    bool hasMemoryRegions_ = false;
    bool memoryReady_ = false;
    RetroAchievementsStatus status_;
    std::unordered_map<uint32_t, ConfirmedAchievementUnlock> triggeredPending_;
    std::unordered_set<uint32_t> awardedConfirmed_;
    AchievementDeduplicator deduplicator_;
    std::string pendingFilePath_;
    uint32_t pendingConsoleId_ = 0;
};

} // namespace brum

#endif

#include "RetroAchievementsRuntime.hpp"

#include "rc_api_runtime.h"
#include "rc_consoles.h"
#include "rc_hash.h"

#include <chrono>
#include <cstdio>
#include <cstring>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace brum {
namespace {

thread_local RetroAchievementsCallbacks::CoreMemoryFn *tl_memoryInfoFn = nullptr;

std::string buildBadgeUrl(const rc_client_achievement_t *achievement) {
    if (!achievement) return {};
    if (achievement->badge_url && achievement->badge_url[0] != '\0') {
        return achievement->badge_url;
    }
    char buffer[256] = {};
    if (rc_client_achievement_get_image_url(achievement, RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED, buffer, sizeof(buffer)) == RC_OK) {
        return buffer;
    }
    return {};
}

bool containsQueryParam(const std::string &haystack, const char *needle) {
    return haystack.find(needle) != std::string::npos;
}

#ifdef _WIN32
void *RC_CCONV winOpenFile(const char *path_utf8) {
    if (!path_utf8 || !path_utf8[0]) return nullptr;
    int needed = MultiByteToWideChar(CP_UTF8, 0, path_utf8, -1, nullptr, 0);
    if (needed <= 0) return nullptr;
    std::wstring wide(static_cast<size_t>(needed), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, path_utf8, -1, &wide[0], needed);
    FILE *f = nullptr;
    if (_wfopen_s(&f, wide.c_str(), L"rb") != 0) return nullptr;
    return f;
}

void RC_CCONV winSeekFile(void *file_handle, int64_t offset, int origin) {
    if (file_handle) _fseeki64(static_cast<FILE *>(file_handle), offset, origin);
}

int64_t RC_CCONV winTellFile(void *file_handle) {
    return file_handle ? _ftelli64(static_cast<FILE *>(file_handle)) : 0;
}

size_t RC_CCONV winReadFile(void *file_handle, void *buffer, size_t requested_bytes) {
    return (file_handle && buffer) ? std::fread(buffer, 1, requested_bytes, static_cast<FILE *>(file_handle)) : 0;
}

void RC_CCONV winCloseFile(void *file_handle) {
    if (file_handle) std::fclose(static_cast<FILE *>(file_handle));
}
#endif

} // namespace

RetroAchievementsRuntime::RetroAchievementsRuntime(RetroAchievementsCallbacks callbacks)
    : callbacks_(std::move(callbacks)),
      lifetime_(std::make_shared<LifetimeGuard>()) {
    std::memset(&regions_, 0, sizeof(regions_));
    client_ = rc_client_create(readMemoryBridge, serverCallBridge);
    if (client_) {
        rc_client_set_userdata(client_, this);
        rc_client_set_hardcore_enabled(client_, 0); // Softcore default until validated & audited.
        rc_client_set_event_handler(client_, eventHandlerBridge);
        rc_client_set_get_time_millisecs_function(client_, timeMillisBridge);
        rc_client_enable_logging(client_, RC_CLIENT_LOG_LEVEL_WARN, logMessageBridge);
#ifdef _WIN32
        rc_hash_callbacks_t hashCallbacks;
        std::memset(&hashCallbacks, 0, sizeof(hashCallbacks));
        hashCallbacks.filereader.open = winOpenFile;
        hashCallbacks.filereader.seek = winSeekFile;
        hashCallbacks.filereader.tell = winTellFile;
        hashCallbacks.filereader.read = winReadFile;
        hashCallbacks.filereader.close = winCloseFile;
        rc_client_set_hash_callbacks(client_, &hashCallbacks);
#endif
    }
}

RetroAchievementsRuntime::~RetroAchievementsRuntime() {
    rc_client_t *toDestroy = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        toDestroy = client_;
        client_ = nullptr;
        memoryReady_ = false;
        if (hasMemoryRegions_) {
            rc_libretro_memory_destroy(&regions_);
            hasMemoryRegions_ = false;
        }
    }
    if (lifetime_) {
        std::lock_guard<std::recursive_mutex> lifeLock(lifetime_->mutex);
        lifetime_->alive = false;
        if (toDestroy) {
            rc_client_unload_game(toDestroy);
            rc_client_destroy(toDestroy);
        }
    } else if (toDestroy) {
        rc_client_unload_game(toDestroy);
        rc_client_destroy(toDestroy);
    }
}

void RetroAchievementsRuntime::setHost(const std::string &hostname) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (client_ && !hostname.empty()) {
        rc_client_set_host(client_, hostname.c_str());
    }
}

void RetroAchievementsRuntime::setHardcoreEnabled(bool enabled) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (client_) {
        rc_client_set_hardcore_enabled(client_, enabled ? 1 : 0);
        status_.hardcore = enabled;
    }
}

void RetroAchievementsRuntime::loginWithPassword(const std::string &username, const std::string &password) {
    RetroAchievementsStatus snapshot;
    rc_client_t *c = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        c = client_;
        if (!c || username.empty() || password.empty()) {
            status_.state = "error";
            status_.message = "Informe usuário e senha RetroAchievements.";
            snapshot = status_;
        } else {
            status_.state = "logging_in";
            status_.username = username;
            status_.message = "Autenticando no RetroAchievements...";
            snapshot = status_;
        }
    }
    notifyStatus(snapshot);
    if (c && !username.empty() && !password.empty()) {
        rc_client_begin_login_with_password(c, username.c_str(), password.c_str(), loginCallbackBridge, this);
    } else if (callbacks_.onLoginCompleted) {
        callbacks_.onLoginCompleted(false, username, {}, "Informe usuário e senha RetroAchievements.");
    }
}

void RetroAchievementsRuntime::loginWithToken(const std::string &username, const std::string &token) {
    RetroAchievementsStatus snapshot;
    rc_client_t *c = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        c = client_;
        if (!c || username.empty() || token.empty()) {
            status_.state = "disabled";
            status_.message = "Conta RetroAchievements não configurada.";
            snapshot = status_;
        } else {
            status_.state = "logging_in";
            status_.username = username;
            status_.token = token;
            status_.message = "Validando sessão RetroAchievements...";
            snapshot = status_;
        }
    }
    notifyStatus(snapshot);
    if (c && !username.empty() && !token.empty()) {
        rc_client_begin_login_with_token(c, username.c_str(), token.c_str(), loginCallbackBridge, this);
    }
}

void RetroAchievementsRuntime::configureMemoryMap(const struct retro_memory_map *mmap, uint32_t consoleId) {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    if (hasMemoryRegions_) {
        rc_libretro_memory_destroy(&regions_);
        hasMemoryRegions_ = false;
    }
    memoryReady_ = false;
    if (consoleId == RC_CONSOLE_UNKNOWN || consoleId == RC_CONSOLE_NINTENDO_3DS) {
        return;
    }
    const struct retro_memory_map *effectiveMap = (mmap && mmap->num_descriptors > 0 && mmap->descriptors) ? mmap : nullptr;
    tl_memoryInfoFn = callbacks_.getCoreMemory ? &callbacks_.getCoreMemory : nullptr;
    int valid = rc_libretro_memory_init(
        &regions_,
        effectiveMap,
        callbacks_.getCoreMemory ? memoryInfoTrampoline : nullptr,
        consoleId);
    tl_memoryInfoFn = nullptr;
    hasMemoryRegions_ = true;
    memoryReady_ = valid != 0;
}

void RetroAchievementsRuntime::startGame(uint32_t consoleId,
                                         const std::string &filePath,
                                         const uint8_t *romData,
                                         size_t romSize,
                                         const struct retro_memory_map *mmap) {
    RetroAchievementsStatus snapshot;
    rc_client_t *c = nullptr;
    bool unsupported = (consoleId == RC_CONSOLE_UNKNOWN || consoleId == RC_CONSOLE_NINTENDO_3DS);
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        c = client_;
        triggeredPending_.clear();
        awardedConfirmed_.clear();
        pendingConsoleId_ = consoleId;
        pendingFilePath_ = filePath;
        status_.consoleId = consoleId;
        status_.gameId = 0;
        status_.gameTitle.clear();
        status_.hash.clear();
        status_.richPresence.clear();
        status_.unlockedCount = 0;
        status_.totalAchievements = 0;
        status_.disconnected = false;

        if (unsupported) {
            status_.state = "unsupported";
            status_.message = (consoleId == RC_CONSOLE_NINTENDO_3DS)
                ? "RetroAchievements não possui suporte oficial ativo para Nintendo 3DS neste runtime."
                : "Sistema sem identificação oficial RetroAchievements.";
            snapshot = status_;
        } else if (!c || status_.username.empty() || status_.token.empty()) {
            status_.state = "disabled";
            status_.message = "Entre com usuário e senha RetroAchievements em Configurações → CLASSICS para ativar conquistas.";
            snapshot = status_;
            unsupported = true;
        } else {
            configureMemoryMap(mmap, consoleId);
            status_.state = "identifying";
            status_.message = "Identificando hash oficial da mídia no RetroAchievements...";
            snapshot = status_;
        }
    }
    notifyStatus(snapshot);
    if (!unsupported && c) {
        const char *pathArg = filePath.empty() ? nullptr : filePath.c_str();
        rc_client_begin_identify_and_load_game(c, consoleId, pathArg, romData, romSize, loadGameCallbackBridge, this);
    }
}

void RetroAchievementsRuntime::doFrame() {
    rc_client_t *c = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        if (!client_ || status_.state != "active" || !memoryReady_) return;
        c = client_;
    }
    rc_client_do_frame(c);
}

void RetroAchievementsRuntime::idle() {
    rc_client_t *c = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        if (!client_ || status_.state != "active") return;
        c = client_;
    }
    rc_client_idle(c);
}

void RetroAchievementsRuntime::reset() {
    rc_client_t *c = nullptr;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        c = client_;
    }
    if (c) rc_client_reset(c);
}

void RetroAchievementsRuntime::unloadGame() {
    rc_client_t *c = nullptr;
    RetroAchievementsStatus snapshot;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        c = client_;
        triggeredPending_.clear();
        awardedConfirmed_.clear();
        memoryReady_ = false;
        if (hasMemoryRegions_) {
            rc_libretro_memory_destroy(&regions_);
            hasMemoryRegions_ = false;
        }
        status_.state = "disabled";
        status_.gameId = 0;
        status_.gameTitle.clear();
        status_.richPresence.clear();
        snapshot = status_;
    }
    if (c) rc_client_unload_game(c);
    notifyStatus(snapshot);
}

RetroAchievementsStatus RetroAchievementsRuntime::status() const {
    std::lock_guard<std::recursive_mutex> lock(mutex_);
    return status_;
}

bool RetroAchievementsRuntime::markExternalEventSeen(const std::string &eventId,
                                                     uint32_t gameId,
                                                     const std::string &achievementId,
                                                     const std::string &title) {
    return deduplicator_.markIfNew(eventId, gameId, achievementId, title);
}

bool RetroAchievementsRuntime::isAwardResponseConfirmed(int httpStatus,
                                                          const std::string &responseBody,
                                                          uint32_t *outAchievementId) {
    if (httpStatus != 200 || responseBody.empty()) {
        return false;
    }
    rc_api_server_response_t serverResponse{};
    serverResponse.body = responseBody.data();
    serverResponse.body_length = responseBody.size();
    serverResponse.http_status_code = httpStatus;

    rc_api_award_achievement_response_t parsed{};
    const int rc = rc_api_process_award_achievement_server_response(&parsed, &serverResponse);
    const bool ok = (rc == RC_OK && parsed.response.succeeded != 0 && parsed.awarded_achievement_id != 0);
    if (ok && outAchievementId) {
        *outAchievementId = parsed.awarded_achievement_id;
    }
    rc_api_destroy_award_achievement_response(&parsed);
    return ok;
}

uint32_t RC_CCONV RetroAchievementsRuntime::readMemoryBridge(uint32_t address, uint8_t *buffer, uint32_t numBytes, rc_client_t *client) {
    auto *self = static_cast<RetroAchievementsRuntime *>(rc_client_get_userdata(client));
    if (!self || !buffer || numBytes == 0) return 0;
    std::lock_guard<std::recursive_mutex> lock(self->mutex_);
    if (!self->hasMemoryRegions_ || !self->memoryReady_) return 0;
    return rc_libretro_memory_read(&self->regions_, address, buffer, numBytes);
}

void RC_CCONV RetroAchievementsRuntime::serverCallBridge(const rc_api_request_t *request,
                                                         rc_client_server_callback_t callback,
                                                         void *callbackData,
                                                         rc_client_t *client) {
    auto *self = static_cast<RetroAchievementsRuntime *>(rc_client_get_userdata(client));
    if (!self || !request || !callback || !self->callbacks_.httpPost) {
        if (callback) {
            rc_api_server_response_t errResp{"", 0, RC_API_SERVER_RESPONSE_CLIENT_ERROR};
            callback(&errResp, callbackData);
        }
        return;
    }

    const std::string url = request->url ? request->url : "";
    const std::string postData = request->post_data ? request->post_data : "";
    const std::string contentType = request->content_type ? request->content_type : "application/x-www-form-urlencoded";
    const bool isAwardRequest = containsQueryParam(url, "r=awardachievement") || containsQueryParam(postData, "r=awardachievement");
    std::shared_ptr<LifetimeGuard> life = self->lifetime_;

    self->callbacks_.httpPost(url, postData, contentType, [self, life, isAwardRequest, callback, callbackData](int httpStatus, const std::string &body) {
        if (!life) return;
        std::lock_guard<std::recursive_mutex> lifeLock(life->mutex);
        if (!life->alive) return;

        uint32_t awardedId = 0;
        const bool confirmed = isAwardRequest && isAwardResponseConfirmed(httpStatus, body, &awardedId);

        rc_api_server_response_t serverResponse{};
        serverResponse.body = body.data();
        serverResponse.body_length = body.size();
        serverResponse.http_status_code = (httpStatus > 0 || httpStatus == RC_API_SERVER_RESPONSE_CLIENT_ERROR || httpStatus == RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR)
            ? httpStatus
            : RC_API_SERVER_RESPONSE_RETRYABLE_CLIENT_ERROR;

        callback(&serverResponse, callbackData);

        if (confirmed && awardedId != 0) {
            self->handleAwardConfirmed(awardedId);
        }
    });
}

void RC_CCONV RetroAchievementsRuntime::eventHandlerBridge(const rc_client_event_t *event, rc_client_t *client) {
    auto *self = static_cast<RetroAchievementsRuntime *>(rc_client_get_userdata(client));
    if (self && event) self->handleEvent(event);
}

rc_clock_t RC_CCONV RetroAchievementsRuntime::timeMillisBridge(const rc_client_t *) {
    return static_cast<rc_clock_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch())
            .count());
}

void RC_CCONV RetroAchievementsRuntime::logMessageBridge(const char *, const rc_client_t *) {}

void RC_CCONV RetroAchievementsRuntime::loginCallbackBridge(int result, const char *errorMessage, rc_client_t *client, void *) {
    auto *self = static_cast<RetroAchievementsRuntime *>(rc_client_get_userdata(client));
    if (self) self->handleLoginResult(result, errorMessage);
}

void RC_CCONV RetroAchievementsRuntime::loadGameCallbackBridge(int result, const char *errorMessage, rc_client_t *client, void *) {
    auto *self = static_cast<RetroAchievementsRuntime *>(rc_client_get_userdata(client));
    if (self) self->handleLoadGameResult(result, errorMessage);
}

void RC_CCONV RetroAchievementsRuntime::memoryInfoTrampoline(uint32_t id, rc_libretro_core_memory_info_t *info) {
    if (!info) return;
    info->data = nullptr;
    info->size = 0;
    if (tl_memoryInfoFn && *tl_memoryInfoFn) {
        void *data = nullptr;
        size_t size = 0;
        (*tl_memoryInfoFn)(id, &data, &size);
        info->data = static_cast<uint8_t *>(data);
        info->size = size;
    }
}

void RetroAchievementsRuntime::handleLoginResult(int result, const char *errorMessage) {
    RetroAchievementsStatus snapshot;
    std::string loggedUser, loggedToken, errText;
    const bool ok = (result == RC_OK);
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        if (ok && client_) {
            const rc_client_user_t *user = rc_client_get_user_info(client_);
            if (user) {
                loggedUser = user->username ? user->username : status_.username;
                loggedToken = user->token ? user->token : status_.token;
                status_.username = loggedUser;
                status_.token = loggedToken;
            }
            if (status_.state == "logging_in") {
                status_.state = "disabled";
                status_.message = "Sessão RetroAchievements autenticada.";
            }
        } else {
            errText = (errorMessage && errorMessage[0]) ? errorMessage : rc_error_str(result);
            status_.state = "error";
            status_.message = "Falha no login RetroAchievements: " + errText;
        }
        snapshot = status_;
    }
    notifyStatus(snapshot);
    if (callbacks_.onLoginCompleted) {
        callbacks_.onLoginCompleted(ok, loggedUser, loggedToken, errText);
    }
}

void RetroAchievementsRuntime::handleLoadGameResult(int result, const char *errorMessage) {
    RetroAchievementsStatus snapshot;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        if (result == RC_OK && client_) {
            const rc_client_game_t *game = rc_client_get_game_info(client_);
            if (game && game->id != 0) {
                status_.gameId = game->id;
                status_.gameTitle = game->title ? game->title : "";
                status_.hash = game->hash ? game->hash : "";
                status_.consoleId = game->console_id;
                updateSummaryLocked();
                status_.state = "active";
                status_.message = "Conectado · " + std::to_string(status_.unlockedCount) + "/" + std::to_string(status_.totalAchievements) + " conquistas";
            } else {
                status_.state = "unsupported";
                status_.gameId = 0;
                status_.message = "Jogo não reconhecido pelo RetroAchievements para este hash.";
            }
        } else {
            const std::string detail = (errorMessage && errorMessage[0]) ? errorMessage : rc_error_str(result);
            status_.state = "error";
            status_.gameId = 0;
            status_.message = "RetroAchievements: " + detail;
        }
        snapshot = status_;
    }
    notifyStatus(snapshot);
}

void RetroAchievementsRuntime::handleEvent(const rc_client_event_t *event) {
    if (!event) return;
    switch (event->type) {
        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED: {
            if (!event->achievement) break;
            const uint32_t achId = event->achievement->id;
            {
                std::lock_guard<std::recursive_mutex> lock(mutex_);
                const rc_client_game_t *game = client_ ? rc_client_get_game_info(client_) : nullptr;
                ConfirmedAchievementUnlock unlock;
                unlock.gameId = game ? game->id : status_.gameId;
                unlock.achievementId = achId;
                unlock.eventId = "ra:" + std::to_string(unlock.gameId) + ":" + std::to_string(achId);
                unlock.title = event->achievement->title ? event->achievement->title : "";
                unlock.description = event->achievement->description ? event->achievement->description : "";
                unlock.badgeUrl = buildBadgeUrl(event->achievement);
                unlock.gameTitle = (game && game->title) ? game->title : status_.gameTitle;
                unlock.consoleName = rc_console_name(status_.consoleId) ? rc_console_name(status_.consoleId) : "";
                unlock.hash = (game && game->hash) ? game->hash : status_.hash;
                unlock.points = event->achievement->points;
                unlock.hardcore = status_.hardcore;
                triggeredPending_[achId] = std::move(unlock);
            }
            maybeEmitConfirmed(achId);
            break;
        }
        case RC_CLIENT_EVENT_DISCONNECTED: {
            RetroAchievementsStatus snapshot;
            {
                std::lock_guard<std::recursive_mutex> lock(mutex_);
                status_.disconnected = true;
                status_.message = "Envio pendente ao RetroAchievements (sem conexão; tentando reconectar)...";
                snapshot = status_;
            }
            notifyStatus(snapshot);
            break;
        }
        case RC_CLIENT_EVENT_RECONNECTED: {
            RetroAchievementsStatus snapshot;
            {
                std::lock_guard<std::recursive_mutex> lock(mutex_);
                status_.disconnected = false;
                updateSummaryLocked();
                status_.message = "Reconectado · " + std::to_string(status_.unlockedCount) + "/" + std::to_string(status_.totalAchievements) + " conquistas";
                snapshot = status_;
            }
            notifyStatus(snapshot);
            break;
        }
        case RC_CLIENT_EVENT_SERVER_ERROR: {
            RetroAchievementsStatus snapshot;
            {
                std::lock_guard<std::recursive_mutex> lock(mutex_);
                if (event->server_error && event->server_error->api &&
                    std::strcmp(event->server_error->api, "awardachievement") == 0 &&
                    event->server_error->related_id != 0) {
                    triggeredPending_.erase(event->server_error->related_id);
                    awardedConfirmed_.erase(event->server_error->related_id);
                }
                const char *err = (event->server_error && event->server_error->error_message) ? event->server_error->error_message : "Erro do servidor";
                status_.message = std::string("Erro RetroAchievements: ") + err;
                snapshot = status_;
            }
            notifyStatus(snapshot);
            break;
        }
        default:
            break;
    }
}

void RetroAchievementsRuntime::handleAwardConfirmed(uint32_t achievementId) {
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        awardedConfirmed_.insert(achievementId);
    }
    maybeEmitConfirmed(achievementId);
}

void RetroAchievementsRuntime::maybeEmitConfirmed(uint32_t achievementId) {
    ConfirmedAchievementUnlock toEmit;
    RetroAchievementsStatus statusSnapshot;
    bool shouldEmit = false;
    {
        std::lock_guard<std::recursive_mutex> lock(mutex_);
        if (awardedConfirmed_.find(achievementId) == awardedConfirmed_.end()) {
            return;
        }
        auto it = triggeredPending_.find(achievementId);
        if (it == triggeredPending_.end()) {
            return;
        }
        toEmit = std::move(it->second);
        triggeredPending_.erase(it);
        awardedConfirmed_.erase(achievementId);
        shouldEmit = deduplicator_.markIfNew(toEmit.eventId, toEmit.gameId, std::to_string(toEmit.achievementId), toEmit.title);
        if (shouldEmit) {
            updateSummaryLocked();
            status_.disconnected = false;
            status_.message = "Conectado · " + std::to_string(status_.unlockedCount) + "/" + std::to_string(status_.totalAchievements) + " conquistas";
            statusSnapshot = status_;
        }
    }
    if (shouldEmit) {
        notifyStatus(statusSnapshot);
        if (callbacks_.onConfirmedUnlock) {
            callbacks_.onConfirmedUnlock(toEmit);
        }
    }
}

void RetroAchievementsRuntime::updateSummaryLocked() {
    if (!client_) return;
    rc_client_user_game_summary_t summary{};
    rc_client_get_user_game_summary(client_, &summary);
    status_.unlockedCount = summary.num_unlocked_achievements;
    status_.totalAchievements = summary.num_core_achievements;
    char rp[256] = {};
    rc_client_get_rich_presence_message(client_, rp, sizeof(rp));
    status_.richPresence = rp;
}

void RetroAchievementsRuntime::notifyStatus(const RetroAchievementsStatus &snapshot) {
    if (callbacks_.onStatusChanged) {
        callbacks_.onStatusChanged(snapshot);
    }
}

} // namespace brum

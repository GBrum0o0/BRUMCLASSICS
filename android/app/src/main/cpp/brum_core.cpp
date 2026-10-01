#include "brum_libretro_api.h"

#include <jni.h>
#include <dlfcn.h>
#include <algorithm>
#include <cstdio>
#include <cstring>
#include <deque>
#include <fstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

using retro_api_version_fn = unsigned (*)(void);
using retro_init_fn = void (*)(void);
using retro_deinit_fn = void (*)(void);
using retro_set_environment_fn = void (*)(brum_retro_environment_t);
using retro_set_video_refresh_fn = void (*)(brum_retro_video_refresh_t);
using retro_set_audio_sample_fn = void (*)(brum_retro_audio_sample_t);
using retro_set_audio_sample_batch_fn = void (*)(brum_retro_audio_sample_batch_t);
using retro_set_input_poll_fn = void (*)(brum_retro_input_poll_t);
using retro_set_input_state_fn = void (*)(brum_retro_input_state_t);
using retro_get_system_info_fn = void (*)(brum_retro_system_info *);
using retro_get_system_av_info_fn = void (*)(brum_retro_system_av_info *);
using retro_load_game_fn = bool (*)(const brum_retro_game_info *);
using retro_unload_game_fn = void (*)(void);
using retro_run_fn = void (*)(void);
using retro_set_controller_port_device_fn = void (*)(unsigned, unsigned);
using retro_get_memory_data_fn = void *(*)(unsigned);
using retro_get_memory_size_fn = size_t (*)(unsigned);

struct CoreFunctions {
    retro_api_version_fn apiVersion{}; retro_init_fn initialize{}; retro_deinit_fn deinitialize{};
    retro_set_environment_fn setEnvironment{}; retro_set_video_refresh_fn setVideo{};
    retro_set_audio_sample_fn setAudio{}; retro_set_audio_sample_batch_fn setAudioBatch{};
    retro_set_input_poll_fn setInputPoll{}; retro_set_input_state_fn setInputState{};
    retro_get_system_info_fn getSystemInfo{}; retro_get_system_av_info_fn getAVInfo{};
    retro_load_game_fn loadGame{}; retro_unload_game_fn unloadGame{}; retro_run_fn run{};
    retro_set_controller_port_device_fn setController{}; retro_get_memory_data_fn getMemoryData{};
    retro_get_memory_size_fn getMemorySize{};
};

class CoreSession;
static CoreSession *activeSession = nullptr;

class CoreSession {
public:
    CoreSession(const std::string &corePath, const std::string &romPath, const std::string &systemDirectory,
                const std::string &saveDirectory, const std::string &savePath)
        : systemDirectory(systemDirectory), saveDirectory(saveDirectory), romPath(romPath), savePath(savePath) {
        try {
            coreHandle = dlopen(corePath.c_str(), RTLD_NOW | RTLD_LOCAL);
            if (!coreHandle) throw std::runtime_error("O núcleo mGBA não pôde ser carregado.");
            loadSymbols();
            if (core.apiVersion() != BRUM_RETRO_API_VERSION) throw std::runtime_error("A versão Libretro do núcleo não é compatível.");
            activeSession = this;
            core.setEnvironment(environment);
            core.setVideo(video);
            core.setAudio(audioSample);
            core.setAudioBatch(audioBatch);
            core.setInputPoll(inputPoll);
            core.setInputState(inputState);
            core.initialize(); initialized = true;
            core.setController(0, BRUM_RETRO_DEVICE_JOYPAD);

            brum_retro_system_info info{}; core.getSystemInfo(&info);
            std::ifstream file(romPath, std::ios::binary);
            if (!file) throw std::runtime_error("A cópia protegida da ROM não pôde ser lida.");
            file.seekg(0, std::ios::end); auto length = file.tellg(); file.seekg(0, std::ios::beg);
            if (length <= 0) throw std::runtime_error("A ROM está vazia.");
            rom.resize(static_cast<size_t>(length)); file.read(reinterpret_cast<char *>(rom.data()), static_cast<std::streamsize>(length));
            if (!file) throw std::runtime_error("A ROM não pôde ser carregada por completo.");

            brum_retro_game_info game{}; game.path = this->romPath.c_str();
            if (!info.need_fullpath) { game.data = rom.data(); game.size = rom.size(); }
            if (!core.loadGame(&game)) throw std::runtime_error("O núcleo mGBA recusou este arquivo.");
            gameLoaded = true; restoreSave();
            brum_retro_system_av_info av{}; core.getAVInfo(&av); sampleRate = static_cast<int>(av.timing.sample_rate);
        } catch (...) {
            if (gameLoaded) core.unloadGame();
            if (initialized) core.deinitialize();
            if (activeSession == this) activeSession = nullptr;
            if (coreHandle) dlclose(coreHandle);
            coreHandle = nullptr; initialized = false; gameLoaded = false;
            throw;
        }
    }

    ~CoreSession() {
        persist();
        if (gameLoaded) core.unloadGame();
        if (initialized) core.deinitialize();
        if (activeSession == this) activeSession = nullptr;
        if (coreHandle) dlclose(coreHandle);
    }

    void runFrames(int count, uint32_t mask) {
        inputMask = mask;
        for (int index = 0; index < count; index++) { suppressVideo = index + 1 < count; core.run(); }
        suppressVideo = false;
    }

    void persist() {
        if (!gameLoaded) return;
        void *memory = core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM);
        size_t size = core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM);
        if (!memory || !size) return;
        std::string temporary = savePath + ".tmp";
        FILE *file = std::fopen(temporary.c_str(), "wb");
        if (!file) return;
        bool written = std::fwrite(memory, 1, size, file) == size;
        std::fflush(file); std::fclose(file);
        if (written) std::rename(temporary.c_str(), savePath.c_str()); else std::remove(temporary.c_str());
    }

    CoreFunctions core{};
    unsigned pixelFormat = BRUM_RETRO_PIXEL_FORMAT_0RGB1555;
    uint32_t inputMask = 0;
    bool suppressVideo = false;
    unsigned frameWidth = 0, frameHeight = 0;
    std::vector<uint32_t> frame;
    std::deque<int16_t> audio;
    std::unordered_map<std::string, std::string> variables;
    std::string systemDirectory, saveDirectory;
    int sampleRate = 48000;

private:
    void *coreHandle{}; bool initialized = false, gameLoaded = false;
    std::string romPath, savePath; std::vector<uint8_t> rom;

    template<typename T> T symbol(const char *name) {
        void *value = dlsym(coreHandle, name);
        if (!value) throw std::runtime_error(std::string("Núcleo inválido: falta ") + name + ".");
        return reinterpret_cast<T>(value);
    }

    void loadSymbols() {
        core.apiVersion = symbol<retro_api_version_fn>("retro_api_version");
        core.initialize = symbol<retro_init_fn>("retro_init"); core.deinitialize = symbol<retro_deinit_fn>("retro_deinit");
        core.setEnvironment = symbol<retro_set_environment_fn>("retro_set_environment"); core.setVideo = symbol<retro_set_video_refresh_fn>("retro_set_video_refresh");
        core.setAudio = symbol<retro_set_audio_sample_fn>("retro_set_audio_sample"); core.setAudioBatch = symbol<retro_set_audio_sample_batch_fn>("retro_set_audio_sample_batch");
        core.setInputPoll = symbol<retro_set_input_poll_fn>("retro_set_input_poll"); core.setInputState = symbol<retro_set_input_state_fn>("retro_set_input_state");
        core.getSystemInfo = symbol<retro_get_system_info_fn>("retro_get_system_info"); core.getAVInfo = symbol<retro_get_system_av_info_fn>("retro_get_system_av_info");
        core.loadGame = symbol<retro_load_game_fn>("retro_load_game"); core.unloadGame = symbol<retro_unload_game_fn>("retro_unload_game"); core.run = symbol<retro_run_fn>("retro_run");
        core.setController = symbol<retro_set_controller_port_device_fn>("retro_set_controller_port_device");
        core.getMemoryData = symbol<retro_get_memory_data_fn>("retro_get_memory_data"); core.getMemorySize = symbol<retro_get_memory_size_fn>("retro_get_memory_size");
    }

    void restoreSave() {
        void *memory = core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM); size_t size = core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM);
        if (!memory || !size) return;
        std::ifstream file(savePath, std::ios::binary | std::ios::ate);
        if (!file || static_cast<size_t>(file.tellg()) != size) return;
        file.seekg(0, std::ios::beg); file.read(reinterpret_cast<char *>(memory), static_cast<std::streamsize>(size));
    }

    static bool environment(unsigned command, void *data) {
        CoreSession *session = activeSession; if (!session) return false;
        switch (command) {
            case BRUM_RETRO_ENVIRONMENT_GET_CAN_DUPE: *static_cast<bool *>(data) = true; return true;
            case BRUM_RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
                unsigned format = *static_cast<unsigned *>(data); if (format > BRUM_RETRO_PIXEL_FORMAT_RGB565) return false;
                session->pixelFormat = format; return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: *static_cast<const char **>(data) = session->systemDirectory.c_str(); return true;
            case BRUM_RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            case BRUM_RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY: *static_cast<const char **>(data) = session->saveDirectory.c_str(); return true;
            case BRUM_RETRO_ENVIRONMENT_GET_LANGUAGE: *static_cast<unsigned *>(data) = 9; return true;
            case BRUM_RETRO_ENVIRONMENT_SET_VARIABLES: {
                auto *variable = static_cast<brum_retro_variable *>(data);
                while (variable && variable->key) {
                    std::string definition = variable->value ? variable->value : ""; size_t separator = definition.find("; ");
                    std::string choices = separator == std::string::npos ? definition : definition.substr(separator + 2);
                    size_t pipe = choices.find('|'); session->variables[variable->key] = choices.substr(0, pipe); variable++;
                }
                return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE: {
                auto *variable = static_cast<brum_retro_variable *>(data); if (!variable || !variable->key) return false;
                auto found = session->variables.find(variable->key); if (found == session->variables.end()) return false;
                variable->value = found->second.c_str(); return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *static_cast<bool *>(data) = false; return true;
            case BRUM_RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            case BRUM_RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
            case BRUM_RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME: return true;
            default: return false;
        }
    }

    static void video(const void *data, unsigned width, unsigned height, size_t pitch) {
        CoreSession *session = activeSession; if (!session || session->suppressVideo || !data || !width || !height) return;
        session->frameWidth = width; session->frameHeight = height; session->frame.resize(static_cast<size_t>(width) * height);
        for (unsigned y = 0; y < height; y++) {
            if (session->pixelFormat == BRUM_RETRO_PIXEL_FORMAT_XRGB8888) {
                auto *source = reinterpret_cast<const uint32_t *>(static_cast<const uint8_t *>(data) + y * pitch);
                for (unsigned x = 0; x < width; x++) session->frame[static_cast<size_t>(y) * width + x] = 0xFF000000u | (source[x] & 0x00FFFFFFu);
            } else {
                auto *source = reinterpret_cast<const uint16_t *>(static_cast<const uint8_t *>(data) + y * pitch);
                for (unsigned x = 0; x < width; x++) {
                    uint16_t value = source[x]; unsigned red, green, blue;
                    if (session->pixelFormat == BRUM_RETRO_PIXEL_FORMAT_RGB565) { red = ((value >> 11) & 31) * 255 / 31; green = ((value >> 5) & 63) * 255 / 63; blue = (value & 31) * 255 / 31; }
                    else { red = ((value >> 10) & 31) * 255 / 31; green = ((value >> 5) & 31) * 255 / 31; blue = (value & 31) * 255 / 31; }
                    session->frame[static_cast<size_t>(y) * width + x] = 0xFF000000u | (red << 16) | (green << 8) | blue;
                }
            }
        }
    }

    static void pushAudio(const int16_t *samples, size_t count) {
        CoreSession *session = activeSession; if (!session || !samples) return;
        constexpr size_t capacity = 262144;
        for (size_t index = 0; index < count; index++) { if (session->audio.size() >= capacity) session->audio.pop_front(); session->audio.push_back(samples[index]); }
    }
    static void audioSample(int16_t left, int16_t right) { int16_t pair[] = {left, right}; pushAudio(pair, 2); }
    static size_t audioBatch(const int16_t *data, size_t frames) { pushAudio(data, frames * 2); return frames; }
    static void inputPoll() {}
    static int16_t inputState(unsigned port, unsigned device, unsigned index, unsigned id) {
        CoreSession *session = activeSession; if (!session || port != 0 || device != BRUM_RETRO_DEVICE_JOYPAD || index != 0 || id > 15) return 0;
        return (session->inputMask & (1u << id)) ? 1 : 0;
    }
};

static std::string jstringValue(JNIEnv *env, jstring value) {
    if (!value) return {};
    const char *raw = env->GetStringUTFChars(value, nullptr); std::string result = raw ? raw : "";
    if (raw) env->ReleaseStringUTFChars(value, raw); return result;
}

static void throwJava(JNIEnv *env, const std::exception &error) {
    jclass type = env->FindClass("java/lang/IllegalStateException"); if (type) env->ThrowNew(type, error.what());
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeCreate(JNIEnv *env, jclass, jstring corePath, jstring romPath,
                                                                   jstring systemDirectory, jstring saveDirectory, jstring savePath) {
    try { return reinterpret_cast<jlong>(new CoreSession(jstringValue(env, corePath), jstringValue(env, romPath), jstringValue(env, systemDirectory), jstringValue(env, saveDirectory), jstringValue(env, savePath))); }
    catch (const std::exception &error) { throwJava(env, error); return 0; }
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeRunFrames(JNIEnv *, jclass, jlong handle, jint count, jint inputMask) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (session) session->runFrames(count, static_cast<uint32_t>(inputMask));
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeCopyFrame(JNIEnv *env, jclass, jlong handle, jintArray target) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (!session || !target || session->frame.empty()) return 0;
    jsize capacity = env->GetArrayLength(target); jsize count = static_cast<jsize>(std::min<size_t>(session->frame.size(), static_cast<size_t>(capacity)));
    env->SetIntArrayRegion(target, 0, count, reinterpret_cast<const jint *>(session->frame.data()));
    return (static_cast<jlong>(session->frameWidth) << 32) | session->frameHeight;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeDrainAudio(JNIEnv *env, jclass, jlong handle, jshortArray target) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (!session || !target || session->audio.empty()) return 0;
    jsize capacity = env->GetArrayLength(target); jsize count = static_cast<jsize>(std::min<size_t>(session->audio.size(), static_cast<size_t>(capacity)));
    std::vector<jshort> values(static_cast<size_t>(count));
    for (jsize index = 0; index < count; index++) { values[static_cast<size_t>(index)] = session->audio.front(); session->audio.pop_front(); }
    env->SetShortArrayRegion(target, 0, count, values.data()); return count;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeSampleRate(JNIEnv *, jclass, jlong handle) {
    auto *session = reinterpret_cast<CoreSession *>(handle); return session ? session->sampleRate : 48000;
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativePersist(JNIEnv *, jclass, jlong handle) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (session) session->persist();
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeDestroy(JNIEnv *, jclass, jlong handle) {
    delete reinterpret_cast<CoreSession *>(handle);
}

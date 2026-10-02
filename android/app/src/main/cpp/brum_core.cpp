#include "brum_libretro_api.h"

#include <jni.h>
#include <dlfcn.h>
#include <android/log.h>
#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <deque>
#include <fstream>
#include <mutex>
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
using retro_serialize_size_fn = size_t (*)(void);
using retro_serialize_fn = bool (*)(void *, size_t);
using retro_unserialize_fn = bool (*)(const void *, size_t);

struct CoreFunctions {
    retro_api_version_fn apiVersion{}; retro_init_fn initialize{}; retro_deinit_fn deinitialize{};
    retro_set_environment_fn setEnvironment{}; retro_set_video_refresh_fn setVideo{};
    retro_set_audio_sample_fn setAudio{}; retro_set_audio_sample_batch_fn setAudioBatch{};
    retro_set_input_poll_fn setInputPoll{}; retro_set_input_state_fn setInputState{};
    retro_get_system_info_fn getSystemInfo{}; retro_get_system_av_info_fn getAVInfo{};
    retro_load_game_fn loadGame{}; retro_unload_game_fn unloadGame{}; retro_run_fn run{};
    retro_set_controller_port_device_fn setController{}; retro_get_memory_data_fn getMemoryData{};
    retro_get_memory_size_fn getMemorySize{};
    retro_serialize_size_fn serializeSize{}; retro_serialize_fn serialize{};
    retro_unserialize_fn unserialize{};
};

class CoreSession;
static CoreSession *activeSession = nullptr;

class HardwareContext {
public:
    bool configure(brum_retro_hw_render_callback *requested) {
        if (!requested || (requested->context_type != BRUM_RETRO_HW_CONTEXT_OPENGLES3 &&
                           requested->context_type != BRUM_RETRO_HW_CONTEXT_OPENGLES_VERSION)) return false;
        if (requested->context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES_VERSION && requested->version_major > 3) return false;
        callback = *requested;
        callback.get_current_framebuffer = currentFramebuffer;
        callback.get_proc_address = getProcAddress;
        requested->get_current_framebuffer = currentFramebuffer;
        requested->get_proc_address = getProcAddress;
        pending = true;
        return true;
    }

    void initialize() {
        if (!pending || initialized) return;
        display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if (display == EGL_NO_DISPLAY || !eglInitialize(display, nullptr, nullptr)) fail("O contexto gráfico EGL não pôde ser iniciado.");
        if (!eglBindAPI(EGL_OPENGL_ES_API)) fail("O OpenGL ES não está disponível neste aparelho.");
        const EGLint attributes[] = {
            EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
            EGL_DEPTH_SIZE, callback.depth ? 24 : 0,
            EGL_STENCIL_SIZE, callback.stencil ? 8 : 0,
            EGL_NONE
        };
        EGLint count = 0;
        if (!eglChooseConfig(display, attributes, &config, 1, &count) || count != 1) fail("Este aparelho não oferece OpenGL ES 3 compatível com o núcleo.");
        const EGLint surfaceAttributes[] = { EGL_WIDTH, surfaceSize, EGL_HEIGHT, surfaceSize, EGL_NONE };
        surface = eglCreatePbufferSurface(display, config, surfaceAttributes);
        if (surface == EGL_NO_SURFACE) fail("Não foi possível criar a superfície gráfica do BRUM Core.");
        const EGLint contextAttributes[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
        context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttributes);
        if (context == EGL_NO_CONTEXT) fail("Não foi possível criar o contexto OpenGL ES 3.");
        initialized = true;
        makeCurrent();
        const char *version = reinterpret_cast<const char *>(glGetString(GL_VERSION));
        if (!version) fail("O driver gráfico não respondeu ao BRUM Core.");
    }

    void makeCurrent() {
        if (initialized && !eglMakeCurrent(display, surface, surface, context)) fail("O contexto gráfico do BRUM Core foi perdido.");
    }

    void releaseCurrent() {
        if (initialized) eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }

    void capture(unsigned width, unsigned height, std::vector<uint32_t> &target) {
        if (!initialized || !width || !height || width > surfaceSize || height > surfaceSize) return;
        const size_t pixelCount = static_cast<size_t>(width) * height;
        if (pixelCount > 16u * 1024u * 1024u) return;
        rgba.resize(pixelCount * 4);
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glReadPixels(0, 0, static_cast<GLsizei>(width), static_cast<GLsizei>(height), GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
        if (glGetError() != GL_NO_ERROR) return;
        target.resize(pixelCount);
        for (unsigned y = 0; y < height; y++) {
            const unsigned sourceY = height - 1 - y;
            for (unsigned x = 0; x < width; x++) {
                size_t source = (static_cast<size_t>(sourceY) * width + x) * 4;
                target[static_cast<size_t>(y) * width + x] = 0xFF000000u |
                    (static_cast<uint32_t>(rgba[source]) << 16) |
                    (static_cast<uint32_t>(rgba[source + 1]) << 8) |
                    static_cast<uint32_t>(rgba[source + 2]);
            }
        }
    }

    void resetCore() {
        if (!pending) return;
        initialize();
        if (callback.context_reset) callback.context_reset();
        releaseCurrent();
    }

    void shutdown() {
        if (!initialized) return;
        makeCurrent();
        if (callback.context_destroy) callback.context_destroy();
        releaseCurrent();
        eglDestroyContext(display, context);
        eglDestroySurface(display, surface);
        eglTerminate(display);
        display = EGL_NO_DISPLAY; context = EGL_NO_CONTEXT; surface = EGL_NO_SURFACE;
        initialized = false;
    }

    bool active() const { return initialized; }

private:
    static constexpr EGLint surfaceSize = 2048;
    EGLDisplay display = EGL_NO_DISPLAY;
    EGLContext context = EGL_NO_CONTEXT;
    EGLSurface surface = EGL_NO_SURFACE;
    EGLConfig config{};
    brum_retro_hw_render_callback callback{};
    bool pending = false;
    bool initialized = false;
    std::vector<uint8_t> rgba;

    [[noreturn]] static void fail(const char *message) { throw std::runtime_error(message); }
    static uintptr_t currentFramebuffer() { return 0; }
    static brum_retro_proc_address_t getProcAddress(const char *name) {
        void *symbol = name ? reinterpret_cast<void *>(eglGetProcAddress(name)) : nullptr;
        if (!symbol && name) symbol = dlsym(RTLD_DEFAULT, name);
        return reinterpret_cast<brum_retro_proc_address_t>(symbol);
    }
};

class CoreSession {
public:
    CoreSession(const std::string &corePath, const std::string &romPath, const std::string &systemDirectory,
                const std::string &saveDirectory, const std::string &savePath)
        : systemDirectory(systemDirectory), saveDirectory(saveDirectory), romPath(romPath), savePath(savePath) {
        try {
            variables["system_core_override"] = "Automatic";
            variables["system_gb_bios_enable"] = "ON";
            variables["system_gba_bios_enable"] = "ON";
            variables["system_nds_bios_enable"] = "ON";
            if (std::ifstream(systemDirectory + "/aes.zip").good()) variables["geolith_system_type"] = "aes";
            else if (std::ifstream(systemDirectory + "/neogeo.zip").good()) variables["geolith_system_type"] = "mvs";
            coreHandle = dlopen(corePath.c_str(), RTLD_NOW | RTLD_LOCAL);
            if (!coreHandle) throw std::runtime_error("O núcleo integrado não pôde ser carregado.");
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
            if (!info.need_fullpath) {
                rom.resize(static_cast<size_t>(length)); file.read(reinterpret_cast<char *>(rom.data()), static_cast<std::streamsize>(length));
                if (!file) throw std::runtime_error("A ROM não pôde ser carregada por completo.");
            }

            brum_retro_game_info game{}; game.path = this->romPath.c_str();
            if (!info.need_fullpath) { game.data = rom.data(); game.size = rom.size(); }
            if (!core.loadGame(&game)) throw std::runtime_error("O núcleo integrado recusou este arquivo.");
            gameLoaded = true; hardware.resetCore(); restoreSave();
            brum_retro_system_av_info av{}; core.getAVInfo(&av);
            const double reportedSampleRate = av.timing.sample_rate;
            sampleRate = std::isfinite(reportedSampleRate) && reportedSampleRate >= 8000.0 && reportedSampleRate <= 192000.0
                ? static_cast<int>(std::lround(reportedSampleRate)) : 48000;
        } catch (...) {
            if (hardware.active()) hardware.makeCurrent();
            if (gameLoaded) core.unloadGame();
            hardware.shutdown();
            if (initialized) core.deinitialize();
            if (activeSession == this) activeSession = nullptr;
            if (coreHandle) dlclose(coreHandle);
            coreHandle = nullptr; initialized = false; gameLoaded = false;
            throw;
        }
    }

    ~CoreSession() {
        if (hardware.active()) hardware.makeCurrent();
        persist();
        if (gameLoaded) core.unloadGame();
        hardware.shutdown();
        if (initialized) core.deinitialize();
        if (activeSession == this) activeSession = nullptr;
        if (coreHandle) dlclose(coreHandle);
    }

    void runFrames(int count, uint32_t mask) {
        if (shutdownRequested) throw std::runtime_error("O núcleo encerrou a emulação. Verifique se a ROM e as BIOS exigidas são válidas.");
        inputMask = mask;
        if (hardware.active()) hardware.makeCurrent();
        for (int index = 0; index < count; index++) { suppressVideo = index + 1 < count; core.run(); }
        suppressVideo = false;
        if (hardware.active()) hardware.releaseCurrent();
        if (shutdownRequested) throw std::runtime_error("O núcleo encerrou a emulação. Verifique se a ROM e as BIOS exigidas são válidas.");
    }

    void setPointer(int16_t x, int16_t y, bool pressed) {
        pointerX = x; pointerY = y; pointerPressed = pressed;
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

    bool saveState(const std::string &path) {
        if (!gameLoaded) return false;
        size_t size = core.serializeSize();
        if (!size || size > 64 * 1024 * 1024) return false;
        std::vector<uint8_t> state(size);
        if (!core.serialize(state.data(), size)) return false;
        std::string temporary = path + ".tmp";
        FILE *file = std::fopen(temporary.c_str(), "wb");
        if (!file) return false;
        bool written = std::fwrite(state.data(), 1, size, file) == size;
        std::fflush(file); std::fclose(file);
        if (!written) { std::remove(temporary.c_str()); return false; }
        if (std::rename(temporary.c_str(), path.c_str()) != 0) { std::remove(temporary.c_str()); return false; }
        return true;
    }

    bool loadState(const std::string &path) {
        if (!gameLoaded) return false;
        size_t expected = core.serializeSize();
        if (!expected || expected > 64 * 1024 * 1024) return false;
        std::ifstream file(path, std::ios::binary | std::ios::ate);
        if (!file || static_cast<size_t>(file.tellg()) != expected) return false;
        file.seekg(0, std::ios::beg); std::vector<uint8_t> state(expected);
        file.read(reinterpret_cast<char *>(state.data()), static_cast<std::streamsize>(expected));
        if (!file) return false;
        bool restored = core.unserialize(state.data(), expected);
        if (restored) clearAudio();
        return restored;
    }

    void clearAudio() {
        std::lock_guard<std::mutex> guard(audioMutex);
        audio.clear();
    }

    int drainAudio(jshort *target, int capacity) {
        if (!target || capacity <= 0) return 0;
        std::lock_guard<std::mutex> guard(audioMutex);
        const int count = static_cast<int>(std::min<size_t>(audio.size(), static_cast<size_t>(capacity)));
        for (int index = 0; index < count; index++) {
            target[index] = audio.front();
            audio.pop_front();
        }
        return count;
    }

    CoreFunctions core{};
    unsigned pixelFormat = BRUM_RETRO_PIXEL_FORMAT_0RGB1555;
    uint32_t inputMask = 0;
    bool suppressVideo = false;
    unsigned frameWidth = 0, frameHeight = 0;
    std::vector<uint32_t> frame;
    std::deque<int16_t> audio;
    std::mutex audioMutex;
    std::unordered_map<std::string, std::string> variables;
    std::string systemDirectory, saveDirectory;
    int sampleRate = 48000;
    int16_t pointerX = 0, pointerY = 0;
    bool pointerPressed = false;
    bool shutdownRequested = false;
    HardwareContext hardware;

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
        core.serializeSize = symbol<retro_serialize_size_fn>("retro_serialize_size");
        core.serialize = symbol<retro_serialize_fn>("retro_serialize"); core.unserialize = symbol<retro_unserialize_fn>("retro_unserialize");
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
                    size_t pipe = choices.find('|');
                    if (session->variables.find(variable->key) == session->variables.end()) session->variables[variable->key] = choices.substr(0, pipe);
                    variable++;
                }
                return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE: {
                auto *variable = static_cast<brum_retro_variable *>(data); if (!variable || !variable->key) return false;
                auto found = session->variables.find(variable->key); if (found == session->variables.end()) { variable->value = nullptr; return false; }
                variable->value = found->second.c_str(); return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *static_cast<bool *>(data) = false; return true;
            case BRUM_RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
                auto *callback = static_cast<brum_retro_log_callback *>(data); if (!callback) return false;
                callback->log = coreLog; return true;
            }
            case BRUM_RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: *static_cast<int *>(data) = 3; return true;
            case BRUM_RETRO_ENVIRONMENT_SHUTDOWN:
                session->shutdownRequested = true;
                return true;
            case BRUM_RETRO_ENVIRONMENT_SET_HW_RENDER:
                return session->hardware.configure(static_cast<brum_retro_hw_render_callback *>(data));
            case BRUM_RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT:
                return true;
            case BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL: return true;
            case BRUM_RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            case BRUM_RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
            case BRUM_RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME: return true;
            default: return false;
        }
    }

    static void video(const void *data, unsigned width, unsigned height, size_t pitch) {
        CoreSession *session = activeSession; if (!session || session->suppressVideo || !data || !width || !height) return;
        if (data == BRUM_RETRO_HW_FRAME_BUFFER_VALID) {
            session->frameWidth = width; session->frameHeight = height;
            session->hardware.capture(width, height, session->frame);
            return;
        }
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
        std::lock_guard<std::mutex> guard(session->audioMutex);
        for (size_t index = 0; index < count; index++) { if (session->audio.size() >= capacity) session->audio.pop_front(); session->audio.push_back(samples[index]); }
    }
    static void audioSample(int16_t left, int16_t right) { int16_t pair[] = {left, right}; pushAudio(pair, 2); }
    static size_t audioBatch(const int16_t *data, size_t frames) { pushAudio(data, frames * 2); return frames; }
    static void inputPoll() {}
    static int16_t inputState(unsigned port, unsigned device, unsigned index, unsigned id) {
        CoreSession *session = activeSession; if (!session || port != 0 || index != 0) return 0;
        if (device == BRUM_RETRO_DEVICE_JOYPAD && id <= 15) return (session->inputMask & (1u << id)) ? 1 : 0;
        if (device == BRUM_RETRO_DEVICE_POINTER) {
            if (id == BRUM_RETRO_DEVICE_ID_POINTER_X) return session->pointerX;
            if (id == BRUM_RETRO_DEVICE_ID_POINTER_Y) return session->pointerY;
            if (id == BRUM_RETRO_DEVICE_ID_POINTER_PRESSED) return session->pointerPressed ? 1 : 0;
        }
        return 0;
    }

    static void coreLog(int level, const char *format, ...) {
        int priority = level >= 3 ? ANDROID_LOG_ERROR : (level == 2 ? ANDROID_LOG_WARN : ANDROID_LOG_INFO);
        va_list arguments; va_start(arguments, format);
        __android_log_vprint(priority, "BRUMCore", format ? format : "", arguments);
        va_end(arguments);
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
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeRunFrames(JNIEnv *env, jclass, jlong handle, jint count, jint inputMask) {
    auto *session = reinterpret_cast<CoreSession *>(handle);
    if (!session) return;
    try { session->runFrames(count, static_cast<uint32_t>(inputMask)); }
    catch (const std::exception &error) { throwJava(env, error); }
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeSetPointer(JNIEnv *, jclass, jlong handle, jint x, jint y, jboolean pressed) {
    auto *session = reinterpret_cast<CoreSession *>(handle);
    if (session) session->setPointer(static_cast<int16_t>(std::clamp(x, -32767, 32767)), static_cast<int16_t>(std::clamp(y, -32767, 32767)), pressed == JNI_TRUE);
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
    auto *session = reinterpret_cast<CoreSession *>(handle); if (!session || !target) return 0;
    jsize capacity = env->GetArrayLength(target);
    std::vector<jshort> values(static_cast<size_t>(capacity));
    jsize count = static_cast<jsize>(session->drainAudio(values.data(), capacity));
    if (!count) return 0;
    env->SetShortArrayRegion(target, 0, count, values.data()); return count;
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeClearAudio(JNIEnv *, jclass, jlong handle) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (session) session->clearAudio();
}

extern "C" JNIEXPORT jint JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeSampleRate(JNIEnv *, jclass, jlong handle) {
    auto *session = reinterpret_cast<CoreSession *>(handle); return session ? session->sampleRate : 48000;
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativePersist(JNIEnv *, jclass, jlong handle) {
    auto *session = reinterpret_cast<CoreSession *>(handle); if (session) session->persist();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeSaveState(JNIEnv *env, jclass, jlong handle, jstring path) {
    auto *session = reinterpret_cast<CoreSession *>(handle);
    return session && session->saveState(jstringValue(env, path)) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeLoadState(JNIEnv *env, jclass, jlong handle, jstring path) {
    auto *session = reinterpret_cast<CoreSession *>(handle);
    return session && session->loadState(jstringValue(env, path)) ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_brumclassics_mobile_emulation_BrumCoreBridge_nativeDestroy(JNIEnv *, jclass, jlong handle) {
    delete reinterpret_cast<CoreSession *>(handle);
}

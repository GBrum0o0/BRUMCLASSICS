// A simulator-only libretro probe. No emulator/game code or copyrighted data.
#include "../../BRUMCLASSICSMobile/Libretro/BrumLibretroAPI.h"
#include <math.h>

static brum_retro_environment_t environment;
static brum_retro_video_refresh_t video;
static brum_retro_audio_sample_batch_t audio;
static unsigned char mode;

unsigned retro_api_version(void) { return BRUM_RETRO_API_VERSION; }
void retro_set_environment(brum_retro_environment_t callback) { environment = callback; }
void retro_set_video_refresh(brum_retro_video_refresh_t callback) { video = callback; }
void retro_set_audio_sample_batch(brum_retro_audio_sample_batch_t callback) { audio = callback; }
void retro_set_audio_sample(brum_retro_audio_sample_t callback) { (void)callback; }
void retro_set_input_poll(brum_retro_input_poll_t callback) { (void)callback; }
void retro_set_input_state(brum_retro_input_state_t callback) { (void)callback; }
void retro_init(void) {
    unsigned pixelFormat = BRUM_RETRO_PIXEL_FORMAT_XRGB8888;
    environment(BRUM_RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &pixelFormat);
}
void retro_deinit(void) {}
void retro_set_controller_port_device(unsigned port, unsigned device) { (void)port; (void)device; }
void retro_get_system_info(brum_retro_system_info *info) {
    *info = (brum_retro_system_info){"BRUM startup probe", "1", "brumtest", false, false};
}
void retro_get_system_av_info(brum_retro_system_av_info *info) {
    *info = (brum_retro_system_av_info){{2, 2, 2, 2, 1}, {60, mode == 'T' ? NAN : 48000}};
}
bool retro_load_game(const brum_retro_game_info *game) {
    if (!game || !game->data || !game->size) return false;
    mode = *(const unsigned char *)game->data;
    if (mode == 'R') {
        brum_retro_log_callback log = {0};
        if (environment(BRUM_RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log)) log.log(3, "probe: rejected content");
        return false;
    }
    return true;
}
void retro_unload_game(void) {}
void retro_run(void) {
    if (mode == 'S') {
        brum_retro_message_ext message = {"probe: required BIOS missing", 3000, 3, 3, 0, 0, -1};
        environment(BRUM_RETRO_ENVIRONMENT_SET_MESSAGE_EXT, &message);
        environment(BRUM_RETRO_ENVIRONMENT_SHUTDOWN, NULL);
        return;
    }
    const uint32_t pixels[4] = {0x123456, 0x654321, 0xabcdef, 0xfedcba};
    const int16_t samples[8] = {100, -100, 200, -200, 300, -300, 400, -400};
    video(pixels, 2, 2, 8);
    audio(samples, 4);
}
void *retro_get_memory_data(unsigned id) { (void)id; return NULL; }
size_t retro_get_memory_size(unsigned id) { (void)id; return 0; }
size_t retro_serialize_size(void) { return 0; }
bool retro_serialize(void *data, size_t size) { (void)data; (void)size; return false; }
bool retro_unserialize(const void *data, size_t size) { (void)data; (void)size; return false; }

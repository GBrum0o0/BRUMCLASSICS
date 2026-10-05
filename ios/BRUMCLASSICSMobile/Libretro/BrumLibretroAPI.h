#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Minimal ABI surface from libretro.h. The libretro API is MIT licensed.
// Keep these layouts and numeric constants aligned with the canonical header.

#define BRUM_RETRO_API_VERSION 1

#define BRUM_RETRO_DEVICE_JOYPAD 1
#define BRUM_RETRO_DEVICE_ANALOG 5
#define BRUM_RETRO_DEVICE_POINTER 6
#define BRUM_RETRO_MEMORY_SAVE_RAM 0

#define BRUM_RETRO_DEVICE_ID_POINTER_X 0
#define BRUM_RETRO_DEVICE_ID_POINTER_Y 1
#define BRUM_RETRO_DEVICE_ID_POINTER_PRESSED 2

#define BRUM_RETRO_ENVIRONMENT_GET_CAN_DUPE 3
#define BRUM_RETRO_ENVIRONMENT_SET_MESSAGE 6
#define BRUM_RETRO_ENVIRONMENT_SHUTDOWN 7
#define BRUM_RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL 8
#define BRUM_RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY 9
#define BRUM_RETRO_ENVIRONMENT_SET_PIXEL_FORMAT 10
#define BRUM_RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS 11
#define BRUM_RETRO_ENVIRONMENT_SET_HW_RENDER 14
#define BRUM_RETRO_ENVIRONMENT_GET_VARIABLE 15
#define BRUM_RETRO_ENVIRONMENT_SET_VARIABLES 16
#define BRUM_RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE 17
#define BRUM_RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME 18
#define BRUM_RETRO_ENVIRONMENT_GET_LOG_INTERFACE 27
#define BRUM_RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY 30
#define BRUM_RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY 31
#define BRUM_RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO 32
#define BRUM_RETRO_ENVIRONMENT_SET_GEOMETRY 37
#define BRUM_RETRO_ENVIRONMENT_GET_LANGUAGE 39
#define BRUM_RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT (44 | 0x10000)
#define BRUM_RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE (47 | 0x10000)
#define BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS 53
#define BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL 54
#define BRUM_RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER 56
#define BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2 67
#define BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL 68

#define BRUM_RETRO_PIXEL_FORMAT_0RGB1555 0
#define BRUM_RETRO_PIXEL_FORMAT_XRGB8888 1
#define BRUM_RETRO_PIXEL_FORMAT_RGB565 2

#define BRUM_RETRO_HW_FRAME_BUFFER_VALID ((void *)-1)
#define BRUM_RETRO_HW_CONTEXT_OPENGLES2 2
#define BRUM_RETRO_HW_CONTEXT_OPENGLES3 4
#define BRUM_RETRO_HW_CONTEXT_OPENGLES_VERSION 5

#define BRUM_RETRO_DEVICE_ID_JOYPAD_B 0
#define BRUM_RETRO_DEVICE_ID_JOYPAD_Y 1
#define BRUM_RETRO_DEVICE_ID_JOYPAD_SELECT 2
#define BRUM_RETRO_DEVICE_ID_JOYPAD_START 3
#define BRUM_RETRO_DEVICE_ID_JOYPAD_UP 4
#define BRUM_RETRO_DEVICE_ID_JOYPAD_DOWN 5
#define BRUM_RETRO_DEVICE_ID_JOYPAD_LEFT 6
#define BRUM_RETRO_DEVICE_ID_JOYPAD_RIGHT 7
#define BRUM_RETRO_DEVICE_ID_JOYPAD_A 8
#define BRUM_RETRO_DEVICE_ID_JOYPAD_X 9
#define BRUM_RETRO_DEVICE_ID_JOYPAD_L 10
#define BRUM_RETRO_DEVICE_ID_JOYPAD_R 11
#define BRUM_RETRO_DEVICE_ID_JOYPAD_L2 12
#define BRUM_RETRO_DEVICE_ID_JOYPAD_R2 13

typedef bool (*brum_retro_environment_t)(unsigned command, void *data);
typedef void (*brum_retro_video_refresh_t)(const void *data, unsigned width, unsigned height, size_t pitch);
typedef void (*brum_retro_audio_sample_t)(int16_t left, int16_t right);
typedef size_t (*brum_retro_audio_sample_batch_t)(const int16_t *data, size_t frames);
typedef void (*brum_retro_input_poll_t)(void);
typedef int16_t (*brum_retro_input_state_t)(unsigned port, unsigned device, unsigned index, unsigned id);

typedef struct {
    const char *library_name;
    const char *library_version;
    const char *valid_extensions;
    bool need_fullpath;
    bool block_extract;
} brum_retro_system_info;

typedef struct {
    unsigned base_width;
    unsigned base_height;
    unsigned max_width;
    unsigned max_height;
    float aspect_ratio;
} brum_retro_game_geometry;

typedef struct {
    double fps;
    double sample_rate;
} brum_retro_system_timing;

typedef struct {
    brum_retro_game_geometry geometry;
    brum_retro_system_timing timing;
} brum_retro_system_av_info;

typedef struct {
    const char *path;
    const void *data;
    size_t size;
    const char *meta;
} brum_retro_game_info;

typedef struct {
    const char *key;
    const char *value;
} brum_retro_variable;

typedef struct {
    const char *value;
    const char *label;
} brum_retro_core_option_value;

typedef struct {
    const char *key;
    const char *desc;
    const char *info;
    brum_retro_core_option_value values[128];
    const char *default_value;
} brum_retro_core_option_definition;

typedef struct {
    const brum_retro_core_option_definition *us;
    const brum_retro_core_option_definition *local;
} brum_retro_core_options_intl;

typedef struct {
    const char *key;
    const char *desc;
    const char *desc_categorized;
    const char *info;
    const char *info_categorized;
    const char *category_key;
    brum_retro_core_option_value values[128];
    const char *default_value;
} brum_retro_core_option_v2_definition;

typedef struct {
    const void *categories;
    const brum_retro_core_option_v2_definition *definitions;
} brum_retro_core_options_v2;

typedef struct {
    const brum_retro_core_options_v2 *us;
    const brum_retro_core_options_v2 *local;
} brum_retro_core_options_v2_intl;

typedef struct {
    const char *msg;
    unsigned frames;
} brum_retro_message;

typedef void (*brum_retro_log_printf_t)(int level, const char *format, ...);
typedef struct { brum_retro_log_printf_t log; } brum_retro_log_callback;

typedef void (*brum_retro_hw_context_reset_t)(void);
typedef uintptr_t (*brum_retro_hw_get_current_framebuffer_t)(void);
typedef void (*brum_retro_proc_address_t)(void);
typedef brum_retro_proc_address_t (*brum_retro_hw_get_proc_address_t)(const char *);
typedef struct {
    int context_type;
    brum_retro_hw_context_reset_t context_reset;
    brum_retro_hw_get_current_framebuffer_t get_current_framebuffer;
    brum_retro_hw_get_proc_address_t get_proc_address;
    bool depth;
    bool stencil;
    bool bottom_left_origin;
    unsigned version_major;
    unsigned version_minor;
    bool cache_context;
    brum_retro_hw_context_reset_t context_destroy;
    bool debug_context;
} brum_retro_hw_render_callback;

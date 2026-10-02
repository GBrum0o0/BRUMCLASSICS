#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define BRUM_RETRO_API_VERSION 1
#define BRUM_RETRO_DEVICE_JOYPAD 1
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
#define BRUM_RETRO_ENVIRONMENT_GET_LANGUAGE 39
#define BRUM_RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT (44 | 0x10000)
#define BRUM_RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE (47 | 0x10000)
#define BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL 68

#define BRUM_RETRO_PIXEL_FORMAT_0RGB1555 0
#define BRUM_RETRO_PIXEL_FORMAT_XRGB8888 1
#define BRUM_RETRO_PIXEL_FORMAT_RGB565 2

#define BRUM_RETRO_HW_FRAME_BUFFER_VALID ((void *)-1)
#define BRUM_RETRO_HW_CONTEXT_OPENGLES3 4
#define BRUM_RETRO_HW_CONTEXT_OPENGLES_VERSION 5

typedef bool (*brum_retro_environment_t)(unsigned, void *);
typedef void (*brum_retro_video_refresh_t)(const void *, unsigned, unsigned, size_t);
typedef void (*brum_retro_audio_sample_t)(int16_t, int16_t);
typedef size_t (*brum_retro_audio_sample_batch_t)(const int16_t *, size_t);
typedef void (*brum_retro_input_poll_t)(void);
typedef int16_t (*brum_retro_input_state_t)(unsigned, unsigned, unsigned, unsigned);

typedef struct { const char *library_name; const char *library_version; const char *valid_extensions; bool need_fullpath; bool block_extract; } brum_retro_system_info;
typedef struct { unsigned base_width; unsigned base_height; unsigned max_width; unsigned max_height; float aspect_ratio; } brum_retro_game_geometry;
typedef struct { double fps; double sample_rate; } brum_retro_system_timing;
typedef struct { brum_retro_game_geometry geometry; brum_retro_system_timing timing; } brum_retro_system_av_info;
typedef struct { const char *path; const void *data; size_t size; const char *meta; } brum_retro_game_info;
typedef struct { const char *key; const char *value; } brum_retro_variable;
typedef void (*brum_retro_log_printf_t)(int, const char *, ...);
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

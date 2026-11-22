#ifndef BRUM_LIBRETRO_SHIM_H
#define BRUM_LIBRETRO_SHIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef RETRO_MEMORY_SAVE_RAM
#define RETRO_MEMORY_SAVE_RAM 0
#endif
#ifndef RETRO_MEMORY_RTC
#define RETRO_MEMORY_RTC 1
#endif
#ifndef RETRO_MEMORY_SYSTEM_RAM
#define RETRO_MEMORY_SYSTEM_RAM 2
#endif
#ifndef RETRO_MEMORY_VIDEO_RAM
#define RETRO_MEMORY_VIDEO_RAM 3
#endif

#ifndef RETRO_MEMDESC_CONST
#define RETRO_MEMDESC_CONST (1 << 0)
#endif
#ifndef RETRO_MEMDESC_BIGENDIAN
#define RETRO_MEMDESC_BIGENDIAN (1 << 1)
#endif
#ifndef RETRO_MEMDESC_SYSTEM_RAM
#define RETRO_MEMDESC_SYSTEM_RAM (1 << 2)
#endif
#ifndef RETRO_MEMDESC_SAVE_RAM
#define RETRO_MEMDESC_SAVE_RAM (1 << 3)
#endif
#ifndef RETRO_MEMDESC_VIDEO_RAM
#define RETRO_MEMDESC_VIDEO_RAM (1 << 4)
#endif
#ifndef RETRO_MEMDESC_ALIGN_2
#define RETRO_MEMDESC_ALIGN_2 (1 << 16)
#endif
#ifndef RETRO_MEMDESC_ALIGN_4
#define RETRO_MEMDESC_ALIGN_4 (2 << 16)
#endif
#ifndef RETRO_MEMDESC_ALIGN_8
#define RETRO_MEMDESC_ALIGN_8 (3 << 16)
#endif
#ifndef RETRO_MEMDESC_MINSIZE_2
#define RETRO_MEMDESC_MINSIZE_2 (1 << 24)
#endif
#ifndef RETRO_MEMDESC_MINSIZE_4
#define RETRO_MEMDESC_MINSIZE_4 (2 << 24)
#endif
#ifndef RETRO_MEMDESC_MINSIZE_8
#define RETRO_MEMDESC_MINSIZE_8 (3 << 24)
#endif

#ifndef RETRO_MEMORY_MAP_DEFINED
#define RETRO_MEMORY_MAP_DEFINED
struct retro_memory_descriptor {
    uint64_t flags;
    void *ptr;
    size_t offset;
    size_t start;
    size_t select;
    size_t disconnect;
    size_t len;
    const char *addrspace;
};

struct retro_memory_map {
    const struct retro_memory_descriptor *descriptors;
    unsigned num_descriptors;
};
#endif

#ifdef __cplusplus
}
#endif

#endif

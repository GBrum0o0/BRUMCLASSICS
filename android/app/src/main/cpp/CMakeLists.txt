cmake_minimum_required(VERSION 3.22.1)
project(brumcore LANGUAGES C CXX)

add_library(brumcore SHARED brum_core.cpp)
target_compile_features(brumcore PRIVATE cxx_std_17)
target_compile_options(brumcore PRIVATE -Wall -Wextra -Werror=return-type)
target_link_libraries(brumcore PRIVATE android log dl EGL GLESv3)

set(MGBA_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/mgba")
if(EXISTS "${MGBA_SOURCE_DIR}/CMakeLists.txt")
    set(BUILD_LIBRETRO ON CACHE BOOL "" FORCE)
    set(LIBRETRO_STATIC OFF CACHE BOOL "" FORCE)
    set(DISABLE_FRONTENDS ON CACHE BOOL "" FORCE)
    set(DISABLE_DEPS ON CACHE BOOL "" FORCE)
    set(SKIP_LIBRARY ON CACHE BOOL "" FORCE)
    set(BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(BUILD_STATIC OFF CACHE BOOL "" FORCE)
    set(BUILD_TEST OFF CACHE BOOL "" FORCE)
    set(BUILD_SUITE OFF CACHE BOOL "" FORCE)
    set(BUILD_GL OFF CACHE BOOL "" FORCE)
    set(BUILD_GLES2 OFF CACHE BOOL "" FORCE)
    set(BUILD_GLES3 OFF CACHE BOOL "" FORCE)
    add_subdirectory("${MGBA_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/mgba")
    set_target_properties(mgba_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore mgba_libretro)
else()
    message(FATAL_ERROR "mGBA pinned source is missing. Run android/fetch-mgba-core.ps1 or clone it in CI.")
endif()

set(BSNES_MERCURY_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/bsnes-mercury")
if(EXISTS "${BSNES_MERCURY_SOURCE_DIR}/target-libretro/libretro.cpp")
    set(BSNES_MERCURY_SFC_DIR "${BSNES_MERCURY_SOURCE_DIR}/sfc")
    add_library(bsnes_mercury_performance_libretro SHARED
        "${BSNES_MERCURY_SOURCE_DIR}/libco/libco.c"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/arm/arm.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/gsu/gsu.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/hg51b/hg51b.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/lr35902/lr35902.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/r65816/r65816.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/spc700/spc700.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/processor/upd96050/upd96050.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/interface/interface.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/system/system.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/scheduler/scheduler.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/memory/memory.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/cartridge/cartridge.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/cpu/cpu.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/ppu/ppu.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/apu/apu.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/cheat/cheat.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/gb/video/video.cpp"
        "${BSNES_MERCURY_SFC_DIR}/interface/interface.cpp"
        "${BSNES_MERCURY_SFC_DIR}/base/satellaview/satellaview.cpp"
        "${BSNES_MERCURY_SFC_DIR}/system/system.cpp"
        "${BSNES_MERCURY_SFC_DIR}/controller/controller.cpp"
        "${BSNES_MERCURY_SFC_DIR}/cartridge/cartridge.cpp"
        "${BSNES_MERCURY_SFC_DIR}/cheat/cheat.cpp"
        "${BSNES_MERCURY_SFC_DIR}/memory/memory.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/icd2/icd2.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/bsx/bsx.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/nss/nss.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/event/event.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/sa1/sa1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/superfx/superfx.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/armdsp/armdsp.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/hitachidsp/hitachidsp.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/necdsp/necdsp.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/epsonrtc/epsonrtc.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/sharprtc/sharprtc.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/spc7110/spc7110.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/sdd1/sdd1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/obc1/obc1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/hsu1/hsu1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/msu1/msu1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/slot/satellaview/satellaview.cpp"
        "${BSNES_MERCURY_SFC_DIR}/slot/sufamiturbo/sufamiturbo.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/dsp1/dsp1.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/dsp2/dsp2.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/dsp3/dsp3.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/dsp4/dsp4.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/cx4/cx4.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/st0010/st0010.cpp"
        "${BSNES_MERCURY_SFC_DIR}/chip/sgb-external/sgb-external.cpp"
        "${BSNES_MERCURY_SFC_DIR}/alt/cpu/cpu.cpp"
        "${BSNES_MERCURY_SFC_DIR}/alt/smp/smp.cpp"
        "${BSNES_MERCURY_SFC_DIR}/alt/dsp/dsp.cpp"
        "${BSNES_MERCURY_SFC_DIR}/alt/ppu-performance/ppu.cpp"
        "${BSNES_MERCURY_SOURCE_DIR}/target-libretro/libretro.cpp")
    target_include_directories(bsnes_mercury_performance_libretro PRIVATE
        "${BSNES_MERCURY_SOURCE_DIR}"
        "${BSNES_MERCURY_SOURCE_DIR}/libco"
        "${BSNES_MERCURY_SFC_DIR}")
    target_compile_definitions(bsnes_mercury_performance_libretro PRIVATE
        PROFILE_PERFORMANCE STDC_HEADERS __STDC_LIMIT_MACROS __LIBRETRO__ SFC_LAGFIX
        HAVE_POSIX_MEMALIGN GIT_VERSION="79d7f9de218b6ffa65a80bbdc5828532bc239232")
    target_compile_options(bsnes_mercury_performance_libretro PRIVATE
        $<$<COMPILE_LANGUAGE:CXX>:-std=c++11>
        -Wno-sign-compare -Wno-unused-variable -Wno-unused-function -Wno-uninitialized -Wno-strict-aliasing)
    target_link_libraries(bsnes_mercury_performance_libretro PRIVATE dl m)
    set_target_properties(bsnes_mercury_performance_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore bsnes_mercury_performance_libretro)
else()
    message(FATAL_ERROR "bsnes-mercury pinned source is missing. Run android/fetch-bsnes-mercury-core.ps1 or clone it in CI.")
endif()

set(BEETLE_PCE_FAST_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/beetle-pce-fast")
if(EXISTS "${BEETLE_PCE_FAST_SOURCE_DIR}/libretro.c")
    set(BEETLE_PCE_FAST_MEDNAFEN_DIR "${BEETLE_PCE_FAST_SOURCE_DIR}/mednafen")
    set(BEETLE_PCE_FAST_DEPS_DIR "${BEETLE_PCE_FAST_SOURCE_DIR}/deps")
    set(BEETLE_PCE_FAST_COMMON_DIR "${BEETLE_PCE_FAST_SOURCE_DIR}/libretro-common")
    file(GLOB BEETLE_PCE_FAST_TREMOR_SOURCES CONFIGURE_DEPENDS
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/tremor/*.c")
    list(FILTER BEETLE_PCE_FAST_TREMOR_SOURCES EXCLUDE REGEX "ivorbisfile_example\\.c$")
    add_library(mednafen_pce_fast_libretro SHARED
        "${BEETLE_PCE_FAST_SOURCE_DIR}/libretro.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/general.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdstream.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/mempatcher.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/okiadpcm.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/file.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/settings.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/state.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/mednafen-endian.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/sound/Blip_Buffer.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/hw_misc/arcade_card/arcade_card.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/pcecd_drive.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/pcecd.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/psg.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/huc6280.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/input.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/pce_fast/vdc.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/CDAccess.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/CDAccess_Image.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/CDAccess_CCD.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/CDAccess_CHD.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/audioreader.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/cdromif.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/CDUtility.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/lec.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/galois.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/l-ec.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/edc_crc32.c"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/cdrom/recover-raw.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/streams/file_stream.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/streams/file_stream_transforms.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/file/file_path.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/file/retro_dirent.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/lists/string_list.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/lists/dir_list.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/compat/compat_strl.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/compat/compat_snprintf.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/compat/compat_posix_string.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/compat/compat_strcasestr.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/compat/fopen_utf8.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/encodings/encoding_utf.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/encodings/encoding_crc32.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/memmap/memalign.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/string/stdstring.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/time/rtime.c"
        "${BEETLE_PCE_FAST_COMMON_DIR}/vfs/vfs_implementation.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/Alloc.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/Bra86.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/BraIA64.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/CpuArch.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/Delta.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/LzFind.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/Lzma86Dec.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/LzmaDec.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/src/LzmaEnc.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/src/libchdr_bitstream.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/src/libchdr_cdrom.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/src/libchdr_chd.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/src/libchdr_flac.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/src/libchdr_huffman.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/common/entropy_common.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/common/error_private.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/common/fse_decompress.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/common/zstd_common.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/common/xxhash.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/decompress/huf_decompress.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/decompress/zstd_ddict.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/decompress/zstd_decompress.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib/decompress/zstd_decompress_block.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/adler32.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/crc32.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/inffast.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/inflate.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/inftrees.c"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11/zutil.c"
        ${BEETLE_PCE_FAST_TREMOR_SOURCES})
    target_include_directories(mednafen_pce_fast_libretro PRIVATE
        "${BEETLE_PCE_FAST_SOURCE_DIR}"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/include"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/hw_sound"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/hw_cpu"
        "${BEETLE_PCE_FAST_MEDNAFEN_DIR}/hw_misc"
        "${BEETLE_PCE_FAST_COMMON_DIR}/include"
        "${BEETLE_PCE_FAST_DEPS_DIR}/lzma-19.00/include"
        "${BEETLE_PCE_FAST_DEPS_DIR}/libchdr/include"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zstd/lib"
        "${BEETLE_PCE_FAST_DEPS_DIR}/zlib-1.2.11")
    target_compile_definitions(mednafen_pce_fast_libretro PRIVATE
        WANT_PCE_FAST_EMU FRONTEND_SUPPORTS_RGB565 USE_CHEATS NEED_TREMOR NEED_CD HAVE_CHD
        _7ZIP_ST ZSTD_DISABLE_ASM STDC_HEADERS __STDC_LIMIT_MACROS __LIBRETRO__ _LOW_ACCURACY_
        HAVE_UNISTD_H MEDNAFEN_VERSION_NUMERIC=931 INLINE=inline
        GIT_VERSION="3f946f277aef3aa99a95551618bbcd1dd2bda0d9")
    target_compile_options(mednafen_pce_fast_libretro PRIVATE -Wno-unused-function -Wno-unused-variable)
    target_link_libraries(mednafen_pce_fast_libretro PRIVATE m)
    set_target_properties(mednafen_pce_fast_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore mednafen_pce_fast_libretro)
else()
    message(FATAL_ERROR "Beetle PCE Fast pinned source is missing. Run android/fetch-beetle-pce-fast-core.ps1 or clone it in CI.")
endif()

set(NESTOPIA_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/nestopia")
if(EXISTS "${NESTOPIA_SOURCE_DIR}/libretro/libretro.cpp")
    set(NESTOPIA_COMMON_DIR "${NESTOPIA_SOURCE_DIR}/libretro/libretro-common")
    file(GLOB_RECURSE NESTOPIA_CORE_SOURCES CONFIGURE_DEPENDS
        "${NESTOPIA_SOURCE_DIR}/source/core/*.cpp")
    add_library(nestopia_libretro SHARED
        "${NESTOPIA_SOURCE_DIR}/libretro/libretro.cpp"
        "${NESTOPIA_COMMON_DIR}/compat/compat_posix_string.c"
        "${NESTOPIA_COMMON_DIR}/compat/compat_strcasestr.c"
        "${NESTOPIA_COMMON_DIR}/compat/compat_snprintf.c"
        "${NESTOPIA_COMMON_DIR}/compat/compat_strl.c"
        "${NESTOPIA_COMMON_DIR}/compat/fopen_utf8.c"
        "${NESTOPIA_COMMON_DIR}/encodings/encoding_utf.c"
        "${NESTOPIA_COMMON_DIR}/file/file_path.c"
        "${NESTOPIA_COMMON_DIR}/file/file_path_io.c"
        "${NESTOPIA_COMMON_DIR}/streams/file_stream.c"
        "${NESTOPIA_COMMON_DIR}/time/rtime.c"
        "${NESTOPIA_COMMON_DIR}/vfs/vfs_implementation.c"
        ${NESTOPIA_CORE_SOURCES})
    target_include_directories(nestopia_libretro PRIVATE
        "${NESTOPIA_SOURCE_DIR}"
        "${NESTOPIA_SOURCE_DIR}/source"
        "${NESTOPIA_SOURCE_DIR}/libretro"
        "${NESTOPIA_COMMON_DIR}/include")
    target_compile_definitions(nestopia_libretro PRIVATE __LIBRETRO__ NST_NO_ZLIB)
    target_compile_options(nestopia_libretro PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-std=c++98> -fno-rtti)
    target_link_libraries(nestopia_libretro PRIVATE m)
    set_target_properties(nestopia_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore nestopia_libretro)
else()
    message(FATAL_ERROR "Nestopia pinned source is missing. Run android/fetch-nestopia-core.ps1 or clone it in CI.")
endif()

set(GEARSYSTEM_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/gearsystem")
if(EXISTS "${GEARSYSTEM_SOURCE_DIR}/platforms/libretro/libretro.cpp")
    set(GEARSYSTEM_LIBRETRO_DIR "${GEARSYSTEM_SOURCE_DIR}/platforms/libretro")
    set(GEARSYSTEM_CORE_DIR "${GEARSYSTEM_SOURCE_DIR}/src")
    set(GEARSYSTEM_DEPS_DIR "${GEARSYSTEM_SOURCE_DIR}/platforms/shared/dependencies")
    file(GLOB GEARSYSTEM_CORE_SOURCES CONFIGURE_DEPENDS
        "${GEARSYSTEM_CORE_DIR}/*.cpp"
        "${GEARSYSTEM_CORE_DIR}/audio/*.cpp")
    add_library(gearsystem_libretro SHARED
        "${GEARSYSTEM_LIBRETRO_DIR}/libretro.cpp"
        "${GEARSYSTEM_LIBRETRO_DIR}/libretro_link.cpp"
        "${GEARSYSTEM_CORE_DIR}/audio/emu2413/emu2413.c"
        "${GEARSYSTEM_DEPS_DIR}/miniz/miniz.c"
        ${GEARSYSTEM_CORE_SOURCES})
    target_include_directories(gearsystem_libretro PRIVATE
        "${GEARSYSTEM_LIBRETRO_DIR}"
        "${GEARSYSTEM_CORE_DIR}"
        "${GEARSYSTEM_DEPS_DIR}/miniz")
    target_compile_definitions(gearsystem_libretro PRIVATE
        __LIBRETRO__
        GS_DISABLE_DISASSEMBLER
        GS_DISABLE_VGMRECORDER
        EMULATOR_BUILD="2d9106f2063d1a6e0661cc8938bb7f8eb737bcae")
    target_compile_options(gearsystem_libretro PRIVATE -fno-exceptions)
    target_link_libraries(gearsystem_libretro PRIVATE m)
    set_target_properties(gearsystem_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore gearsystem_libretro)
else()
    message(FATAL_ERROR "Gearsystem pinned source is missing. Run android/fetch-gearsystem-core.ps1 or clone it in CI.")
endif()

set(SKYEMU_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/skyemu")
if(EXISTS "${SKYEMU_SOURCE_DIR}/src/libretro.c")
    add_library(skyemu_libretro SHARED
        "${SKYEMU_SOURCE_DIR}/src/libretro.c"
        "${SKYEMU_SOURCE_DIR}/src/shared.c"
        "${SKYEMU_SOURCE_DIR}/src/localization.c")
    target_include_directories(skyemu_libretro PRIVATE "${SKYEMU_SOURCE_DIR}/src")
    target_compile_definitions(skyemu_libretro PRIVATE
        GIT_COMMIT_HASH="36771a16bfde7eb5c1c0315877b5e465e6f38858")
    target_link_libraries(skyemu_libretro PRIVATE atomic m)
    set_target_properties(skyemu_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore skyemu_libretro)
else()
    message(FATAL_ERROR "SkyEmu pinned source is missing. Run android/fetch-skyemu-core.ps1 or clone it in CI.")
endif()

set(GEOLITH_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/geolith")
if(EXISTS "${GEOLITH_SOURCE_DIR}/libretro/libretro.c")
    add_library(geolith_libretro SHARED
        "${GEOLITH_SOURCE_DIR}/libretro/libretro.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/compat/compat_posix_string.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/compat/compat_strl.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/compat/fopen_utf8.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/encodings/encoding_utf.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/file/file_path.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/file/file_path_io.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/streams/file_stream.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/streams/file_stream_transforms.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/string/stdstring.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/time/rtime.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/vfs/vfs_implementation.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_bitstream.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_cdrom.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_chd.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_flac.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_flac_codec.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_huffman.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_lzma.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_zlib.c"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/formats/libchdr/libchdr_zstd.c"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/src/Alloc.c"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/src/CpuArch.c"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/src/LzFind.c"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/src/LzmaDec.c"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/src/LzmaEnc.c"
        "${GEOLITH_SOURCE_DIR}/deps/miniz/miniz.c"
        "${GEOLITH_SOURCE_DIR}/deps/speex/resample.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/common/entropy_common.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/common/error_private.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/common/fse_decompress.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/common/zstd_common.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/common/xxhash.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/decompress/huf_decompress.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/decompress/zstd_ddict.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/decompress/zstd_decompress.c"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib/decompress/zstd_decompress_block.c"
        "${GEOLITH_SOURCE_DIR}/src/geo.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_cd.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_chd.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_cue.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_disc.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_lc8951.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_lspc.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_m68k.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_memcard.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_mixer.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_neo.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_rtc.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_serial.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_vfs.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_ymfm.c"
        "${GEOLITH_SOURCE_DIR}/src/geo_z80.c"
        "${GEOLITH_SOURCE_DIR}/src/m68k/m68kcpu.c"
        "${GEOLITH_SOURCE_DIR}/src/m68k/m68kops.c"
        "${GEOLITH_SOURCE_DIR}/src/ymfm/ymfm_adpcm.c"
        "${GEOLITH_SOURCE_DIR}/src/ymfm/ymfm_opn.c"
        "${GEOLITH_SOURCE_DIR}/src/ymfm/ymfm_ssg.c"
        "${GEOLITH_SOURCE_DIR}/src/z80/z80.c")
    target_include_directories(geolith_libretro PRIVATE
        "${GEOLITH_SOURCE_DIR}/deps"
        "${GEOLITH_SOURCE_DIR}/deps/libretro-common/include"
        "${GEOLITH_SOURCE_DIR}/deps/miniz"
        "${GEOLITH_SOURCE_DIR}/deps/lzma/include"
        "${GEOLITH_SOURCE_DIR}/deps/zstd/lib"
        "${GEOLITH_SOURCE_DIR}/src"
        "${GEOLITH_SOURCE_DIR}/libretro")
    target_compile_definitions(geolith_libretro PRIVATE
        HAVE_ZLIB HAVE_7ZIP HAVE_DR_FLAC HAVE_FLAC HAVE_ZSTD ZSTD_DISABLE_ASM HAVE_CHDR
        __LIBRETRO__ Z7_ST GIT_VERSION="1940249")
    target_compile_options(geolith_libretro PRIVATE -fsigned-char -fno-strict-overflow)
    target_link_libraries(geolith_libretro PRIVATE z m)
    set_target_properties(geolith_libretro PROPERTIES PREFIX "lib")
    add_dependencies(brumcore geolith_libretro)
else()
    message(FATAL_ERROR "Geolith pinned source is missing. Run android/fetch-geolith-core.ps1 or clone it in CI.")
endif()

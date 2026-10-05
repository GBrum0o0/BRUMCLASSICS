#import "BrumLibretroEngine.h"
#import "BrumLibretroAPI.h"
#include "BrumScreenProfiles.hpp"
#include "../../../shared/brum-core/InputState.hpp"
#include "../../../shared/brum-core/N64Input.hpp"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <GameController/GameController.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <math.h>
#import <os/lock.h>
#import <stdlib.h>
#import <stdarg.h>
#import <string.h>

static NSString *const BrumLibretroErrorDomain = @"com.brumclassics.mobile.ios.libretro";
static const void *BrumHardwareFrameBuffer = (const void *)(intptr_t)-1;

static NSString *BrumSHA256(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

typedef unsigned (*retro_api_version_fn)(void);
typedef void (*retro_init_fn)(void);
typedef void (*retro_deinit_fn)(void);
typedef void (*retro_set_environment_fn)(brum_retro_environment_t);
typedef void (*retro_set_video_refresh_fn)(brum_retro_video_refresh_t);
typedef void (*retro_set_audio_sample_fn)(brum_retro_audio_sample_t);
typedef void (*retro_set_audio_sample_batch_fn)(brum_retro_audio_sample_batch_t);
typedef void (*retro_set_input_poll_fn)(brum_retro_input_poll_t);
typedef void (*retro_set_input_state_fn)(brum_retro_input_state_t);
typedef void (*retro_get_system_info_fn)(brum_retro_system_info *);
typedef void (*retro_get_system_av_info_fn)(brum_retro_system_av_info *);
typedef bool (*retro_load_game_fn)(const brum_retro_game_info *);
typedef void (*retro_unload_game_fn)(void);
typedef void (*retro_run_fn)(void);
typedef void (*retro_set_controller_port_device_fn)(unsigned, unsigned);
typedef void *(*retro_get_memory_data_fn)(unsigned);
typedef size_t (*retro_get_memory_size_fn)(unsigned);
typedef size_t (*retro_serialize_size_fn)(void);
typedef bool (*retro_serialize_fn)(void *, size_t);
typedef bool (*retro_unserialize_fn)(const void *, size_t);

typedef struct {
    retro_api_version_fn apiVersion;
    retro_init_fn initialize;
    retro_deinit_fn deinitialize;
    retro_set_environment_fn setEnvironment;
    retro_set_video_refresh_fn setVideo;
    retro_set_audio_sample_fn setAudio;
    retro_set_audio_sample_batch_fn setAudioBatch;
    retro_set_input_poll_fn setInputPoll;
    retro_set_input_state_fn setInputState;
    retro_get_system_info_fn getSystemInfo;
    retro_get_system_av_info_fn getAVInfo;
    retro_load_game_fn loadGame;
    retro_unload_game_fn unloadGame;
    retro_run_fn run;
    retro_set_controller_port_device_fn setController;
    retro_get_memory_data_fn getMemoryData;
    retro_get_memory_size_fn getMemorySize;
    retro_serialize_size_fn serializeSize;
    retro_serialize_fn serialize;
    retro_unserialize_fn unserialize;
} BrumRetroFunctions;

@interface BrumVirtualStick : UIControl
@property(nonatomic, readonly) double horizontal;
@property(nonatomic, readonly) double vertical;
- (void)reset;
@end

@implementation BrumVirtualStick {
    UIView *_thumb;
    double _horizontal;
    double _vertical;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.84];
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    self.layer.borderWidth = 2;
    _thumb = [[UIView alloc] init];
    _thumb.backgroundColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:0.92];
    _thumb.userInteractionEnabled = NO;
    [self addSubview:_thumb];
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Controle analógico";
    self.accessibilityHint = @"Arraste para mover o personagem. Toque em D-PAD para usar as setas.";
    return self;
}

- (double)horizontal { return _horizontal; }
- (double)vertical { return _vertical; }

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2;
    const CGFloat diameter = 48;
    const CGFloat radius = MAX(1, MIN(self.bounds.size.width, self.bounds.size.height) / 2 - diameter / 2 - 5);
    _thumb.frame = CGRectMake(0, 0, diameter, diameter);
    _thumb.layer.cornerRadius = diameter / 2;
    _thumb.center = CGPointMake(CGRectGetMidX(self.bounds) + _horizontal * radius,
                                CGRectGetMidY(self.bounds) + _vertical * radius);
}

- (void)updateWithTouch:(UITouch *)touch {
    const CGPoint point = [touch locationInView:self];
    const double radius = MAX(1, MIN(self.bounds.size.width, self.bounds.size.height) / 2 - 29);
    const auto position = brum::virtualStick(point.x - CGRectGetMidX(self.bounds),
                                              point.y - CGRectGetMidY(self.bounds), radius);
    _horizontal = position.x;
    _vertical = position.y;
    [self setNeedsLayout];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateWithTouch:touch];
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [self updateWithTouch:touch];
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { [self reset]; }
- (void)cancelTrackingWithEvent:(UIEvent *)event { [self reset]; }

- (void)reset {
    _horizontal = 0;
    _vertical = 0;
    [self setNeedsLayout];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end

@class BrumLibretroViewController;
static __weak BrumLibretroViewController *BrumCurrentHost;

@interface BrumLibretroViewController () {
@public
    void *_coreHandle;
    BrumRetroFunctions _core;
    BOOL _coreInitialized;
    BOOL _gameLoaded;
    BOOL _stopped;
    BOOL _fastForwardEnabled;
    BOOL _suppressVideo;
    BOOL _screenFillsDisplay;
    BOOL _shutdownRequested;
    unsigned _pixelFormat;
    brum::InputState _input;
    brum::ScreenManager _screenManager;
    std::vector<brum::Placement> _screenPlacements;
    NSMutableArray<CALayer *> *_screenLayers;
    BOOL _paused;
    BOOL _explicitlyPaused;
    BOOL _backgrounded;
    BOOL _audioInterrupted;
    int16_t _pointerX;
    int16_t _pointerY;
    BOOL _pointerPressed;
    unsigned _frameWidth;
    unsigned _frameHeight;
    CADisplayLink *_displayLink;
    UIImageView *_screen;
    UILabel *_statusLabel;
    UIButton *_fastForwardButton;
    UIButton *_displayModeButton;
    UIButton *_stateButton;
    BrumVirtualStick *_virtualStick;
    UIView *_digitalPad;
    UIButton *_padModeButton;
    BOOL _dpadMode;
    uint8_t _n64CButtonMask;
    NSURL *_romURL;
    NSData *_romData;
    NSString *_gameTitle;
    NSString *_systemDirectory;
    NSString *_coreAssetsDirectory;
    NSString *_saveDirectory;
    NSString *_savePath;
    NSString *_saveManifestPath;
    NSString *_canonicalGameID;
    NSString *_emulatedSystemID;
    NSString *_contentSHA256;
    NSString *_coreID;
    NSString *_coreVersion;
    NSString *_coreDisplayName;
    NSString *_coreLibraryName;
    NSInteger _retroAchievementsGameID;
    NSString *_saveIdentifier;
    NSString *_legacySaveBasename;
    NSMutableDictionary<NSString *, NSString *> *_variables;
    BrumEmulatorExitHandler _onExit;
    NSError *_startupError;
    AudioQueueRef _audioQueue;
    double _audioSampleRate;
    int16_t *_audioRing;
    size_t _audioCapacity;
    size_t _audioRead;
    size_t _audioWrite;
    size_t _audioCount;
    os_unfair_lock _audioLock;
    EAGLContext *_hardwareContext;
    brum_retro_hw_render_callback _hardwareCallback;
    GLuint _hardwareFramebuffer;
    GLuint _hardwareColorTexture;
    GLuint _hardwareDepthStencil;
    GLsizei _hardwareSurfaceSize;
    BOOL _hardwarePending;
    BOOL _hardwareInitialized;
    brum_retro_system_av_info _pendingAVInfo;
    BOOL _hasPendingAVInfo;
}

- (void)closeEmulator;
- (void)stopCore;
- (void)persistSaveRAM;
- (void)updateDisplayModeButton;
- (void)showStateMenu;
- (void)saveStateAtSlot:(NSInteger)slot;
- (void)loadStateAtSlot:(NSInteger)slot;
- (void)showStateStatus:(NSString *)text error:(BOOL)error;
- (BOOL)startAudio:(double)sampleRate error:(NSError **)error;
- (void)applyPendingAVInfo;
- (void)presentFrame:(CGImageRef)image;
- (void)layoutScreens;
- (void)showScreenMenu;
- (void)updatePauseState;
- (BOOL)configureHardware:(brum_retro_hw_render_callback *)callback;
- (BOOL)initializeHardware:(NSError **)error;
- (void)destroyHardware;
- (void)handleCoreShutdown;
- (BrumVirtualStick *)analogPad;
- (UIStackView *)n64ActionPad;
- (UIStackView *)segaActionPad;
- (void)virtualStickChanged:(BrumVirtualStick *)stick;
- (void)toggleAnalogPadMode;
- (void)updateN64CButtons;
@end

static void *BrumLoadSymbol(void *handle, const char *name) {
    dlerror();
    return dlsym(handle, name);
}

static void BrumCoreLog(int level, const char *format, ...) {
    if (!format) return;
    char message[2048];
    va_list arguments; va_start(arguments, format);
    vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);
    NSLog(@"BRUM Core [%d] %s", level, message);
}

static uintptr_t BrumCurrentFramebuffer(void) {
    BrumLibretroViewController *host = BrumCurrentHost;
    return host && host->_hardwareInitialized ? host->_hardwareFramebuffer : 0;
}

static brum_retro_proc_address_t BrumGetProcAddress(const char *name) {
    return name ? (brum_retro_proc_address_t)dlsym(RTLD_DEFAULT, name) : NULL;
}

static bool BrumValidGeometry(const brum_retro_game_geometry *geometry) {
    return geometry && geometry->base_width > 0 && geometry->base_height > 0 &&
        geometry->max_width >= geometry->base_width && geometry->max_height >= geometry->base_height &&
        geometry->max_width <= 4096 && geometry->max_height <= 4096 &&
        isfinite(geometry->aspect_ratio) && geometry->aspect_ratio >= 0;
}

static void BrumRegisterCoreOption(BrumLibretroViewController *host, const char *key, const char *defaultValue, const char *firstValue) {
    if (!key) return;
    NSString *optionKey = [NSString stringWithUTF8String:key];
    const char *selected = defaultValue ?: firstValue;
    if (optionKey.length && selected && !host->_variables[optionKey]) {
        host->_variables[optionKey] = [NSString stringWithUTF8String:selected];
    }
}

static void BrumRegisterCoreOptions(BrumLibretroViewController *host, const brum_retro_core_option_definition *definitions) {
    for (const brum_retro_core_option_definition *option = definitions; option && option->key; option++) {
        BrumRegisterCoreOption(host, option->key, option->default_value, option->values[0].value);
    }
}

static void BrumRegisterCoreOptionsV2(BrumLibretroViewController *host, const brum_retro_core_options_v2 *options) {
    const brum_retro_core_option_v2_definition *definitions = options ? options->definitions : NULL;
    for (const brum_retro_core_option_v2_definition *option = definitions; option && option->key; option++) {
        BrumRegisterCoreOption(host, option->key, option->default_value, option->values[0].value);
    }
}

static bool BrumEnvironment(unsigned command, void *data) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host) return false;
    switch (command) {
        case BRUM_RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            unsigned format = *(unsigned *)data;
            if (format > BRUM_RETRO_PIXEL_FORMAT_RGB565) return false;
            host->_pixelFormat = format;
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            *(const char **)data = host->_systemDirectory.fileSystemRepresentation;
            return true;
        case BRUM_RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = host->_saveDirectory.fileSystemRepresentation;
            return true;
        case BRUM_RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
            *(const char **)data = host->_coreAssetsDirectory.fileSystemRepresentation;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_GEOMETRY:
            // Frame dimensions arrive in the video callback; accept a valid
            // geometry change without inventing a different rendered size.
            return BrumValidGeometry((const brum_retro_game_geometry *)data);
        case BRUM_RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: {
            const brum_retro_system_av_info *info = (const brum_retro_system_av_info *)data;
            if (!info || !BrumValidGeometry(&info->geometry) || !isfinite(info->timing.fps) ||
                info->timing.fps < 20 || info->timing.fps > 240 ||
                !isfinite(info->timing.sample_rate) || info->timing.sample_rate < 8000 ||
                info->timing.sample_rate > 192000) return false;
            host->_pendingAVInfo = *info;
            host->_hasPendingAVInfo = YES;
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_LANGUAGE:
            *(unsigned *)data = 9; // Portuguese (Brazil)
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_VARIABLES: {
            const brum_retro_variable *variable = (const brum_retro_variable *)data;
            while (variable && variable->key) {
                NSString *key = [NSString stringWithUTF8String:variable->key];
                NSString *definition = variable->value ? [NSString stringWithUTF8String:variable->value] : @"";
                NSString *choices = [[definition componentsSeparatedByString:@"; "] lastObject] ?: @"";
                NSString *value = [[choices componentsSeparatedByString:@"|"] firstObject] ?: @"";
                if (key.length && value.length && !host->_variables[key]) host->_variables[key] = value;
                variable++;
            }
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE: {
            brum_retro_variable *variable = (brum_retro_variable *)data;
            if (!variable || !variable->key) return false;
            NSString *key = [NSString stringWithUTF8String:variable->key];
            variable->value = [host->_variables[key] UTF8String];
            return variable->value != NULL;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            *(bool *)data = false;
            return true;
        case BRUM_RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            brum_retro_log_callback *callback = (brum_retro_log_callback *)data;
            if (!callback) return false;
            callback->log = BrumCoreLog;
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE:
            *(int *)data = 3;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_HW_RENDER:
            return [host configureHardware:(brum_retro_hw_render_callback *)data];
        case BRUM_RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT:
            // The EAGL adapter owns one context per session, not a shared
            // context. Never tell a backend that cross-context resources work.
            return false;
        case BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS:
            BrumRegisterCoreOptions(host, (const brum_retro_core_option_definition *)data);
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL: {
            const brum_retro_core_options_intl *options = (const brum_retro_core_options_intl *)data;
            BrumRegisterCoreOptions(host, options ? (options->local ?: options->us) : NULL);
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
            BrumRegisterCoreOptionsV2(host, (const brum_retro_core_options_v2 *)data);
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL: {
            const brum_retro_core_options_v2_intl *options = (const brum_retro_core_options_v2_intl *)data;
            BrumRegisterCoreOptionsV2(host, options ? (options->local ?: options->us) : NULL);
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER:
            *(unsigned *)data = BRUM_RETRO_HW_CONTEXT_OPENGLES3;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_MESSAGE: {
            const brum_retro_message *message = (const brum_retro_message *)data;
            if (message && message->msg) {
                NSString *text = [NSString stringWithUTF8String:message->msg];
                dispatch_async(dispatch_get_main_queue(), ^{ host->_statusLabel.text = text; });
            }
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_SHUTDOWN: {
            host->_shutdownRequested = YES;
            dispatch_async(dispatch_get_main_queue(), ^{ [host handleCoreShutdown]; });
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
        case BRUM_RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case BRUM_RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true;
        default:
            return false;
    }
}

static void BrumVideo(const void *data, unsigned width, unsigned height, size_t pitch) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || host->_suppressVideo || !data || !width || !height) return;
    if (width > 4096 || height > 4096) return;
    const size_t bytesPerPixel = host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_XRGB8888 ? 4 : 2;
    if (data != BrumHardwareFrameBuffer && (pitch < (size_t)width * bytesPerPixel || pitch > SIZE_MAX / height)) return;
    host->_frameWidth = width;
    host->_frameHeight = height;
    NSMutableData *pixels = [NSMutableData dataWithLength:(NSUInteger)width * height * 4];
    uint32_t *target = (uint32_t *)pixels.mutableBytes;
    if (data == BrumHardwareFrameBuffer) {
        if (!host->_hardwareInitialized || width > (unsigned)host->_hardwareSurfaceSize || height > (unsigned)host->_hardwareSurfaceSize) return;
        glBindFramebuffer(GL_FRAMEBUFFER, host->_hardwareFramebuffer);
        NSMutableData *rgba = [NSMutableData dataWithLength:(NSUInteger)width * height * 4];
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glReadPixels(0, 0, (GLsizei)width, (GLsizei)height, GL_RGBA, GL_UNSIGNED_BYTE, rgba.mutableBytes);
        if (glGetError() != GL_NO_ERROR) return;
        const uint8_t *source = (const uint8_t *)rgba.bytes;
        for (unsigned y = 0; y < height; y++) {
            unsigned sourceY = host->_hardwareCallback.bottom_left_origin ? height - 1 - y : y;
            for (unsigned x = 0; x < width; x++) {
                size_t offset = ((size_t)sourceY * width + x) * 4;
                target[(size_t)y * width + x] = ((uint32_t)source[offset] << 16) |
                    ((uint32_t)source[offset + 1] << 8) | source[offset + 2];
            }
        }
    } else for (unsigned y = 0; y < height; y++) {
        if (host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_XRGB8888) {
            const uint32_t *source = (const uint32_t *)((const uint8_t *)data + y * pitch);
            memcpy(target + (size_t)y * width, source, (size_t)width * 4);
        } else {
            const uint16_t *source = (const uint16_t *)((const uint8_t *)data + y * pitch);
            for (unsigned x = 0; x < width; x++) {
                uint16_t value = source[x];
                unsigned red, green, blue;
                if (host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_RGB565) {
                    red = ((value >> 11) & 31) * 255 / 31;
                    green = ((value >> 5) & 63) * 255 / 63;
                    blue = (value & 31) * 255 / 31;
                } else {
                    red = ((value >> 10) & 31) * 255 / 31;
                    green = ((value >> 5) & 31) * 255 / 31;
                    blue = (value & 31) * 255 / 31;
                }
                target[(size_t)y * width + x] = (red << 16) | (green << 8) | blue;
            }
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGBitmapInfo bitmap = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
    CGImageRef image = CGImageCreate(width, height, 8, 32, (size_t)width * 4, colorSpace, bitmap, provider, NULL, false, kCGRenderingIntentDefault);
    if (image) {
        [host presentFrame:image];
        CGImageRelease(image);
    }
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
}

static void BrumPushAudio(const int16_t *data, size_t frames) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || host->_fastForwardEnabled || !host->_audioRing || !data || !frames) return;
    os_unfair_lock_lock(&host->_audioLock);
    const size_t samples = frames * 2;
    for (size_t index = 0; index < samples; index++) {
        if (host->_audioCount == host->_audioCapacity) {
            host->_audioRead = (host->_audioRead + 1) % host->_audioCapacity;
            host->_audioCount--;
        }
        host->_audioRing[host->_audioWrite] = data[index];
        host->_audioWrite = (host->_audioWrite + 1) % host->_audioCapacity;
        host->_audioCount++;
    }
    os_unfair_lock_unlock(&host->_audioLock);
}

static void BrumAudioSample(int16_t left, int16_t right) {
    int16_t pair[2] = { left, right };
    BrumPushAudio(pair, 1);
}

static size_t BrumAudioBatch(const int16_t *data, size_t frames) {
    BrumPushAudio(data, frames);
    return frames;
}

static void BrumInputPoll(void) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host) return;
    host->_input.release(brum::InputSource::controller);
    GCExtendedGamepad *pad = GCController.controllers.firstObject.extendedGamepad;
    if (!pad) return;
    NSArray<GCControllerButtonInput *> *buttons = @[pad.buttonB, pad.buttonY, pad.buttonOptions ?: pad.buttonMenu, pad.buttonMenu,
        pad.dpad.up, pad.dpad.down, pad.dpad.left, pad.dpad.right, pad.buttonA, pad.buttonX,
        pad.leftShoulder, pad.rightShoulder, pad.leftTrigger, pad.rightTrigger];
    for (NSUInteger i = 0; i < buttons.count; i++) host->_input.set(brum::InputSource::controller, (unsigned)i, buttons[i].isPressed);
    host->_input.set(brum::InputSource::controller, 2, pad.buttonOptions.isPressed);
    if ([host->_emulatedSystemID isEqualToString:@"psx"] ||
        [host->_emulatedSystemID isEqualToString:@"psp"] ||
        [host->_emulatedSystemID isEqualToString:@"dreamcast"] ||
        [@[@"md", @"segacd", @"32x"] containsObject:host->_emulatedSystemID]) {
        host->_input.set(brum::InputSource::controller, 0, pad.buttonA.isPressed);
        host->_input.set(brum::InputSource::controller, 8, pad.buttonB.isPressed);
        host->_input.set(brum::InputSource::controller, 1, pad.buttonX.isPressed);
        host->_input.set(brum::InputSource::controller, 9, pad.buttonY.isPressed);
    } else if ([host->_emulatedSystemID isEqualToString:@"n64"]) {
        // Mupen's default map reads Libretro B/Y as N64 A/B.
        host->_input.set(brum::InputSource::controller, 0, pad.buttonA.isPressed);
        host->_input.set(brum::InputSource::controller, 1, pad.buttonB.isPressed);
    }
    host->_input.setAxis(brum::InputSource::controller, 0, 0, pad.leftThumbstick.xAxis.value);
    host->_input.setAxis(brum::InputSource::controller, 0, 1, -pad.leftThumbstick.yAxis.value);
    // This pinned Mupen revision reverses right-stick X when decoding C buttons.
    host->_input.setAxis(brum::InputSource::controller, 1, 0,
                         [host->_emulatedSystemID isEqualToString:@"n64"] ? -pad.rightThumbstick.xAxis.value : pad.rightThumbstick.xAxis.value);
    host->_input.setAxis(brum::InputSource::controller, 1, 1, -pad.rightThumbstick.yAxis.value);
    host->_input.set(brum::InputSource::controller, 14, pad.leftThumbstickButton.isPressed);
    host->_input.set(brum::InputSource::controller, 15, pad.rightThumbstickButton.isPressed);
}

static int16_t BrumInputState(unsigned port, unsigned device, unsigned index, unsigned identifier) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || port != 0 || host->_paused) return 0;
    if (device == BRUM_RETRO_DEVICE_ANALOG) return host->_input.analog(index, identifier);
    if (index != 0) return 0;
    if (device == BRUM_RETRO_DEVICE_POINTER) {
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_X) return host->_pointerX;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_Y) return host->_pointerY;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_PRESSED) return host->_pointerPressed ? 1 : 0;
        return 0;
    }
    if (device != BRUM_RETRO_DEVICE_JOYPAD || identifier > 15) return 0;
    BOOL pressed = host->_input.pressed(identifier);

    return pressed ? 1 : 0;
}

static void BrumAudioQueueOutput(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    BrumLibretroViewController *host = (__bridge BrumLibretroViewController *)context;
    const size_t requested = buffer->mAudioDataBytesCapacity / sizeof(int16_t);
    int16_t *output = (int16_t *)buffer->mAudioData;
    os_unfair_lock_lock(&host->_audioLock);
    size_t written = 0;
    while (written < requested && host->_audioCount) {
        output[written++] = host->_audioRing[host->_audioRead];
        host->_audioRead = (host->_audioRead + 1) % host->_audioCapacity;
        host->_audioCount--;
    }
    os_unfair_lock_unlock(&host->_audioLock);
    if (written < requested) memset(output + written, 0, (requested - written) * sizeof(int16_t));
    buffer->mAudioDataByteSize = (UInt32)(requested * sizeof(int16_t));
    AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}

@implementation BrumLibretroViewController

- (instancetype)initWithROMURL:(NSURL *)romURL
                         title:(NSString *)title
               canonicalGameID:(NSString *)canonicalGameID
                      systemID:(NSString *)systemID
                 contentSHA256:(NSString *)contentSHA256
                        coreID:(NSString *)coreID
                    coreVersion:(NSString *)coreVersion
                coreDisplayName:(NSString *)coreDisplayName
                coreLibraryName:(NSString *)coreLibraryName
        retroAchievementsGameID:(NSInteger)retroAchievementsGameID
                saveIdentifier:(NSString *)saveIdentifier
            legacySaveBasename:(NSString *)legacySaveBasename
                        onExit:(BrumEmulatorExitHandler)onExit {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _romURL = romURL;
    _gameTitle = [title copy];
    _canonicalGameID = [canonicalGameID copy];
    _emulatedSystemID = [systemID copy];
    _contentSHA256 = [contentSHA256 copy];
    _coreID = [coreID copy];
    _coreVersion = [coreVersion copy];
    _coreDisplayName = [coreDisplayName copy];
    _coreLibraryName = [coreLibraryName copy];
    _retroAchievementsGameID = MAX(0, retroAchievementsGameID);
    _saveIdentifier = [saveIdentifier copy];
    _legacySaveBasename = [legacySaveBasename copy];
    _onExit = [onExit copy];
    _variables = [NSMutableDictionary dictionary];
    _variables[@"system_core_override"] = @"Automatic";
    _variables[@"system_gb_bios_enable"] = @"ON";
    _variables[@"system_gba_bios_enable"] = @"ON";
    _variables[@"system_nds_bios_enable"] = @"ON";
    _variables[@"citra_layout_option"] = @"Default Top-Bottom Screen";
    _variables[@"citra_resolution_factor"] = @"1x (Native)";
    _variables[@"citra_touch_touchscreen"] = @"enabled";
    _screenLayers = [NSMutableArray array];
    _pixelFormat = BRUM_RETRO_PIXEL_FORMAT_0RGB1555;
    _screenFillsDisplay = YES;
    _audioLock = OS_UNFAIR_LOCK_INIT;
    _audioCapacity = 262144;
    _audioRing = (int16_t *)calloc(_audioCapacity, sizeof(int16_t));
    // 2048x2048 bounds the experimental GLES adapter's native output while
    // avoiding a 128+ MB color/depth allocation that can terminate the app.
    _hardwareSurfaceSize = 2048;
    NSError *startupError = nil;
    if (![self prepareDirectories:&startupError]) {
        _startupError = startupError;
    } else {
        NSFileManager *manager = NSFileManager.defaultManager;
        if ([manager fileExistsAtPath:[_systemDirectory stringByAppendingPathComponent:@"aes.zip"]]) {
            _variables[@"geolith_system_type"] = @"aes";
        } else if ([manager fileExistsAtPath:[_systemDirectory stringByAppendingPathComponent:@"neogeo.zip"]]) {
            _variables[@"geolith_system_type"] = @"mvs";
        }
        if (![self loadCore:&startupError]) _startupError = startupError;
    }
    return self;
}

- (BOOL)prepareDirectories:(NSError **)error {
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:error];
    if (!support) return NO;
    NSURL *root = [support URLByAppendingPathComponent:@"IntegratedEmulator" isDirectory:YES];
    NSURL *system = [root URLByAppendingPathComponent:@"System" isDirectory:YES];
    NSURL *savesRoot = [root URLByAppendingPathComponent:@"Saves" isDirectory:YES];
    NSURL *saves = [savesRoot URLByAppendingPathComponent:_emulatedSystemID isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:system withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:saves withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    _systemDirectory = system.path;
    _saveDirectory = saves.path;
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath ?: NSBundle.mainBundle.bundlePath;
    NSURL *bundledAssets = [[NSURL fileURLWithPath:frameworks isDirectory:YES] URLByAppendingPathComponent:@"CoreAssets" isDirectory:YES];
    _coreAssetsDirectory = bundledAssets.path;

    // These two cores require their data below the libretro system directory.
    // Copy only once, keeping the signed application bundle read-only.
    NSFileManager *manager = NSFileManager.defaultManager;
    for (NSString *folder in @[@"PPSSPP", @"dolphin-emu"]) {
        NSURL *source = [bundledAssets URLByAppendingPathComponent:folder isDirectory:YES];
        NSURL *destination = [system URLByAppendingPathComponent:folder isDirectory:YES];
        if ([manager fileExistsAtPath:source.path] && ![manager fileExistsAtPath:destination.path]) {
            if (![manager copyItemAtURL:source toURL:destination error:error]) return NO;
        }
    }

    // Flycast's system layout uses System/dc, while the Files-folder firmware
    // importer intentionally accepts BIOS files anywhere under the ROM root.
    if ([_emulatedSystemID isEqualToString:@"dreamcast"]) {
        NSURL *dc = [system URLByAppendingPathComponent:@"dc" isDirectory:YES];
        if (![manager createDirectoryAtURL:dc withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        for (NSString *filename in @[@"dc_boot.bin", @"dc_flash.bin"]) {
            NSURL *source = [system URLByAppendingPathComponent:filename];
            NSURL *destination = [dc URLByAppendingPathComponent:filename];
            if ([manager fileExistsAtPath:source.path]) {
                NSData *firmware = [NSData dataWithContentsOfURL:source options:NSDataReadingMappedIfSafe error:error];
                if (!firmware) return NO;
                NSData *installed = [NSData dataWithContentsOfURL:destination options:NSDataReadingMappedIfSafe error:nil];
                if (![installed isEqualToData:firmware] &&
                    ![firmware writeToURL:destination options:NSDataWritingAtomic error:error]) return NO;
            }
        }
    }

    // Citra looks for user-supplied keys in Saves/3ds/Citra/sysdata.
    if ([_emulatedSystemID isEqualToString:@"3ds"]) {
        NSURL *sysdata = [[saves URLByAppendingPathComponent:@"Citra" isDirectory:YES] URLByAppendingPathComponent:@"sysdata" isDirectory:YES];
        if (![manager createDirectoryAtURL:sysdata withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        for (NSString *filename in @[@"aes_keys.txt", @"seeddb.bin"]) {
            NSURL *source = [system URLByAppendingPathComponent:filename];
            NSURL *destination = [sysdata URLByAppendingPathComponent:filename];
            if ([manager fileExistsAtPath:source.path] && ![manager fileExistsAtPath:destination.path]) {
                if (![manager copyItemAtURL:source toURL:destination error:error]) return NO;
            }
        }
    }
    NSString *saveName = [_contentSHA256 stringByAppendingPathExtension:@"srm"];
    _savePath = [[saves URLByAppendingPathComponent:saveName] path];
    _saveManifestPath = [[saves URLByAppendingPathComponent:[_contentSHA256 stringByAppendingPathExtension:@"save.json"]] path];

    // Releases anteriores usavam somente o nome do arquivo. Copiamos o save
    // antigo uma única vez; nunca o apagamos, para que a migração seja reversível.
    NSString *legacyName = [_legacySaveBasename stringByAppendingPathExtension:@"srm"];
    NSString *legacyPath = [[savesRoot URLByAppendingPathComponent:legacyName] path];
    if (![manager fileExistsAtPath:_savePath] && [manager fileExistsAtPath:legacyPath]) {
        if (![manager copyItemAtPath:legacyPath toPath:_savePath error:error]) return NO;
    }
    return YES;
}

- (BOOL)loadCore:(NSError **)error {
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath ?: NSBundle.mainBundle.bundlePath;
    NSString *path = [frameworks stringByAppendingPathComponent:_coreLibraryName];
    _coreHandle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!_coreHandle) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O núcleo interno %@ não está presente neste IPA.", _coreDisplayName]}];
        return NO;
    }
#define BRUM_LOAD(field, symbol) do { _core.field = (decltype(_core.field))BrumLoadSymbol(_coreHandle, symbol); if (!_core.field) { if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Núcleo inválido: falta %s.", symbol]}]; return NO; } } while (0)
    BRUM_LOAD(apiVersion, "retro_api_version");
    BRUM_LOAD(initialize, "retro_init");
    BRUM_LOAD(deinitialize, "retro_deinit");
    BRUM_LOAD(setEnvironment, "retro_set_environment");
    BRUM_LOAD(setVideo, "retro_set_video_refresh");
    BRUM_LOAD(setAudio, "retro_set_audio_sample");
    BRUM_LOAD(setAudioBatch, "retro_set_audio_sample_batch");
    BRUM_LOAD(setInputPoll, "retro_set_input_poll");
    BRUM_LOAD(setInputState, "retro_set_input_state");
    BRUM_LOAD(getSystemInfo, "retro_get_system_info");
    BRUM_LOAD(getAVInfo, "retro_get_system_av_info");
    BRUM_LOAD(loadGame, "retro_load_game");
    BRUM_LOAD(unloadGame, "retro_unload_game");
    BRUM_LOAD(run, "retro_run");
    BRUM_LOAD(setController, "retro_set_controller_port_device");
    BRUM_LOAD(getMemoryData, "retro_get_memory_data");
    BRUM_LOAD(getMemorySize, "retro_get_memory_size");
    BRUM_LOAD(serializeSize, "retro_serialize_size");
    BRUM_LOAD(serialize, "retro_serialize");
    BRUM_LOAD(unserialize, "retro_unserialize");
#undef BRUM_LOAD
    if (_core.apiVersion() != BRUM_RETRO_API_VERSION) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"A versão do núcleo não é compatível com este aplicativo."}];
        return NO;
    }
    return YES;
}

- (BOOL)configureHardware:(brum_retro_hw_render_callback *)callback {
    if (!callback) return NO;
    BOOL supported = callback->context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES2 ||
        callback->context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES3 ||
        callback->context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES_VERSION;
    if (!supported || callback->version_major > 3 || (callback->version_major == 3 && callback->version_minor > 0)) return NO;
    _hardwareCallback = *callback;
    _hardwareCallback.get_current_framebuffer = BrumCurrentFramebuffer;
    _hardwareCallback.get_proc_address = BrumGetProcAddress;
    callback->get_current_framebuffer = BrumCurrentFramebuffer;
    callback->get_proc_address = BrumGetProcAddress;
    _hardwarePending = YES;
    return YES;
}

- (BOOL)initializeHardware:(NSError **)error {
    if (!_hardwarePending || _hardwareInitialized) return YES;
    EAGLRenderingAPI api = _hardwareCallback.context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES2
        ? kEAGLRenderingAPIOpenGLES2 : kEAGLRenderingAPIOpenGLES3;
    _hardwareContext = [[EAGLContext alloc] initWithAPI:api];
    if (!_hardwareContext || ![EAGLContext setCurrentContext:_hardwareContext]) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:9 userInfo:@{NSLocalizedDescriptionKey: @"Este aparelho não conseguiu criar o contexto OpenGL ES exigido pelo núcleo."}];
        return NO;
    }
    GLint maximumTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maximumTextureSize);
    if (maximumTextureSize < _hardwareSurfaceSize) _hardwareSurfaceSize = maximumTextureSize;
    if (_hardwareSurfaceSize < 1024) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:10 userInfo:@{NSLocalizedDescriptionKey: @"A GPU não oferece uma superfície grande o suficiente para este núcleo."}];
        return NO;
    }
    glGenFramebuffers(1, &_hardwareFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _hardwareFramebuffer);
    glGenTextures(1, &_hardwareColorTexture);
    glBindTexture(GL_TEXTURE_2D, _hardwareColorTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, api == kEAGLRenderingAPIOpenGLES2 ? GL_RGBA : GL_RGBA8, _hardwareSurfaceSize, _hardwareSurfaceSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _hardwareColorTexture, 0);
    if (_hardwareCallback.depth || _hardwareCallback.stencil) {
        glGenRenderbuffers(1, &_hardwareDepthStencil);
        glBindRenderbuffer(GL_RENDERBUFFER, _hardwareDepthStencil);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, _hardwareSurfaceSize, _hardwareSurfaceSize);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _hardwareDepthStencil);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _hardwareDepthStencil);
    }
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:11 userInfo:@{NSLocalizedDescriptionKey: @"A GPU recusou a superfície gráfica do BRUM Core."}];
        [self destroyHardware];
        return NO;
    }
    _hardwareInitialized = YES;
    if (_hardwareCallback.context_reset) _hardwareCallback.context_reset();
    return YES;
}

- (void)destroyHardware {
    if (_hardwareContext) [EAGLContext setCurrentContext:_hardwareContext];
    if (_hardwareInitialized && _hardwareCallback.context_destroy) _hardwareCallback.context_destroy();
    if (_hardwareDepthStencil) glDeleteRenderbuffers(1, &_hardwareDepthStencil);
    if (_hardwareColorTexture) glDeleteTextures(1, &_hardwareColorTexture);
    if (_hardwareFramebuffer) glDeleteFramebuffers(1, &_hardwareFramebuffer);
    _hardwareDepthStencil = 0;
    _hardwareColorTexture = 0;
    _hardwareFramebuffer = 0;
    _hardwareInitialized = NO;
    _hardwarePending = NO;
    if ([EAGLContext currentContext] == _hardwareContext) [EAGLContext setCurrentContext:nil];
    _hardwareContext = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    [self buildInterface];
    if (_startupError) {
        _statusLabel.text = _startupError.localizedDescription;
        _statusLabel.textColor = UIColor.systemRedColor;
        return;
    }
    NSError *error = nil;
    if (![self startCore:&error]) {
        [self stopCore];
        _statusLabel.text = error.localizedDescription ?: @"Não foi possível iniciar o jogo.";
        _statusLabel.textColor = UIColor.systemRedColor;
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionInterrupted:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:AVAudioSession.sharedInstance];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    _backgrounded = YES;
    [self updatePauseState];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    _backgrounded = NO;
    [self updatePauseState];
}

- (BOOL)isPaused { return _paused; }

- (BrumBackendCapabilities)capabilities {
    if (!_gameLoaded || _stopped) return 0;
    BrumBackendCapabilities result = BrumBackendVideo | BrumBackendController | BrumBackendFastForward;
    if (_audioQueue) result |= BrumBackendAudio;
    if (_screenManager.screens.size() > 1) result |= BrumBackendMultipleScreens;
    for (const auto& screen : _screenManager.screens) if (screen.touch) result |= BrumBackendTouch;
    if (_core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM) && _core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM)) result |= BrumBackendSave;
    const size_t size = _core.serializeSize ? _core.serializeSize() : 0;
    if (size && size <= 64 * 1024 * 1024 && _core.serialize && _core.unserialize) result |= BrumBackendSaveState;
    return result;
}

- (void)pause {
    _explicitlyPaused = YES;
    [self updatePauseState];
}

- (void)resume {
    _explicitlyPaused = NO;
    [self updatePauseState];
}

- (void)updatePauseState {
    if (_stopped || !_gameLoaded) return;
    const BOOL shouldPause = _explicitlyPaused || _backgrounded || _audioInterrupted;
    if (_paused == shouldPause) return;
    _paused = shouldPause;
    _displayLink.paused = shouldPause;
    if (shouldPause) {
        _input.clear();
        _n64CButtonMask = 0;
        [_virtualStick reset];
        _virtualStick.enabled = NO;
        _pointerPressed = NO;
        if (_audioQueue) AudioQueuePause(_audioQueue);
        os_unfair_lock_lock(&_audioLock); _audioRead = 0; _audioWrite = 0; _audioCount = 0; os_unfair_lock_unlock(&_audioLock);
        [self persistSaveRAM];
        return;
    }
    _virtualStick.enabled = !_dpadMode;
    if (!_audioQueue) return;
    NSError *error = nil;
    if (![AVAudioSession.sharedInstance setActive:YES error:&error]) {
        [self showStateStatus:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL: %@", error.localizedDescription] error:YES];
        return;
    }
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) [self showStateStatus:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL (%d)", (int)status] error:YES];
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    AVAudioSessionInterruptionType type = static_cast<AVAudioSessionInterruptionType>(
        [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]
    );
    if (type == AVAudioSessionInterruptionTypeBegan) {
        _audioInterrupted = YES;
        [self updatePauseState];
        return;
    }
    _audioInterrupted = NO;
    // Foreground gameplay owns the audio session. Never clear a user/menu pause.
    [self updatePauseState];
}

- (void)buildInterface {
    _screen = [[UIImageView alloc] init];
    _screen.translatesAutoresizingMaskIntoConstraints = NO;
    _screen.backgroundColor = [UIColor colorWithWhite:0.02 alpha:1];
    _screen.layer.magnificationFilter = kCAFilterNearest;
    _screen.clipsToBounds = YES;
    _screen.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *touch = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(screenTouch:)];
    touch.minimumPressDuration = 0;
    touch.allowableMovement = CGFLOAT_MAX;
    touch.cancelsTouchesInView = NO;
    [_screen addGestureRecognizer:touch];
    [self.view addSubview:_screen];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = _gameTitle;
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.view addSubview:title];

    UIButton *close = [self controlButton:@"←  SAIR" identifier:-1];
    [close addTarget:self action:@selector(closeEmulator) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    _fastForwardButton = [self controlButton:@"  5×" identifier:-1];
    UIImageSymbolConfiguration *fastSymbol = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBlack];
    [_fastForwardButton setImage:[[UIImage systemImageNamed:@"forward.fill"] imageWithConfiguration:fastSymbol] forState:UIControlStateNormal];
    _fastForwardButton.tintColor = UIColor.whiteColor;
    _fastForwardButton.accessibilityLabel = @"Avanço rápido, cinco vezes";
    _fastForwardButton.accessibilityValue = @"Desativado";
    [_fastForwardButton addTarget:self action:@selector(toggleFastForward) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_fastForwardButton];

    _displayModeButton = [self controlButton:@"" identifier:-1];
    UIImageSymbolConfiguration *displaySymbol = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightBlack];
    [_displayModeButton setImage:[[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"] imageWithConfiguration:displaySymbol] forState:UIControlStateNormal];
    _displayModeButton.accessibilityLabel = @"Modo de exibição";
    [_displayModeButton addTarget:self action:@selector(toggleDisplayMode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_displayModeButton];
    [self updateDisplayModeButton];

    _stateButton = [self controlButton:@"SLOTS" identifier:-1];
    _stateButton.accessibilityLabel = @"Estados rápidos";
    [_stateButton addTarget:self action:@selector(showStateMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_stateButton];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.text = _retroAchievementsGameID > 0
        ? [NSString stringWithFormat:@"BRUM CORE · %@ · RA ID %ld (PREPARAÇÃO)", _coreDisplayName, (long)_retroAchievementsGameID]
        : [NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName];
    _statusLabel.textColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _statusLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    [self.view addSubview:_statusLabel];

    const BOOL isN64 = [_emulatedSystemID isEqualToString:@"n64"];
    const BOOL isDreamcast = [_emulatedSystemID isEqualToString:@"dreamcast"];
    const BOOL isSega = [@[@"md", @"segacd", @"32x"] containsObject:_emulatedSystemID];
    const BOOL hasAnalogPad = isN64 || isDreamcast || [_emulatedSystemID isEqualToString:@"psp"];
    UIView *up = hasAnalogPad ? [self analogPad] : [self directionPad];
    UIView *actions = isN64 ? [self n64ActionPad] : isSega ? [self segaActionPad] : [self actionPad];
    UIButton *start = [self controlButton:@"START" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_START];
    NSArray<UIButton *> *menuButtons = isDreamcast ? @[start] : @[
        [self controlButton:isN64 ? @"Z" : isSega ? @"MODE" : @"SELECT" identifier:isN64 ? BRUM_RETRO_DEVICE_ID_JOYPAD_L2 : BRUM_RETRO_DEVICE_ID_JOYPAD_SELECT], start
    ];
    UIStackView *menu = [[UIStackView alloc] initWithArrangedSubviews:menuButtons];
    UIButton *leftShoulder = [self controlButton:isDreamcast ? @"LT" : @"L" identifier:isDreamcast ? BRUM_RETRO_DEVICE_ID_JOYPAD_L2 : BRUM_RETRO_DEVICE_ID_JOYPAD_L];
    UIButton *rightShoulder = [self controlButton:isDreamcast ? @"RT" : @"R" identifier:isDreamcast ? BRUM_RETRO_DEVICE_ID_JOYPAD_R2 : BRUM_RETRO_DEVICE_ID_JOYPAD_R];
    leftShoulder.hidden = isSega;
    rightShoulder.hidden = isSega;
    [self.view addSubview:leftShoulder]; [self.view addSubview:rightShoulder];
    if ([_emulatedSystemID isEqualToString:@"psx"]) {
        [leftShoulder setTitle:@"L1" forState:UIControlStateNormal];
        [rightShoulder setTitle:@"R1" forState:UIControlStateNormal];
        UIButton *l2 = [self controlButton:@"L2" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L2];
        UIButton *r2 = [self controlButton:@"R2" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R2];
        [self.view addSubview:l2]; [self.view addSubview:r2];
        [NSLayoutConstraint activateConstraints:@[
            [l2.leadingAnchor constraintEqualToAnchor:leftShoulder.trailingAnchor constant:8],
            [l2.centerYAnchor constraintEqualToAnchor:leftShoulder.centerYAnchor],
            [r2.trailingAnchor constraintEqualToAnchor:rightShoulder.leadingAnchor constant:-8],
            [r2.centerYAnchor constraintEqualToAnchor:rightShoulder.centerYAnchor]
        ]];
    }
    menu.translatesAutoresizingMaskIntoConstraints = NO;
    menu.axis = UILayoutConstraintAxisHorizontal;
    menu.spacing = 10;
    [self.view addSubview:up]; [self.view addSubview:actions]; [self.view addSubview:menu];
    if (hasAnalogPad) {
        _digitalPad = [self directionPad];
        _digitalPad.hidden = YES;
        [self.view addSubview:_digitalPad];
        _padModeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _padModeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_padModeButton setTitle:@"D-PAD" forState:UIControlStateNormal];
        [_padModeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        _padModeButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        _padModeButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.82];
        _padModeButton.layer.cornerRadius = 12;
        _padModeButton.accessibilityLabel = @"Alternar analógico e direcional digital";
        _padModeButton.accessibilityValue = @"Analógico ativo";
        [_padModeButton addTarget:self action:@selector(toggleAnalogPadMode) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_padModeButton];
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [close.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [close.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [close.widthAnchor constraintEqualToConstant:92],
        [_fastForwardButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_fastForwardButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [_fastForwardButton.widthAnchor constraintEqualToConstant:92],
        [_displayModeButton.trailingAnchor constraintEqualToAnchor:_fastForwardButton.leadingAnchor constant:-10],
        [_displayModeButton.centerYAnchor constraintEqualToAnchor:_fastForwardButton.centerYAnchor],
        [_displayModeButton.widthAnchor constraintEqualToConstant:54],
        [_stateButton.trailingAnchor constraintEqualToAnchor:_displayModeButton.leadingAnchor constant:-10],
        [_stateButton.centerYAnchor constraintEqualToAnchor:_displayModeButton.centerYAnchor],
        [_stateButton.widthAnchor constraintEqualToConstant:64],
        [title.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [title.centerYAnchor constraintEqualToAnchor:close.centerYAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:close.trailingAnchor constant:8],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:_stateButton.leadingAnchor constant:-8],
        [_statusLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [_statusLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [_screen.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [_screen.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_screen.topAnchor constraintEqualToAnchor:self.view.topAnchor], [_screen.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [up.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:26], [up.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-24],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-30], [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-36],
        [menu.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [menu.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
        [leftShoulder.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18], [leftShoulder.topAnchor constraintEqualToAnchor:safe.topAnchor constant:66],
        [rightShoulder.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18], [rightShoulder.topAnchor constraintEqualToAnchor:safe.topAnchor constant:66]
    ]];
    if (hasAnalogPad) {
        [NSLayoutConstraint activateConstraints:@[
            [_digitalPad.centerXAnchor constraintEqualToAnchor:up.centerXAnchor],
            [_digitalPad.centerYAnchor constraintEqualToAnchor:up.centerYAnchor],
            [_padModeButton.leadingAnchor constraintEqualToAnchor:up.leadingAnchor],
            [_padModeButton.bottomAnchor constraintEqualToAnchor:up.topAnchor constant:-8],
            [_padModeButton.widthAnchor constraintEqualToConstant:66],
            [_padModeButton.heightAnchor constraintEqualToConstant:32]
        ]];
    }
  }

- (UIButton *)controlButton:(NSString *)text identifier:(NSInteger)identifier {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = identifier;
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    button.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.82];
    button.layer.cornerRadius = 18;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    button.layer.borderWidth = 1;
    if (identifier >= 0) {
        [button addTarget:self action:@selector(inputDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(inputUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    }
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:54].active = YES;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;
    return button;
}

- (UIStackView *)directionPad {
    UIButton *up = [self controlButton:@"▲" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_UP];
    UIButton *down = [self controlButton:@"▼" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_DOWN];
    UIButton *left = [self controlButton:@"◀" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_LEFT];
    UIButton *right = [self controlButton:@"▶" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_RIGHT];
    UIView *blank1 = [[UIView alloc] init]; UIView *blank2 = [[UIView alloc] init]; UIView *blank3 = [[UIView alloc] init]; UIView *blank4 = [[UIView alloc] init]; UIView *center = [[UIView alloc] init];
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[blank1, up, blank2]];
    UIStackView *middle = [[UIStackView alloc] initWithArrangedSubviews:@[left, center, right]];
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[blank3, down, blank4]];
    for (UIStackView *row in @[top, middle, bottom]) { row.axis = UILayoutConstraintAxisHorizontal; row.distribution = UIStackViewDistributionFillEqually; }
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:@[top, middle, bottom]];
    pad.translatesAutoresizingMaskIntoConstraints = NO; pad.axis = UILayoutConstraintAxisVertical; pad.distribution = UIStackViewDistributionFillEqually;
    [pad.widthAnchor constraintEqualToConstant:166].active = YES; [pad.heightAnchor constraintEqualToConstant:132].active = YES;
    return pad;
}

- (BrumVirtualStick *)analogPad {
    _virtualStick = [[BrumVirtualStick alloc] initWithFrame:CGRectZero];
    _virtualStick.translatesAutoresizingMaskIntoConstraints = NO;
    [_virtualStick.widthAnchor constraintEqualToConstant:146].active = YES;
    [_virtualStick.heightAnchor constraintEqualToConstant:146].active = YES;
    [_virtualStick addTarget:self action:@selector(virtualStickChanged:) forControlEvents:UIControlEventValueChanged];
    return _virtualStick;
}

- (UIStackView *)n64ActionPad {
    UIButton *cUp = [self controlButton:@"C▲" identifier:16];
    UIButton *cRight = [self controlButton:@"C▶" identifier:19];
    UIButton *b = [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_Y];
    UIButton *a = [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B];
    UIButton *cLeft = [self controlButton:@"C◀" identifier:18];
    UIButton *cDown = [self controlButton:@"C▼" identifier:17];
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[cUp, cRight]];
    UIStackView *middle = [[UIStackView alloc] initWithArrangedSubviews:@[b, a]];
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[cLeft, cDown]];
    for (UIStackView *row in @[top, middle, bottom]) {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 8;
        row.distribution = UIStackViewDistributionFillEqually;
    }
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:@[top, middle, bottom]];
    pad.translatesAutoresizingMaskIntoConstraints = NO;
    pad.axis = UILayoutConstraintAxisVertical;
    pad.spacing = 4;
    [pad.widthAnchor constraintEqualToConstant:116].active = YES;
    return pad;
}

- (UIStackView *)segaActionPad {
    // BlastEm's pinned Libretro map is B/A/R for A/B/C and Y/X/L for X/Y/Z.
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self controlButton:@"X" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_Y],
        [self controlButton:@"Y" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_X],
        [self controlButton:@"Z" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L]
    ]];
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B],
        [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A],
        [self controlButton:@"C" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R]
    ]];
    for (UIStackView *row in @[top, bottom]) {
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 5;
        row.distribution = UIStackViewDistributionFillEqually;
    }
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:@[top, bottom]];
    pad.translatesAutoresizingMaskIntoConstraints = NO;
    pad.axis = UILayoutConstraintAxisVertical;
    pad.spacing = 5;
    return pad;
}

- (void)virtualStickChanged:(BrumVirtualStick *)stick {
    [self setAnalogStick:0 axis:0 value:_dpadMode ? 0 : stick.horizontal source:BrumInputVirtualPad];
    [self setAnalogStick:0 axis:1 value:_dpadMode ? 0 : stick.vertical source:BrumInputVirtualPad];
}

- (void)toggleAnalogPadMode {
    _dpadMode = !_dpadMode;
    [_virtualStick reset];
    for (unsigned direction = 4; direction <= 7; ++direction)
        _input.set(brum::InputSource::virtualPad, direction, false);
    _virtualStick.hidden = _dpadMode;
    _virtualStick.enabled = !_dpadMode && !_paused;
    _digitalPad.hidden = !_dpadMode;
    [_padModeButton setTitle:_dpadMode ? @"STICK" : @"D-PAD" forState:UIControlStateNormal];
    _padModeButton.accessibilityValue = _dpadMode ? @"D-pad ativo" : @"Analógico ativo";
}

- (void)updateN64CButtons {
    const auto axes = brum::n64CButtons(_n64CButtonMask);
    [self setAnalogStick:1 axis:0 value:axes.x source:BrumInputVirtualPad];
    [self setAnalogStick:1 axis:1 value:axes.y source:BrumInputVirtualPad];
}

- (UIStackView *)actionPad {
    UIButton *y = [self controlButton:@"Y" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_Y];
    UIButton *x = [self controlButton:@"X" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_X];
    UIButton *b = [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B];
    UIButton *a = [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A];
    if ([_emulatedSystemID isEqualToString:@"psx"] || [_emulatedSystemID isEqualToString:@"psp"]) {
        [y setTitle:@"□" forState:UIControlStateNormal];
        [x setTitle:@"△" forState:UIControlStateNormal];
        [b setTitle:@"×" forState:UIControlStateNormal];
        [a setTitle:@"○" forState:UIControlStateNormal];
    } else if ([_emulatedSystemID isEqualToString:@"dreamcast"]) {
        [y setTitle:@"X" forState:UIControlStateNormal];
        [x setTitle:@"Y" forState:UIControlStateNormal];
        [b setTitle:@"A" forState:UIControlStateNormal];
        [a setTitle:@"B" forState:UIControlStateNormal];
    }
    for (UIButton *button in @[y, x, b, a]) { button.layer.cornerRadius = 26; [button.widthAnchor constraintEqualToConstant:52].active = YES; [button.heightAnchor constraintEqualToConstant:52].active = YES; }
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[y, x]];
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[b, a]];
    top.axis = UILayoutConstraintAxisHorizontal; bottom.axis = UILayoutConstraintAxisHorizontal; top.spacing = 12; bottom.spacing = 12;
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:@[top, bottom]];
    pad.translatesAutoresizingMaskIntoConstraints = NO; pad.axis = UILayoutConstraintAxisVertical; pad.spacing = 8;
    return pad;
}

- (void)screenTouch:(UILongPressGestureRecognizer *)gesture {
    if (_paused || !_frameWidth || !_frameHeight || !(self.capabilities & BrumBackendTouch)) {
        _pointerPressed = NO;
        return;
    }
    CGPoint point = [gesture locationInView:_screen];
    if (_screenManager.screens.size() > 1) {
        const auto touch = brum::ScreenManager::hitTest({point.x, point.y}, _screenPlacements);
        _pointerPressed = touch.pressed && (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged);
        _pointerX = (int16_t)lrint((touch.atlas.x * 2 - 1) * 32767);
        _pointerY = (int16_t)lrint((touch.atlas.y * 2 - 1) * 32767);
        // SkyEmu treats Y == 0 as pen-up, including the first lower-screen row.
        if (_pointerPressed && [_coreID isEqualToString:@"skyemu"]) _pointerY = MAX(1, _pointerY);
        return;
    }
    CGSize bounds = _screen.bounds.size;
    CGFloat scaleX = bounds.width / (CGFloat)_frameWidth;
    CGFloat scaleY = bounds.height / (CGFloat)_frameHeight;
    CGFloat scale = _screenFillsDisplay ? MAX(scaleX, scaleY) : MIN(scaleX, scaleY);
    CGSize image = CGSizeMake((CGFloat)_frameWidth * scale, (CGFloat)_frameHeight * scale);
    CGRect target = CGRectMake((bounds.width - image.width) / 2.0, (bounds.height - image.height) / 2.0, image.width, image.height);
    CGFloat normalizedX = target.size.width > 0 ? ((point.x - CGRectGetMinX(target)) / target.size.width) * 2.0 - 1.0 : 0;
    CGFloat normalizedY = target.size.height > 0 ? ((point.y - CGRectGetMinY(target)) / target.size.height) * 2.0 - 1.0 : 0;
    _pointerX = (int16_t)lrint(MAX(-1.0, MIN(1.0, normalizedX)) * 32767.0);
    _pointerY = (int16_t)lrint(MAX(-1.0, MIN(1.0, normalizedY)) * 32767.0);
    _pointerPressed = (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) && CGRectContainsPoint(target, point);
}

- (void)setButton:(NSUInteger)button source:(BrumInputSource)source pressed:(BOOL)pressed {
    if (button >= 16 || source > BrumInputRemote || (_paused && pressed)) return;
    _input.set(static_cast<brum::InputSource>(source), (unsigned)button, pressed);
}

- (void)releaseInputSource:(BrumInputSource)source {
    if (source <= BrumInputRemote) _input.release(static_cast<brum::InputSource>(source));
}

- (void)setAnalogStick:(NSUInteger)stick axis:(NSUInteger)axis value:(double)value source:(BrumInputSource)source {
    if (_paused || _stopped || source > BrumInputRemote || stick > 1 || axis > 1) return;
    _input.setAxis(static_cast<brum::InputSource>(source), (unsigned)stick, (unsigned)axis, value);
}

- (void)inputDown:(UIButton *)sender {
    if (sender.tag < 0) return;
    if (sender.tag >= 16 && sender.tag <= 19 && [_emulatedSystemID isEqualToString:@"n64"]) {
        if (!_paused && !_stopped) {
            _n64CButtonMask |= (uint8_t)(1u << (sender.tag - 16));
            [self updateN64CButtons];
        }
        return;
    }
    [self setButton:(NSUInteger)sender.tag source:BrumInputVirtualPad pressed:YES];
}

- (void)inputUp:(UIButton *)sender {
    if (sender.tag < 0) return;
    if (sender.tag >= 16 && sender.tag <= 19 && [_emulatedSystemID isEqualToString:@"n64"]) {
        _n64CButtonMask &= (uint8_t)~(1u << (sender.tag - 16));
        [self updateN64CButtons];
        return;
    }
    [self setButton:(NSUInteger)sender.tag source:BrumInputVirtualPad pressed:NO];
}

- (void)presentFrame:(CGImageRef)image {
    _screenManager.screens = brum::libretroScreens(_coreID.UTF8String, _frameWidth, _frameHeight);
    if (_screenManager.screens.size() == 1) {
        for (CALayer *layer in _screenLayers) layer.hidden = YES;
        _screen.layer.contents = (__bridge id)image;
        _screen.layer.contentsGravity = _screenFillsDisplay ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
        return;
    }
    _screen.layer.contents = nil;
    while (_screenLayers.count < _screenManager.screens.size()) {
        CALayer *layer = [CALayer layer];
        layer.magnificationFilter = kCAFilterNearest;
        layer.contentsGravity = kCAGravityResize;
        [_screen.layer addSublayer:layer];
        [_screenLayers addObject:layer];
    }
    [self layoutScreens];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in _screenLayers) layer.contents = (__bridge id)image;
    [CATransaction commit];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutScreens];
}

- (void)layoutScreens {
    if (_screenManager.screens.size() < 2) return;
    const CGSize size = _screen.bounds.size;
    _screenPlacements = _screenManager.place({0, 0, size.width, size.height});
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in _screenLayers) layer.hidden = YES;
    for (NSUInteger i = 0; i < _screenPlacements.size() && i < _screenLayers.count; i++) {
        CALayer *layer = _screenLayers[i];
        const auto& p = _screenPlacements[i];
        layer.hidden = NO;
        layer.affineTransform = CGAffineTransformIdentity;
        const BOOL rotated = p.quarterTurns % 2 != 0;
        layer.bounds = CGRectMake(0, 0, rotated ? p.frame.height : p.frame.width, rotated ? p.frame.width : p.frame.height);
        layer.position = CGPointMake(p.frame.x + p.frame.width / 2, p.frame.y + p.frame.height / 2);
        layer.contentsRect = CGRectMake(p.screen.crop.x, p.screen.crop.y, p.screen.crop.width, p.screen.crop.height);
        layer.affineTransform = CGAffineTransformMakeRotation(p.quarterTurns * M_PI_2);
    }
    [CATransaction commit];
}

- (void)showScreenMenu {
    if (self.presentedViewController) return;
    const BOOL wasPaused = _explicitlyPaused;
    [self pause];
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"TELAS" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSString *> *titles = @[@"Superior em cima", @"Inferior em cima", @"Superior à esquerda", @"Inferior à esquerda", @"Somente superior", @"Somente inferior"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        [menu addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            self->_screenManager.layout = static_cast<brum::Layout>(i);
            self->_pointerPressed = NO;
            [self layoutScreens];
            if (!wasPaused) [self resume];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Girar telas 90°" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        self->_screenManager.quarterTurns = (self->_screenManager.quarterTurns + 1) % 4;
        [self layoutScreens];
        if (!wasPaused) [self resume];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Alternar escala 75% / 100%" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        self->_screenManager.scale = self->_screenManager.scale == 1 ? 0.75 : 1;
        [self layoutScreens];
        if (!wasPaused) [self resume];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Voltar ao jogo" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) { if (!wasPaused) [self resume]; }]];
    menu.popoverPresentationController.sourceView = _displayModeButton;
    menu.popoverPresentationController.sourceRect = _displayModeButton.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)toggleFastForward {
    _fastForwardEnabled = !_fastForwardEnabled;
    os_unfair_lock_lock(&_audioLock);
    _audioRead = 0; _audioWrite = 0; _audioCount = 0;
    os_unfair_lock_unlock(&_audioLock);
    UIColor *accent = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _fastForwardButton.backgroundColor = _fastForwardEnabled ? accent : [UIColor colorWithWhite:0.1 alpha:0.82];
    [_fastForwardButton setTitleColor:_fastForwardEnabled ? UIColor.blackColor : UIColor.whiteColor forState:UIControlStateNormal];
    _fastForwardButton.tintColor = _fastForwardEnabled ? UIColor.blackColor : UIColor.whiteColor;
    _fastForwardButton.layer.borderColor = (_fastForwardEnabled ? accent : [UIColor colorWithWhite:1 alpha:0.16]).CGColor;
    _fastForwardButton.accessibilityValue = _fastForwardEnabled ? @"Ativado" : @"Desativado";
    _fastForwardButton.accessibilityTraits = _fastForwardEnabled ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    _statusLabel.text = _fastForwardEnabled ? @"AVANÇO RÁPIDO · 5×" : [NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName];
}

- (void)toggleDisplayMode {
    if (self.capabilities & BrumBackendMultipleScreens) { [self showScreenMenu]; return; }
    _screenFillsDisplay = !_screenFillsDisplay;
    [self updateDisplayModeButton];
}

- (void)updateDisplayModeButton {
    UIColor *accent = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _displayModeButton.backgroundColor = _screenFillsDisplay ? accent : [UIColor colorWithWhite:0.1 alpha:0.82];
    _displayModeButton.tintColor = _screenFillsDisplay ? UIColor.blackColor : UIColor.whiteColor;
    _displayModeButton.layer.borderColor = (_screenFillsDisplay ? accent : [UIColor colorWithWhite:1 alpha:0.16]).CGColor;
    _displayModeButton.accessibilityValue = _screenFillsDisplay ? @"Preencher tela" : @"Mostrar imagem inteira";
    _displayModeButton.accessibilityTraits = _screenFillsDisplay ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    _screen.layer.contentsGravity = _screenFillsDisplay ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
}

- (NSString *)statePathForSlot:(NSInteger)slot {
    return [_saveDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.slot%ld.state", _contentSHA256, (long)slot]];
}

- (void)showStateMenu {
    if (!_gameLoaded || _stopped || self.presentedViewController) return;
    if (!(self.capabilities & BrumBackendSaveState)) { [self showStateStatus:@"ESTADO RÁPIDO INDISPONÍVEL" error:YES]; return; }
    const BOOL wasPaused = _explicitlyPaused;
    [self pause];
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"ESTADOS RÁPIDOS"
                                                                   message:@"O save normal continua separado. Escolha um dos três slots locais."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger slot = 1; slot <= 3; slot++) {
        NSInteger selected = slot;
        [menu addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Salvar no slot %ld", (long)slot]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *action) { [self saveStateAtSlot:selected]; if (!wasPaused) [self resume]; }]];
        UIAlertAction *load = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Carregar slot %ld", (long)slot]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(__unused UIAlertAction *action) { [self loadStateAtSlot:selected]; if (!wasPaused) [self resume]; }];
        load.enabled = [NSFileManager.defaultManager fileExistsAtPath:[self statePathForSlot:slot]];
        [menu addAction:load];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) { if (!wasPaused) [self resume]; }]];
    if (menu.popoverPresentationController) {
        menu.popoverPresentationController.sourceView = _stateButton;
        menu.popoverPresentationController.sourceRect = _stateButton.bounds;
    }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)saveStateAtSlot:(NSInteger)slot {
    size_t size = _core.serializeSize();
    if (!size || size > 64 * 1024 * 1024) { [self showStateStatus:@"ESTADO RÁPIDO INDISPONÍVEL" error:YES]; return; }
    NSMutableData *state = [NSMutableData dataWithLength:size];
    if (!_core.serialize(state.mutableBytes, size) || ![state writeToFile:[self statePathForSlot:slot] options:NSDataWritingAtomic error:nil]) {
        [self showStateStatus:@"NÃO FOI POSSÍVEL SALVAR O SLOT" error:YES]; return;
    }
    NSDictionary *metadata = @{
        @"schemaVersion": @1, @"canonicalGameID": _canonicalGameID, @"systemID": _emulatedSystemID, @"coreID": _coreID,
        @"coreVersion": _coreVersion, @"slot": @(slot),
        @"sizeBytes": @(size), @"updatedAt": [NSISO8601DateFormatter stringFromDate:NSDate.date timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0] formatOptions:NSISO8601DateFormatWithInternetDateTime]
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:metadata options:NSJSONWritingSortedKeys error:nil];
    if (!json || ![json writeToFile:[[self statePathForSlot:slot] stringByAppendingString:@".json"] options:NSDataWritingAtomic error:nil]) {
        [NSFileManager.defaultManager removeItemAtPath:[self statePathForSlot:slot] error:nil];
        [self showStateStatus:@"NÃO FOI POSSÍVEL CONCLUIR O SLOT" error:YES]; return;
    }
    [self showStateStatus:[NSString stringWithFormat:@"SLOT %ld SALVO", (long)slot] error:NO];
}

- (void)loadStateAtSlot:(NSInteger)slot {
    NSString *path = [self statePathForSlot:slot];
    NSData *metadataData = [NSData dataWithContentsOfFile:[path stringByAppendingString:@".json"]];
    NSDictionary *metadata = metadataData ? [NSJSONSerialization JSONObjectWithData:metadataData options:0 error:nil] : nil;
    BOOL compatible = [metadata isKindOfClass:NSDictionary.class] && [metadata[@"schemaVersion"] integerValue] == 1 &&
        [metadata[@"slot"] integerValue] == slot && [metadata[@"canonicalGameID"] isEqualToString:_canonicalGameID] &&
        [metadata[@"systemID"] isEqualToString:_emulatedSystemID] && [metadata[@"coreID"] isEqualToString:_coreID] &&
        [metadata[@"coreVersion"] isEqualToString:_coreVersion];
    NSData *state = compatible ? [NSData dataWithContentsOfFile:path] : nil;
    size_t expected = _core.serializeSize();
    if (!state || !expected || state.length != expected || [metadata[@"sizeBytes"] unsignedLongLongValue] != state.length || !_core.unserialize(state.bytes, state.length)) {
        [self showStateStatus:@"ESTADO INCOMPATÍVEL OU CORROMPIDO" error:YES]; return;
    }
    os_unfair_lock_lock(&_audioLock); _audioRead = 0; _audioWrite = 0; _audioCount = 0; os_unfair_lock_unlock(&_audioLock);
    [self showStateStatus:[NSString stringWithFormat:@"SLOT %ld CARREGADO", (long)slot] error:NO];
}

- (void)showStateStatus:(NSString *)text error:(BOOL)error {
    _statusLabel.text = text;
    _statusLabel.textColor = error ? UIColor.systemRedColor : [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    __weak BrumLibretroViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_stopped) return;
        strongSelf->_statusLabel.text = strongSelf->_fastForwardEnabled ? @"AVANÇO RÁPIDO · 5×" : [NSString stringWithFormat:@"BRUM CORE · %@", strongSelf->_coreDisplayName];
        strongSelf->_statusLabel.textColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    });
}

- (BOOL)startCore:(NSError **)error {
    if (_gameLoaded) return YES;
    if (_stopped || !_coreHandle) return NO;
    if (BrumCurrentHost && BrumCurrentHost != self) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:12 userInfo:@{NSLocalizedDescriptionKey: @"Encerre a sessão atual antes de abrir outro jogo."}];
        return NO;
    }
    BrumCurrentHost = self;
    _core.setEnvironment(BrumEnvironment);
    _core.setVideo(BrumVideo);
    _core.setAudio(BrumAudioSample);
    _core.setAudioBatch(BrumAudioBatch);
    _core.setInputPoll(BrumInputPoll);
    _core.setInputState(BrumInputState);
    _core.initialize();
    _coreInitialized = YES;
    _core.setController(0, BRUM_RETRO_DEVICE_JOYPAD);

    brum_retro_system_info systemInfo = {};
    _core.getSystemInfo(&systemInfo);
    brum_retro_game_info gameInfo = {};
    gameInfo.path = _romURL.path.fileSystemRepresentation;
    if (systemInfo.need_fullpath) {
        NSNumber *isRegular = nil;
        NSNumber *fileSize = nil;
        if (![_romURL getResourceValue:&isRegular forKey:NSURLIsRegularFileKey error:error] || !isRegular.boolValue ||
            ![_romURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:error] || fileSize.unsignedLongLongValue == 0) {
            if (error && !*error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"A ROM não está disponível como um arquivo local válido."}];
            return NO;
        }
    } else {
        _romData = [NSData dataWithContentsOfURL:_romURL options:NSDataReadingMappedIfSafe error:error];
        if (!_romData) return NO;
        gameInfo.data = _romData.bytes;
        gameInfo.size = _romData.length;
    }
    if (!_core.loadGame(&gameInfo)) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O núcleo %@ recusou este arquivo. Confirme que a ROM é válida para %@.", _coreDisplayName, _emulatedSystemID.uppercaseString]}];
        return NO;
    }
    _gameLoaded = YES;
    if (![self initializeHardware:error]) return NO;
    [self restoreSaveRAM];
    brum_retro_system_av_info avInfo = {};
    _core.getAVInfo(&avInfo);
    if (_hasPendingAVInfo) { avInfo = _pendingAVInfo; _hasPendingAVInfo = NO; }
    _screenManager.screens = brum::libretroScreens(_coreID.UTF8String, avInfo.geometry.base_width, avInfo.geometry.base_height);
    _stateButton.enabled = (self.capabilities & BrumBackendSaveState) != 0;
    if (![self startAudio:avInfo.timing.sample_rate error:error]) return NO;
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(runFrame)];
    if (@available(iOS 15.0, *)) {
        float fps = (float)MAX(20.0, MIN(120.0, avInfo.timing.fps));
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
    } else { _displayLink.preferredFramesPerSecond = (NSInteger)llround(avInfo.timing.fps); }
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}

- (BOOL)startAudio:(double)sampleRate error:(NSError **)error {
    if (!isfinite(sampleRate) || sampleRate < 8000.0 || sampleRate > 192000.0) sampleRate = 48000.0;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    if (![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:error] ||
        ![session setActive:YES error:error]) return NO;
    NSError *preferredRateError = nil;
    if (![session setPreferredSampleRate:sampleRate error:&preferredRateError]) {
        NSLog(@"BRUM Core: taxa de áudio preferida não aceita: %@", preferredRateError.localizedDescription);
    }
    AudioStreamBasicDescription format = {};
    format.mSampleRate = sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBytesPerPacket = 4; format.mFramesPerPacket = 1; format.mBytesPerFrame = 4;
    format.mChannelsPerFrame = 2; format.mBitsPerChannel = 16;
    OSStatus status = AudioQueueNewOutput(&format, BrumAudioQueueOutput, (__bridge void *)self, NULL, NULL, 0, &_audioQueue);
    if (status != noErr) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O iOS não conseguiu criar a saída de áudio (%d).", (int)status]}];
        return NO;
    }
    NSUInteger allocated = 0;
    for (NSUInteger index = 0; index < 3; index++) {
        AudioQueueBufferRef buffer = NULL;
        if (AudioQueueAllocateBuffer(_audioQueue, 8192, &buffer) == noErr) {
            memset(buffer->mAudioData, 0, 8192); buffer->mAudioDataByteSize = 8192;
            if (AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL) == noErr) allocated++;
        }
    }
    if (allocated < 2) {
        AudioQueueDispose(_audioQueue, true); _audioQueue = NULL;
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:7 userInfo:@{NSLocalizedDescriptionKey: @"O iOS não reservou buffers suficientes para o áudio."}];
        return NO;
    }
    status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) {
        AudioQueueDispose(_audioQueue, true); _audioQueue = NULL;
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:8 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O iOS recusou iniciar o áudio (%d).", (int)status]}];
        return NO;
    }
    _audioSampleRate = sampleRate;
    return YES;
}

- (void)applyPendingAVInfo {
    if (!_hasPendingAVInfo || _stopped) return;
    const brum_retro_system_av_info info = _pendingAVInfo;
    _hasPendingAVInfo = NO;
    if (_displayLink) {
        float fps = (float)MAX(20.0, MIN(120.0, info.timing.fps));
        if (@available(iOS 15.0, *)) {
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
        } else {
            _displayLink.preferredFramesPerSecond = (NSInteger)llround(fps);
        }
    }
    if (!_audioQueue || fabs(info.timing.sample_rate - _audioSampleRate) < 1.0) return;
    AudioQueueRef oldQueue = _audioQueue;
    _audioQueue = NULL;
    AudioQueueStop(oldQueue, true);
    AudioQueueDispose(oldQueue, true);
    os_unfair_lock_lock(&_audioLock);
    _audioRead = 0; _audioWrite = 0; _audioCount = 0;
    os_unfair_lock_unlock(&_audioLock);
    NSError *error = nil;
    if (![self startAudio:info.timing.sample_rate error:&error]) {
        [self showStateStatus:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL: %@", error.localizedDescription ?: @"falha ao mudar a taxa"] error:YES];
    }
}

- (void)runFrame {
    if (_stopped || !_gameLoaded || _paused || _shutdownRequested) return;
    if (_hardwareInitialized) [EAGLContext setCurrentContext:_hardwareContext];
    NSUInteger frameCount = _fastForwardEnabled ? 5 : 1;
    for (NSUInteger frame = 0; frame < frameCount; frame++) {
        _suppressVideo = frame + 1 < frameCount;
        _core.run();
        if (_shutdownRequested) break;
    }
    _suppressVideo = NO;
    [self applyPendingAVInfo];
}

- (void)restoreSaveRAM {
    void *memory = _core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM);
    size_t size = _core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM);
    NSData *save = [NSData dataWithContentsOfFile:_savePath];
    if (memory && size && save.length == size) memcpy(memory, save.bytes, size);
}

- (void)persistSaveRAM {
    if (!_gameLoaded) return;
    void *memory = _core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM);
    size_t size = _core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM);
    if (!memory || !size) return;

    NSData *payload = [NSData dataWithBytes:memory length:size];
    NSString *payloadHash = BrumSHA256(payload);
    NSDictionary *previous = nil;
    NSData *previousData = [NSData dataWithContentsOfFile:_saveManifestPath];
    if (previousData) {
        id decoded = [NSJSONSerialization JSONObjectWithData:previousData options:0 error:nil];
        if ([decoded isKindOfClass:NSDictionary.class]) previous = decoded;
    }
    BOOL unchanged = [previous[@"payloadSHA256"] isEqualToString:payloadHash] &&
                     [NSFileManager.defaultManager fileExistsAtPath:_savePath];
    if (unchanged) return;

    NSError *writeError = nil;
    if (![payload writeToFile:_savePath options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"BRUM Core: não foi possível persistir o save: %@", writeError.localizedDescription);
        return;
    }
    NSInteger generation = [previous[@"generation"] integerValue] + 1;
    if (generation < 1) generation = 1;
    NSString *deviceID = UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"ios-local";
    NSString *updatedAt = [NSISO8601DateFormatter stringFromDate:NSDate.date
                                                        timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]
                                                   formatOptions:NSISO8601DateFormatWithInternetDateTime];
    NSDictionary *manifest = @{
        @"schemaVersion": @1,
        @"canonicalGameID": _canonicalGameID,
        @"systemID": _emulatedSystemID,
        @"coreID": _coreID,
        @"coreVersion": _coreVersion,
        @"slot": @"battery",
        @"generation": @(generation),
        @"payloadSHA256": payloadHash,
        @"sizeBytes": @(size),
        @"updatedAt": updatedAt,
        @"deviceID": deviceID,
        @"formatVersion": @1,
        @"saveIdentifier": _saveIdentifier
    };
    NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingSortedKeys error:&writeError];
    if (!manifestData || ![manifestData writeToFile:_saveManifestPath options:NSDataWritingAtomic error:&writeError]) {
        NSLog(@"BRUM Core: save gravado, mas o manifesto falhou: %@", writeError.localizedDescription);
    }
}

- (void)closeEmulator {
    if (_stopped) return;
    [self stopCore];
    if (_onExit) _onExit();
}

- (void)handleCoreShutdown {
    if (_stopped || self.presentedViewController) return;
    [_displayLink invalidate]; _displayLink = nil;
    _statusLabel.text = @"O NÚCLEO INTERROMPEU O JOGO";
    _statusLabel.textColor = UIColor.systemRedColor;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"O jogo foi interrompido"
                                                                   message:@"O núcleo encerrou a emulação. Verifique se a ROM e as BIOS exigidas são válidas. A tela foi mantida aberta para mostrar a causa."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak BrumLibretroViewController *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Voltar" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf closeEmulator];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)stopCore {
    if (_stopped) return;
    _stopped = YES;
    _hasPendingAVInfo = NO;
    _input.clear();
    _pointerPressed = NO;
    [_displayLink invalidate]; _displayLink = nil;
    if (_audioQueue) { AudioQueueStop(_audioQueue, true); AudioQueueDispose(_audioQueue, true); _audioQueue = NULL; }
    _audioSampleRate = 0;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    [self persistSaveRAM];
    if (_hardwareInitialized) [EAGLContext setCurrentContext:_hardwareContext];
    [self destroyHardware];
    if (_gameLoaded) { _core.unloadGame(); _gameLoaded = NO; }
    if (_coreInitialized) { _core.deinitialize(); _coreInitialized = NO; }
    if (BrumCurrentHost == self) BrumCurrentHost = nil;
}

- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self stopCore]; }

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopCore];
    if (_coreHandle) dlclose(_coreHandle);
    free(_audioRing);
}

@end

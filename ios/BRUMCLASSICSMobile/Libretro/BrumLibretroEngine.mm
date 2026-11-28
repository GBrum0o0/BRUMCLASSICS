#import "BrumLibretroEngine.h"
#import "BrumLibretroAPI.h"
#import "BrumCoreDiagnostics.h"
#include "BrumScreenProfiles.hpp"
#include "../../../shared/brum-core/InputState.hpp"
#include "../../../shared/brum-core/N64Input.hpp"
#include "../../../shared/brum-core/VirtualControlProfile.hpp"
#include "../../../shared/brum-core/VirtualControlInput.hpp"
#include "../../../shared/brum-core/FrameCadence.hpp"
#include "../../../shared/brum-core/ContentValidation.hpp"
#include "../../../shared/brum-core/RetroAchievementsRuntime.hpp"
#include "../../../shared/brum-core/PokemonFireRedAdapter.hpp"
#include "../../../shared/brum-core/brum_resolution_shaders.hpp"
#include <memory>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <GameController/GameController.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#import <QuartzCore/QuartzCore.h>
#if __has_include("BRUMCLASSICSMobile-Swift.h")
#import "BRUMCLASSICSMobile-Swift.h"
#elif __has_include("BRUMCLASSICSMobileTests-Swift.h")
#import "BRUMCLASSICSMobileTests-Swift.h"
#elif __has_include("BRUMCLASSICSMobileUITests-Swift.h")
#import "BRUMCLASSICSMobileUITests-Swift.h"
#endif
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
    self.multipleTouchEnabled = YES;
    self.exclusiveTouch = NO;
    self.backgroundColor = [UIColor colorWithWhite:0.09 alpha:0.84];
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    self.layer.borderWidth = 1.5;
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

@interface BrumVirtualDPad : UIControl
@property(nonatomic, readonly) uint8_t mask;
- (void)reset;
@end

@implementation BrumVirtualDPad {
    NSArray<UILabel *> *_arrows;
    UIView *_horizontalBar;
    UIView *_verticalBar;
    uint8_t _mask;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.multipleTouchEnabled = NO;
    self.exclusiveTouch = NO;
    self.backgroundColor = [UIColor colorWithWhite:0.09 alpha:0.84];
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    self.layer.borderWidth = 1.5;
    _horizontalBar = [[UIView alloc] init];
    _horizontalBar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09];
    _horizontalBar.layer.cornerRadius = 6;
    _horizontalBar.userInteractionEnabled = NO;
    [self addSubview:_horizontalBar];
    _verticalBar = [[UIView alloc] init];
    _verticalBar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.09];
    _verticalBar.layer.cornerRadius = 6;
    _verticalBar.userInteractionEnabled = NO;
    [self addSubview:_verticalBar];
    NSMutableArray<UILabel *> *arrows = [NSMutableArray array];
    for (NSString *symbol in @[@"▲", @"▼", @"◀", @"▶"]) {
        UILabel *label = [[UILabel alloc] init];
        label.text = symbol;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont boldSystemFontOfSize:19];
        label.layer.cornerRadius = 10;
        label.clipsToBounds = YES;
        [self addSubview:label];
        [arrows addObject:label];
    }
    _arrows = arrows;
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Direcional virtual";
    self.accessibilityHint = @"Deslize entre direções; diagonais são aceitas.";
    return self;
}
- (uint8_t)mask { return _mask; }
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = MIN(self.bounds.size.width, self.bounds.size.height) / 2;
    const CGFloat cx = CGRectGetMidX(self.bounds), cy = CGRectGetMidY(self.bounds);
    const CGFloat armLong = MIN(self.bounds.size.width, self.bounds.size.height) * 0.72;
    const CGFloat armThick = 34;
    _horizontalBar.bounds = CGRectMake(0, 0, armLong, armThick);
    _horizontalBar.center = CGPointMake(cx, cy);
    _verticalBar.bounds = CGRectMake(0, 0, armThick, armLong);
    _verticalBar.center = CGPointMake(cx, cy);
    const CGFloat dx = self.bounds.size.width * 0.30, dy = self.bounds.size.height * 0.29;
    NSArray<NSValue *> *positions = @[
        [NSValue valueWithCGPoint:CGPointMake(cx, cy - dy)],
        [NSValue valueWithCGPoint:CGPointMake(cx, cy + dy)],
        [NSValue valueWithCGPoint:CGPointMake(cx - dx, cy)],
        [NSValue valueWithCGPoint:CGPointMake(cx + dx, cy)]
    ];
    for (NSUInteger i = 0; i < _arrows.count; ++i) {
        UILabel *label = _arrows[i];
        label.bounds = CGRectMake(0, 0, 45, 38);
        label.center = positions[i].CGPointValue;
    }
}
- (void)updateWithTouch:(UITouch *)touch {
    const CGPoint point = [touch locationInView:self];
    const double radius = MAX(1, MIN(self.bounds.size.width, self.bounds.size.height) / 2);
    const uint8_t next = brum::dpadDirections(point.x - CGRectGetMidX(self.bounds),
                                               point.y - CGRectGetMidY(self.bounds), radius, 0.16, _mask);
    if (_mask == next) return;
    _mask = next;
    const uint8_t bits[] = {brum::up, brum::down, brum::left, brum::right};
    for (NSUInteger i = 0; i < _arrows.count; ++i) {
        const BOOL pressed = (_mask & bits[i]) != 0;
        UILabel *label = _arrows[i];
        label.backgroundColor = pressed ? [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1] : UIColor.clearColor;
        label.textColor = pressed ? UIColor.blackColor : UIColor.whiteColor;
    }
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
    if (!_mask) return;
    _mask = 0;
    for (UILabel *label in _arrows) { label.backgroundColor = UIColor.clearColor; label.textColor = UIColor.whiteColor; }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end

@class BrumLibretroViewController;
static __weak BrumLibretroViewController *BrumCurrentHost;

@interface BrumLibretroViewController () <UIGestureRecognizerDelegate> {
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
    BOOL _readyDelivered;
    BOOL _exitDelivered;
    BOOL _failurePresented;
    uint64_t _sessionFrames;
    uint64_t _presentedFrames;
    uint64_t _audioSamplesProduced;
    uint64_t _audioSamplesConsumed;
    uint64_t _audioSamplesDropped;
    uint64_t _audioSamplesMissing;
    BrumCoreDiagnostics *_diagnostics;
    BrumEmulatorReadyHandler _onReady;
    unsigned _pixelFormat;
    brum::InputState _input;
    std::array<brum::InputState, 4> _extraPortInputs;
    NSInteger _virtualPadPort;
    brum::ScreenManager _screenManager;
    std::vector<brum::Placement> _screenPlacements;
    brum::Viewport _singleViewport;
    unsigned _screenProfileWidth;
    unsigned _screenProfileHeight;
    double _contentAspectRatio;
    BOOL _layoutManuallyChosen;
    NSMutableArray<CALayer *> *_screenLayers;
    CALayer *_singleScreenLayer;
    UIView *_directionControl;
    UIView *_actionControl;
    NSMutableArray<UIButton *> *_virtualButtons;
    UIImpactFeedbackGenerator *_virtualFeedback;
    BOOL _virtualHapticsEnabled;
    BOOL _performanceHUDEnabled;
    CFTimeInterval _metricsStartedAt;
    CFTimeInterval _coreRunSeconds;
    CFTimeInterval _hostVideoSeconds;
    NSUInteger _measuredFrames;
    brum::FrameCadence _frameCadence;
    BOOL _paused;
    BOOL _explicitlyPaused;
    BOOL _backgrounded;
    BOOL _audioInterrupted;
    int16_t _pointerX;
    int16_t _pointerY;
    BOOL _pointerPressed;
    int _pointerLatchFrames;
    unsigned _frameWidth;
    unsigned _frameHeight;
    CADisplayLink *_displayLink;
    UIImageView *_screen;
    UILabel *_statusLabel;
    UIButton *_brumMenuButton;
    UIButton *_exitFallbackButton;
    UIImageView *_fastForwardBadge;
    NSUInteger _statusToastToken;
    UIView *_touchReticle;
    NSMutableArray<UIView *> *_padOverlayViews;
    BOOL _controlsHidden;
    BOOL _manualControlsHidden;
    BOOL _autoHideWithController;
    BrumVirtualStick *_virtualStick;
    BrumVirtualStick *_rightVirtualStick;
    UIView *_digitalPad;
    BrumVirtualDPad *_primaryDPad;
    BrumVirtualDPad *_secondaryDPad;
    UIButton *_padModeButton;
    BOOL _dpadMode;
    uint8_t _n64CButtonMask;
    NSURL *_romURL;
    NSData *_romData;
    std::vector<brum_retro_memory_descriptor> _memoryDescriptors;
    std::unique_ptr<brum::RetroAchievementsRuntime> _raRuntime;
    std::unique_ptr<brum::pokedex::FireRedCaptureTracker> _pokedexTracker;
    BrumAchievementOverlayPresenter *_achievementOverlay;
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
    CAEAGLLayer *_hardwareDisplayLayer;
    GLuint _hardwareDisplayFramebuffer;
    GLuint _hardwareDisplayRenderbuffer;
    GLint _hardwareDisplayWidth;
    GLint _hardwareDisplayHeight;
    BOOL _hardwareDisplayReady;
    BOOL _hardwarePending;
    BOOL _hardwareInitialized;
    uint64_t _videoCallbackCount;
    uint64_t _videoNullCount;
    uint64_t _nonBlackFrameCount;
    uint64_t _hwReadbackErrors;
    brum_retro_system_av_info _pendingAVInfo;
    BOOL _hasPendingAVInfo;
    CGColorSpaceRef _rgbColorSpace;
    std::vector<uint8_t> _hwReadbackRGBA;
    CALayer *_scanlineOverlayLayer;
}

- (void)closeEmulator;
- (void)stopCore;
- (void)persistSaveRAM;
- (void)updateDisplayModeButton;
- (void)showBrumQuickMenu;
- (void)refreshVideoFilterPresentation;
- (void)applyVirtualControlsStyle;
- (void)showStateMenu;
- (void)saveStateAtSlot:(NSInteger)slot;
- (void)loadStateAtSlot:(NSInteger)slot;
- (void)showStateStatus:(NSString *)text error:(BOOL)error;
- (BOOL)startAudio:(double)sampleRate error:(NSError **)error;
- (void)applyPendingAVInfo;
- (void)configureDisplayCadence:(double)framesPerSecond;
- (BOOL)ensureHardwareDisplayDrawable;
- (BOOL)presentHardwareFrameDirectWidth:(unsigned)width height:(unsigned)height;
- (void)presentFrame:(CGImageRef)image;
- (void)layoutScreens;
- (brum::Rect)availableGameRect;
- (void)showScreenMenu;
- (void)toggleControlsVisibility;
- (void)applyVirtualControlsVisibility;
- (void)physicalControllerChanged:(NSNotification *)notification;
- (void)syncPhysicalControllerUIWithToast:(BOOL)showToast;
- (void)updatePauseState;
- (BOOL)configureHardware:(brum_retro_hw_render_callback *)callback;
- (BOOL)initializeHardware:(NSError **)error;
- (void)destroyHardware;
- (void)handleCoreShutdown;
- (void)captureDiagnosticsMetrics;
- (void)showStartupFailure;
- (void)shareDiagnostics;
- (void)reportAudioFailure:(NSString *)message;
- (BrumVirtualStick *)analogPad;
- (BrumVirtualDPad *)directionPad;
- (void)dpadChanged:(BrumVirtualDPad *)pad;
- (void)dpadTouchDown:(BrumVirtualDPad *)pad;
- (UIStackView *)n64ActionPad;
- (UIStackView *)segaActionPad;
- (UIStackView *)profileActionPad:(brum::VirtualFace)face;
- (UIStackView *)faceRows:(NSArray<NSArray<UIButton *> *> *)rows width:(CGFloat)width;
- (void)virtualStickChanged:(BrumVirtualStick *)stick;
- (void)rightVirtualStickChanged:(BrumVirtualStick *)stick;
- (void)toggleAnalogPadMode;
- (void)updateN64CButtons;
- (void)setVirtualButton:(UIButton *)button pressed:(BOOL)pressed;
- (void)releaseVirtualControls;
@end

static void *BrumLoadSymbol(void *handle, const char *name) {
    dlerror();
    return dlsym(handle, name);
}

static uint32_t BrumRAConsoleIDForSystem(NSString *systemID) {
    if (!systemID.length) return 0;
    NSString *lower = systemID.lowercaseString;
    if ([lower isEqualToString:@"md"]) return 1;
    if ([lower isEqualToString:@"n64"]) return 2;
    if ([lower isEqualToString:@"sfc"]) return 3;
    if ([lower isEqualToString:@"gb"]) return 4;
    if ([lower isEqualToString:@"gba"]) return 5;
    if ([lower isEqualToString:@"gbc"]) return 6;
    if ([lower isEqualToString:@"nes"]) return 7;
    if ([lower isEqualToString:@"pce"]) return 8;
    if ([lower isEqualToString:@"segacd"]) return 9;
    if ([lower isEqualToString:@"32x"]) return 10;
    if ([lower isEqualToString:@"sms"]) return 11;
    if ([lower isEqualToString:@"psx"]) return 12;
    if ([lower isEqualToString:@"lynx"]) return 13;
    if ([lower isEqualToString:@"gg"]) return 15;
    if ([lower isEqualToString:@"nds"]) return 18;
    if ([lower isEqualToString:@"neogeo"] || [lower isEqualToString:@"arcade"]) return 27;
    if ([lower isEqualToString:@"saturn"]) return 39;
    if ([lower isEqualToString:@"dreamcast"]) return 40;
    if ([lower isEqualToString:@"psp"]) return 41;
    if ([lower isEqualToString:@"a2600"]) return 25;
    if ([lower isEqualToString:@"ws"] || [lower isEqualToString:@"wsc"]) return 53;
    // Nintendo 3DS has no official RetroAchievements runtime memory support.
    if ([lower isEqualToString:@"3ds"]) return 0;
    return 0;
}

static void BrumCoreLog(int level, const char *format, ...) {
    if (!format || level < 2) return;
    char message[2048];
    va_list arguments; va_start(arguments, format);
    vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);
    NSLog(@"BRUM Core [%d] %s", level, message);
    BrumLibretroViewController *host = BrumCurrentHost;
    if (host) [host->_diagnostics recordMessage:[NSString stringWithUTF8String:message] ?: @"Mensagem do núcleo com codificação inválida." level:level];
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
        // Advertised maxima are capacity hints, not the currently rendered
        // dimensions. Azahar advertises 7200x4800 for optional future layouts
        // while its native frame is 400x480. Allocation checks belong to the
        // actual video callback, not this metadata contract.
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
            if (!BrumValidGeometry((const brum_retro_game_geometry *)data)) return false;
            host->_contentAspectRatio = ((const brum_retro_game_geometry *)data)->aspect_ratio;
            host->_screenProfileWidth = 0;
            return true;
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
        case BRUM_RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION:
            if (!data) return false;
            *(unsigned *)data = 1;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_MESSAGE_EXT: {
            const brum_retro_message_ext *message = (const brum_retro_message_ext *)data;
            if (!message || !message->msg) return false;
            NSString *text = [NSString stringWithUTF8String:message->msg] ?: @"Mensagem do núcleo com codificação inválida.";
            [host->_diagnostics recordMessage:text level:message->level];
            if (message->target != 1) { // RETRO_MESSAGE_TARGET_LOG is not an OSD notification.
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!host->_stopped && !host->_shutdownRequested) [host showStateStatus:text error:NO];
                });
            }
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
        case BRUM_RETRO_ENVIRONMENT_GET_JIT_CAPABLE:
            if (data) *(bool *)data = false;
            return true;
        case BRUM_RETRO_ENVIRONMENT_SET_MEMORY_MAPS: {
            const brum_retro_memory_map *map = (const brum_retro_memory_map *)data;
            host->_memoryDescriptors.clear();
            if (map && map->descriptors && map->num_descriptors > 0 && map->num_descriptors <= 4096) {
                host->_memoryDescriptors.assign(map->descriptors, map->descriptors + map->num_descriptors);
            }
            return true;
        }
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
                [host->_diagnostics recordMessage:text ?: @"Mensagem inválida do núcleo." level:2];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!host->_stopped && !host->_shutdownRequested && text.length) [host showStateStatus:text error:NO];
                });
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
    if (!host || host->_suppressVideo) return;
    ++host->_videoCallbackCount;
    if (!data || !width || !height) {
        ++host->_videoNullCount;
        return;
    }
    const CFTimeInterval started = host->_performanceHUDEnabled ? CACurrentMediaTime() : 0;
    if (width > 4096 || height > 4096) return;
    if (data == BrumHardwareFrameBuffer) {
        if (!host->_hardwareInitialized) return;
        if (width > (unsigned)host->_hardwareSurfaceSize || height > (unsigned)host->_hardwareSurfaceSize) {
            if (host->_videoCallbackCount <= 3) {
                [host->_diagnostics recordMessage:[NSString stringWithFormat:@"Quadro HW (%ux%u) excedeu a superfície GL (%dpx).", width, height, (int)host->_hardwareSurfaceSize] level:2];
            }
            return;
        }
        host->_frameWidth = width;
        host->_frameHeight = height;
        if ([host presentHardwareFrameDirectWidth:width height:height]) {
            if (host->_performanceHUDEnabled) host->_hostVideoSeconds += CACurrentMediaTime() - started;
            return;
        }
    } else {
        const size_t bytesPerPixel = host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_XRGB8888 ? 4 : 2;
        if (pitch < (size_t)width * bytesPerPixel || pitch > SIZE_MAX / height) return;
        host->_frameWidth = width;
        host->_frameHeight = height;
    }
    const NSUInteger byteCount = (NSUInteger)width * height * 4;
    uint32_t *target = (uint32_t *)malloc(byteCount);
    if (!target) return;
    NSData *pixels = [NSData dataWithBytesNoCopy:target length:byteCount freeWhenDone:YES];
    if (data == BrumHardwareFrameBuffer) {
        while (glGetError() != GL_NO_ERROR) {}
        GLint prevFramebuffer = 0;
        GLint prevReadFramebuffer = 0, prevDrawFramebuffer = 0, prevReadBuffer = GL_COLOR_ATTACHMENT0;
        GLint prevPackAlignment = 4, prevPackRowLength = 0, prevPackSkipRows = 0, prevPackSkipPixels = 0;
        GLint prevPackBuffer = 0;
        const GLboolean hadScissor = glIsEnabled(GL_SCISSOR_TEST);
        const BOOL isES3 = host->_hardwareContext && host->_hardwareContext.API >= kEAGLRenderingAPIOpenGLES3;
        glGetIntegerv(GL_PACK_ALIGNMENT, &prevPackAlignment);
        if (isES3) {
            glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prevReadFramebuffer);
            glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &prevDrawFramebuffer);
            glGetIntegerv(GL_READ_BUFFER, &prevReadBuffer);
            glGetIntegerv(GL_PACK_ROW_LENGTH, &prevPackRowLength);
            glGetIntegerv(GL_PACK_SKIP_ROWS, &prevPackSkipRows);
            glGetIntegerv(GL_PACK_SKIP_PIXELS, &prevPackSkipPixels);
            glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &prevPackBuffer);
            if (prevPackBuffer != 0) glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
            glPixelStorei(GL_PACK_ROW_LENGTH, 0);
            glPixelStorei(GL_PACK_SKIP_ROWS, 0);
            glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
        } else {
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFramebuffer);
        }
        if (hadScissor) glDisable(GL_SCISSOR_TEST);
        if (isES3) {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, host->_hardwareFramebuffer);
            glReadBuffer(GL_COLOR_ATTACHMENT0);
        } else {
            glBindFramebuffer(GL_FRAMEBUFFER, host->_hardwareFramebuffer);
        }
        host->_hwReadbackRGBA.resize(byteCount);
        glPixelStorei(GL_PACK_ALIGNMENT, 1);
        glReadPixels(0, 0, (GLsizei)width, (GLsizei)height, GL_RGBA, GL_UNSIGNED_BYTE, host->_hwReadbackRGBA.data());
        const GLenum readErr = glGetError();
        glPixelStorei(GL_PACK_ALIGNMENT, prevPackAlignment);
        if (isES3) {
            glPixelStorei(GL_PACK_ROW_LENGTH, prevPackRowLength);
            glPixelStorei(GL_PACK_SKIP_ROWS, prevPackSkipRows);
            glPixelStorei(GL_PACK_SKIP_PIXELS, prevPackSkipPixels);
            if (prevPackBuffer != 0) glBindBuffer(GL_PIXEL_PACK_BUFFER, (GLuint)prevPackBuffer);
            glReadBuffer((GLenum)prevReadBuffer);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)prevReadFramebuffer);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)prevDrawFramebuffer);
        } else {
            glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)prevFramebuffer);
        }
        if (hadScissor) glEnable(GL_SCISSOR_TEST);
        if (readErr != GL_NO_ERROR) {
            ++host->_hwReadbackErrors;
            NSLog(@"BRUM Core GL readback error=0x%X (%ux%u)", readErr, width, height);
            return;
        }
        bool hasVisiblePixel = false;
        const uint8_t *source = host->_hwReadbackRGBA.data();
        for (unsigned y = 0; y < height; y++) {
            unsigned sourceY = host->_hardwareCallback.bottom_left_origin ? height - 1 - y : y;
            const uint8_t *srcRow = source + (size_t)sourceY * width * 4;
            uint32_t *dstRow = target + (size_t)y * width;
            for (unsigned x = 0; x < width; x++) {
                const size_t offset = (size_t)x * 4;
                const uint32_t px = ((uint32_t)srcRow[offset] << 16) |
                    ((uint32_t)srcRow[offset + 1] << 8) | srcRow[offset + 2];
                dstRow[x] = px;
                if (px != 0) hasVisiblePixel = true;
            }
        }
        if (hasVisiblePixel) ++host->_nonBlackFrameCount;
    } else if (host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_XRGB8888) {
        for (unsigned y = 0; y < height; y++) {
            const uint32_t *source = (const uint32_t *)((const uint8_t *)data + y * pitch);
            memcpy(target + (size_t)y * width, source, (size_t)width * 4);
        }
    } else {
        static uint8_t lut5[32];
        static uint8_t lut6[64];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            for (unsigned i = 0; i < 32; ++i) lut5[i] = (uint8_t)((i << 3) | (i >> 2));
            for (unsigned i = 0; i < 64; ++i) lut6[i] = (uint8_t)((i << 2) | (i >> 4));
        });
        const BOOL is565 = host->_pixelFormat == BRUM_RETRO_PIXEL_FORMAT_RGB565;
        for (unsigned y = 0; y < height; y++) {
            const uint16_t *source = (const uint16_t *)((const uint8_t *)data + y * pitch);
            uint32_t *dstRow = target + (size_t)y * width;
            if (is565) {
                for (unsigned x = 0; x < width; x++) {
                    const uint16_t value = source[x];
                    dstRow[x] = ((uint32_t)lut5[(value >> 11) & 31] << 16) |
                                ((uint32_t)lut6[(value >> 5) & 63] << 8) |
                                (uint32_t)lut5[value & 31];
                }
            } else {
                for (unsigned x = 0; x < width; x++) {
                    const uint16_t value = source[x];
                    dstRow[x] = ((uint32_t)lut5[(value >> 10) & 31] << 16) |
                                ((uint32_t)lut5[(value >> 5) & 31] << 8) |
                                (uint32_t)lut5[value & 31];
                }
            }
        }
    }
    NSString *activeFilter = host.videoFilterMode ?: @"none";
    if ([activeFilter isEqualToString:@"cas_sharpen"]) {
        brum_shaders::applyCasSharpen(target, (int)width, (int)height, 70);
    } else if ([activeFilter isEqualToString:@"edge_upscale_2x"] || [activeFilter isEqualToString:@"sharp_bilinear"]) {
        thread_local std::vector<uint32_t> shaderOut;
        int outW = 0;
        int outH = 0;
        if ([activeFilter isEqualToString:@"edge_upscale_2x"]) {
            brum_shaders::applyEdgeUpscale2x(target, (int)width, (int)height, shaderOut, outW, outH);
        } else {
            brum_shaders::applySharpBilinearPrescale(target, (int)width, (int)height, shaderOut, outW, outH);
        }
        if (outW > 0 && outH > 0 && shaderOut.size() == (size_t)outW * (size_t)outH) {
            pixels = [NSData dataWithBytes:shaderOut.data() length:(NSUInteger)outW * (NSUInteger)outH * 4];
            width = (unsigned)outW;
            height = (unsigned)outH;
        }
    }
    CGColorSpaceRef ownedSpace = host->_rgbColorSpace ? NULL : CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef colorSpace = host->_rgbColorSpace ?: ownedSpace;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGBitmapInfo bitmap = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
    CGImageRef image = CGImageCreate(width, height, 8, 32, (size_t)width * 4, colorSpace, bitmap, provider, NULL, false, kCGRenderingIntentDefault);
    if (image) {
        [host presentFrame:image];
        ++host->_presentedFrames;
        CGImageRelease(image);
    }
    CGDataProviderRelease(provider);
    if (ownedSpace) CGColorSpaceRelease(ownedSpace);
    if (host->_performanceHUDEnabled) host->_hostVideoSeconds += CACurrentMediaTime() - started;
}

static void BrumPushAudio(const int16_t *data, size_t frames) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || host->_fastForwardEnabled || !host->_audioRing || !data || !frames || frames > SIZE_MAX / 2) return;
    os_unfair_lock_lock(&host->_audioLock);
    const size_t samples = frames * 2;
    host->_audioSamplesProduced += samples;
    for (size_t index = 0; index < samples; index++) {
        if (host->_audioCount == host->_audioCapacity) {
            host->_audioRead = (host->_audioRead + 1) % host->_audioCapacity;
            host->_audioCount--;
            ++host->_audioSamplesDropped;
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

static NSArray<GCController *> *BrumActiveControllers(void) {
    NSMutableArray<GCController *> *active = [NSMutableArray array];
    for (GCController *controller in GCController.controllers) {
        if (!controller.isSnapshot) [active addObject:controller];
    }
    return active;
}

static void BrumApplyControllerToInput(GCController *controller, NSString *systemID, brum::InputState &target) {
    GCExtendedGamepad *pad = controller.extendedGamepad;
    if (!pad) {
        GCMicroGamepad *micro = controller.microGamepad;
        if (micro) {
            target.set(brum::InputSource::controller, 0, micro.buttonA.isPressed);
            target.set(brum::InputSource::controller, 1, micro.buttonX.isPressed);
            target.set(brum::InputSource::controller, 3, micro.buttonMenu.isPressed);
            target.set(brum::InputSource::controller, 4, micro.dpad.up.isPressed);
            target.set(brum::InputSource::controller, 5, micro.dpad.down.isPressed);
            target.set(brum::InputSource::controller, 6, micro.dpad.left.isPressed);
            target.set(brum::InputSource::controller, 7, micro.dpad.right.isPressed);
        }
        return;
    }
    NSArray<GCControllerButtonInput *> *buttons = @[pad.buttonB, pad.buttonY, pad.buttonOptions ?: pad.buttonMenu, pad.buttonMenu,
        pad.dpad.up, pad.dpad.down, pad.dpad.left, pad.dpad.right, pad.buttonA, pad.buttonX,
        pad.leftShoulder, pad.rightShoulder, pad.leftTrigger, pad.rightTrigger];
    for (NSUInteger i = 0; i < buttons.count; i++) target.set(brum::InputSource::controller, (unsigned)i, buttons[i].isPressed);
    target.set(brum::InputSource::controller, 2, pad.buttonOptions.isPressed);
    target.set(brum::InputSource::controller, 12, pad.leftTrigger.isPressed || pad.leftTrigger.value > 0.25f);
    target.set(brum::InputSource::controller, 13, pad.rightTrigger.isPressed || pad.rightTrigger.value > 0.25f);
    if ([systemID isEqualToString:@"psx"] ||
        [systemID isEqualToString:@"psp"] ||
        [systemID isEqualToString:@"dreamcast"] ||
        [@[@"md", @"segacd", @"32x"] containsObject:systemID]) {
        target.set(brum::InputSource::controller, 0, pad.buttonA.isPressed);
        target.set(brum::InputSource::controller, 8, pad.buttonB.isPressed);
        target.set(brum::InputSource::controller, 1, pad.buttonX.isPressed);
        target.set(brum::InputSource::controller, 9, pad.buttonY.isPressed);
    } else if ([systemID isEqualToString:@"n64"]) {
        // Mupen's default map reads Libretro B/Y as N64 A/B.
        target.set(brum::InputSource::controller, 0, pad.buttonA.isPressed);
        target.set(brum::InputSource::controller, 1, pad.buttonB.isPressed);
    }
    target.setAxis(brum::InputSource::controller, 0, 0, pad.leftThumbstick.xAxis.value);
    target.setAxis(brum::InputSource::controller, 0, 1, -pad.leftThumbstick.yAxis.value);
    // This pinned Mupen revision reverses right-stick X when decoding C buttons.
    target.setAxis(brum::InputSource::controller, 1, 0,
                   [systemID isEqualToString:@"n64"] ? -pad.rightThumbstick.xAxis.value : pad.rightThumbstick.xAxis.value);
    target.setAxis(brum::InputSource::controller, 1, 1, -pad.rightThumbstick.yAxis.value);
    target.set(brum::InputSource::controller, 14, pad.leftThumbstickButton.isPressed);
    target.set(brum::InputSource::controller, 15, pad.rightThumbstickButton.isPressed);
}

static void BrumInputPoll(void) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host) return;
    host->_input.release(brum::InputSource::controller);
    for (auto &extra : host->_extraPortInputs) extra.clear();
    NSArray<GCController *> *controllers = BrumActiveControllers();
    const NSInteger vPort = (host->_virtualPadPort >= 0 && host->_virtualPadPort < 4) ? host->_virtualPadPort : 0;
    for (NSUInteger idx = 0; idx < controllers.count && idx < 4; idx++) {
        GCController *controller = controllers[idx];
        if (vPort == 0 && idx == 0) {
            BrumApplyControllerToInput(controller, host->_emulatedSystemID, host->_input);
        } else {
            BrumApplyControllerToInput(controller, host->_emulatedSystemID, host->_extraPortInputs[idx]);
        }
    }
}

static int16_t BrumInputState(unsigned port, unsigned device, unsigned index, unsigned identifier) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || port >= 4 || host->_paused) return 0;
    const unsigned vPort = (host->_virtualPadPort >= 0 && host->_virtualPadPort < 4) ? (unsigned)host->_virtualPadPort : 0;
    if (device == BRUM_RETRO_DEVICE_ANALOG) {
        if (vPort == 0 && port == 0) return host->_input.analog(index, identifier);
        if (port == vPort) {
            const int16_t v = host->_input.analog(index, identifier);
            const int16_t c = host->_extraPortInputs[port].analog(index, identifier);
            return abs(v) >= abs(c) ? v : c;
        }
        return host->_extraPortInputs[port].analog(index, identifier);
    }
    if (index != 0) return 0;
    if (device == BRUM_RETRO_DEVICE_POINTER) {
        if (port != 0) return 0;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_X) return host->_pointerX;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_Y) return host->_pointerY;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_PRESSED) return (host->_pointerPressed || host->_pointerLatchFrames > 0) ? 1 : 0;
        if (identifier == BRUM_RETRO_DEVICE_ID_POINTER_COUNT) return (host->_pointerPressed || host->_pointerLatchFrames > 0) ? 1 : 0;
        return 0;
    }
    if (device != BRUM_RETRO_DEVICE_JOYPAD || identifier > 15) return 0;
    if (vPort == 0 && port == 0) return host->_input.pressed(identifier) ? 1 : 0;
    if (port == vPort) {
        return (host->_input.pressed(identifier) || host->_extraPortInputs[port].pressed(identifier)) ? 1 : 0;
    }
    return host->_extraPortInputs[port].pressed(identifier) ? 1 : 0;
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
    host->_audioSamplesConsumed += written;
    host->_audioSamplesMissing += requested - written;
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
                       onReady:(BrumEmulatorReadyHandler)onReady
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
    _onReady = [onReady copy];
    _onExit = [onExit copy];
    NSURL *support = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *report = [[support URLByAppendingPathComponent:@"IntegratedEmulator/Diagnostics" isDirectory:YES] URLByAppendingPathComponent:@"last-session.json"];
    _diagnostics = [[BrumCoreDiagnostics alloc] initWithContext:@{
        @"systemID": _emulatedSystemID, @"coreID": _coreID, @"coreVersion": _coreVersion,
        @"contentSHA256": _contentSHA256, @"format": _romURL.pathExtension.lowercaseString,
        @"appVersion": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
        @"appBuild": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?",
        @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString,
        @"cpuCount": @(NSProcessInfo.processInfo.activeProcessorCount),
        @"physicalMemoryBytes": @(NSProcessInfo.processInfo.physicalMemory)
    } reportURL:report redactedPaths:@[_romURL.path, NSBundle.mainBundle.bundlePath, NSHomeDirectory()]];
    _variables = [NSMutableDictionary dictionary];
    // Exact option/value from pinned libretro PPSSPP. Sideloadly provides no JIT.
    _variables[@"ppsspp_cpu_core"] = @"IR jit";
    _variables[@"ppsspp_internal_resolution"] = @"480x272";
    _variables[@"ppsspp_rendering_mode"] = @"buffered";
    _variables[@"ppsspp_auto_frameskip"] = @"enabled";
    _variables[@"ppsspp_frameskip"] = @"1";
    _variables[@"ppsspp_fast_memory"] = @"disabled";
    _variables[@"ppsspp_audio_latency"] = @"medium";
    _variables[@"ppsspp_gpu_hardware_transform"] = @"enabled";
    _variables[@"ppsspp_block_transfer_gpu"] = @"enabled";
    _variables[@"ppsspp_vertex_cache"] = @"enabled";
    _variables[@"ppsspp_unsafe_func_replacements"] = @"enabled";
    _variables[@"ppsspp_io_timing_method"] = @"Fast";
    _variables[@"ppsspp_texture_anisotropic_filtering"] = @"off";
    _variables[@"ppsspp_texture_scaling_level"] = @"1";
    _variables[@"system_core_override"] = @"Automatic";
    _variables[@"system_gb_bios_enable"] = @"ON";
    _variables[@"system_gba_bios_enable"] = @"ON";
    _variables[@"system_nds_bios_enable"] = @"ON";
    _variables[@"citra_graphics_api"] = @"Software";
    _variables[@"citra_use_cpu_jit"] = @"disabled";
    _variables[@"citra_layout_option"] = @"default";
    _variables[@"citra_resolution_factor"] = @"1";
    _variables[@"citra_enable_touch_touchscreen"] = @"enabled";
    _variables[@"citra_enable_mouse_touchscreen"] = @"disabled";
    // Keep the pinned WonderSwan X/Y cursor mapping stable for its two
    // separate virtual directional clusters.
    _variables[@"wswan_rotate_keymap"] = @"disabled";
    _videoFilterMode = @"none";
    _screenLayers = [NSMutableArray array];
    _pixelFormat = BRUM_RETRO_PIXEL_FORMAT_0RGB1555;
    // FIT is the safe default; cropping is an explicit user choice.
    _screenFillsDisplay = NO;
    _screenFillsDisplay = [NSUserDefaults.standardUserDefaults boolForKey:@"BrumDefaultScreenFillEnabled"];
    _autoHideWithController = [NSUserDefaults.standardUserDefaults boolForKey:@"BrumAutoHidePadWithController"];
    _audioLock = OS_UNFAIR_LOCK_INIT;
    _rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    _audioCapacity = 262144;
    _audioRing = (int16_t *)calloc(_audioCapacity, sizeof(int16_t));
    // PSP uses 1024 for 1x/2x (up to 960x544); loadCore scales up to 2048 if higher res is requested.
    _hardwareSurfaceSize = [_emulatedSystemID isEqualToString:@"psp"] ? 1024 : 2048;
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
    }
    if (_startupError) [_diagnostics recordFailure:_startupError.localizedDescription];
    return self;
}

- (BOOL)prepareDirectories:(NSError **)error {
    NSURL *support = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:error];
    if (!support) return NO;
    NSURL *root = [support URLByAppendingPathComponent:@"IntegratedEmulator" isDirectory:YES];
    NSURL *system = [root URLByAppendingPathComponent:@"System" isDirectory:YES];
    if ([_emulatedSystemID isEqualToString:@"psp"]) {
        // A prior experimental IPA may have installed the old Japanese font.
        // Keep that tree intact and use this release's separate asset directory.
        system = [system URLByAppendingPathComponent:@"psp-7b4ddb-ume77c1e965-v1" isDirectory:YES];
    }
    NSURL *savesRoot = [root URLByAppendingPathComponent:@"Saves" isDirectory:YES];
    NSURL *saves = [savesRoot URLByAppendingPathComponent:_emulatedSystemID isDirectory:YES];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:system withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:saves withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    _systemDirectory = system.path;
    _saveDirectory = saves.path;
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath ?: NSBundle.mainBundle.bundlePath;
    NSURL *bundledAssets = [[NSURL fileURLWithPath:frameworks isDirectory:YES] URLByAppendingPathComponent:@"CoreAssets" isDirectory:YES];
    _coreAssetsDirectory = bundledAssets.path;

    if ([_emulatedSystemID isEqualToString:@"psp"]) {
        for (NSString *asset in @[@"PPSSPP/flash0/font/ltn0.pgf", @"PPSSPP/ppge_atlas.zim"]) {
            NSNumber *size = nil;
            NSURL *file = [bundledAssets URLByAppendingPathComponent:asset];
            if (![file getResourceValue:&size forKey:NSURLFileSizeKey error:nil] || size.unsignedLongLongValue == 0) {
                if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:19 userInfo:@{NSLocalizedDescriptionKey: @"Os recursos do PPSSPP estão ausentes ou incompletos nesta instalação. Reinstale o IPA completo. A ROM e os saves foram preservados."}];
                return NO;
            }
        }
    }

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

    // Azahar looks for user-supplied keys in Saves/3ds/Azahar/sysdata.
    if ([_emulatedSystemID isEqualToString:@"3ds"]) {
        NSURL *sysdata = [[saves URLByAppendingPathComponent:@"Azahar" isDirectory:YES] URLByAppendingPathComponent:@"sysdata" isDirectory:YES];
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
    [_diagnostics enterStage:@"load_library"];
    NSString *frameworks = NSBundle.mainBundle.privateFrameworksPath ?: NSBundle.mainBundle.bundlePath;
    NSString *path = [frameworks stringByAppendingPathComponent:_coreLibraryName];
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path];
    dlerror();
    _coreHandle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!_coreHandle) {
        const char *reason = dlerror();
        if (reason) [_diagnostics recordMessage:[NSString stringWithUTF8String:reason] ?: @"Falha do carregador nativo." level:3];
        NSString *message = exists
            ? [NSString stringWithFormat:@"O núcleo %@ está no aplicativo, mas o iOS não conseguiu carregá-lo. O relatório contém o erro de assinatura, dependência ou arquitetura informado pelo sistema.", _coreDisplayName]
            : [NSString stringWithFormat:@"O núcleo interno %@ não está presente neste IPA.", _coreDisplayName];
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
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
    if (!supported || callback->version_major > 3 || (callback->version_major == 3 && callback->version_minor > 0)) {
        [_diagnostics recordMessage:[NSString stringWithFormat:@"API gráfica recusada: contexto %d, versão %u.%u; este host fornece OpenGL ES até 3.0.", callback->context_type, callback->version_major, callback->version_minor] level:3];
        return NO;
    }
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
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES3;
    _hardwareContext = [[EAGLContext alloc] initWithAPI:api];
    if (!_hardwareContext && _hardwareCallback.context_type == BRUM_RETRO_HW_CONTEXT_OPENGLES2) {
        api = kEAGLRenderingAPIOpenGLES2;
        _hardwareContext = [[EAGLContext alloc] initWithAPI:api];
    }
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
    glViewport(0, 0, _hardwareSurfaceSize, _hardwareSurfaceSize);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    _hardwareInitialized = YES;
    if (api >= kEAGLRenderingAPIOpenGLES3 && _screen.layer) {
        _hardwareDisplayLayer = [CAEAGLLayer layer];
        _hardwareDisplayLayer.opaque = YES;
        _hardwareDisplayLayer.contentsScale = MIN(UIScreen.mainScreen.scale, 2.0);
        _hardwareDisplayLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking: @NO,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        };
        _hardwareDisplayLayer.hidden = YES;
        if (_singleScreenLayer) {
            [_screen.layer insertSublayer:_hardwareDisplayLayer above:_singleScreenLayer];
        } else {
            [_screen.layer addSublayer:_hardwareDisplayLayer];
        }
        glGenFramebuffers(1, &_hardwareDisplayFramebuffer);
        glGenRenderbuffers(1, &_hardwareDisplayRenderbuffer);
    }
    const char *glVendor = (const char *)glGetString(GL_VENDOR);
    const char *glRenderer = (const char *)glGetString(GL_RENDERER);
    const char *glVersion = (const char *)glGetString(GL_VERSION);
    [_diagnostics recordMessage:[NSString stringWithFormat:@"GL HW pronto (%@, FBO %dpx): %s | %s | %s",
        api == kEAGLRenderingAPIOpenGLES3 ? @"GLES3" : @"GLES2",
        (int)_hardwareSurfaceSize,
        glVendor ?: "?", glRenderer ?: "?", glVersion ?: "?"] level:0];
    if (_hardwareCallback.context_reset) _hardwareCallback.context_reset();
    glBindFramebuffer(GL_FRAMEBUFFER, _hardwareFramebuffer);
    return YES;
}

- (void)destroyHardware {
    if (_hardwareContext) [EAGLContext setCurrentContext:_hardwareContext];
    if (_hardwareInitialized && _hardwareCallback.context_destroy) _hardwareCallback.context_destroy();
    if (_hardwareDisplayRenderbuffer) {
        glBindRenderbuffer(GL_RENDERBUFFER, _hardwareDisplayRenderbuffer);
        if (_hardwareContext) [_hardwareContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:nil];
        glDeleteRenderbuffers(1, &_hardwareDisplayRenderbuffer);
    }
    if (_hardwareDisplayFramebuffer) glDeleteFramebuffers(1, &_hardwareDisplayFramebuffer);
    if (_hardwareDisplayLayer) {
        [_hardwareDisplayLayer removeFromSuperlayer];
        _hardwareDisplayLayer = nil;
    }
    _hardwareDisplayFramebuffer = 0;
    _hardwareDisplayRenderbuffer = 0;
    _hardwareDisplayWidth = 0;
    _hardwareDisplayHeight = 0;
    _hardwareDisplayReady = NO;
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

- (void)applyInitialCoreVariablesAndSurfaceSize {
    if (_initialCoreVariables.count > 0) {
        for (NSString *key in _initialCoreVariables) {
            NSString *val = _initialCoreVariables[key];
            if (key.length && val.length) {
                _variables[key] = val;
            }
        }
    }
    NSString *pspRes = _variables[@"ppsspp_internal_resolution"];
    if (pspRes.length) {
        NSArray<NSString *> *parts = [pspRes componentsSeparatedByString:@"x"];
        if (parts.count == 2) {
            NSInteger w = MAX(parts[0].integerValue, parts[1].integerValue);
            if (w > 1024 && _hardwareSurfaceSize < 2048) _hardwareSurfaceSize = 2048;
        }
    }
    NSString *citraFactor = _variables[@"citra_resolution_factor"];
    if (citraFactor.integerValue > 2 && _hardwareSurfaceSize < 2048) {
        _hardwareSurfaceSize = 2048;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    [self buildInterface];
    _achievementOverlay = [[BrumAchievementOverlayPresenter alloc] initWithHostView:self.view];
    if (!_startupError && !_coreHandle) {
        [self applyInitialCoreVariablesAndSurfaceSize];
        NSError *loadError = nil;
        if (![self loadCore:&loadError]) _startupError = loadError;
    }
    if (_startupError) {
        [_diagnostics recordFailure:_startupError.localizedDescription];
        _exitFallbackButton.hidden = NO;
        _statusLabel.text = _startupError.localizedDescription;
        _statusLabel.textColor = UIColor.systemRedColor;
        _statusLabel.hidden = NO;
        _statusLabel.alpha = 1;
        return;
    }
    NSError *error = nil;
    if (![self startCore:&error]) {
        _startupError = error ?: [NSError errorWithDomain:BrumLibretroErrorDomain code:13 userInfo:@{NSLocalizedDescriptionKey: @"Não foi possível iniciar o jogo."}];
        [_diagnostics recordFailure:_startupError.localizedDescription];
        [self stopCore];
        _exitFallbackButton.hidden = NO;
        _statusLabel.text = error.localizedDescription ?: @"Não foi possível iniciar o jogo.";
        _statusLabel.textColor = UIColor.systemRedColor;
        _statusLabel.hidden = NO;
        _statusLabel.alpha = 1;
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(physicalControllerChanged:)
                                                     name:GCControllerDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(physicalControllerChanged:)
                                                     name:GCControllerDidDisconnectNotification
                                                   object:nil];
        [self syncPhysicalControllerUIWithToast:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_startupError) [self showStartupFailure];
}

- (void)captureDiagnosticsMetrics {
    os_unfair_lock_lock(&_audioLock);
    const uint64_t produced = _audioSamplesProduced, consumed = _audioSamplesConsumed;
    const uint64_t dropped = _audioSamplesDropped, missing = _audioSamplesMissing;
    const size_t buffered = _audioCount;
    os_unfair_lock_unlock(&_audioLock);
    NSDictionary *metrics = @{
        @"emulatedFrames": @(_sessionFrames), @"presentedFrames": @(_presentedFrames),
        @"videoCallbackCount": @(_videoCallbackCount), @"videoNullCount": @(_videoNullCount),
        @"nonBlackFrameCount": @(_nonBlackFrameCount), @"hwReadbackErrors": @(_hwReadbackErrors),
        @"audioSamplesProduced": @(produced), @"audioSamplesConsumed": @(consumed),
        @"audioSamplesDropped": @(dropped), @"audioSamplesMissing": @(missing),
        @"audioBufferedSamples": @(buffered), @"audioQueueActive": @(_audioQueue != NULL),
        @"sampleRate": @(_audioSampleRate), @"thermalState": @(NSProcessInfo.processInfo.thermalState)
    };
    [_diagnostics setMetrics:metrics];
}

- (NSString *)diagnosticsReport {
    [self captureDiagnosticsMetrics];
    return _diagnostics.reportText;
}

- (void)reportAudioFailure:(NSString *)message {
    [_diagnostics recordMessage:[@"Host de áudio: " stringByAppendingString:message] level:3];
    [self captureDiagnosticsMetrics];
    [_diagnostics checkpoint];
    [self showStateStatus:message error:YES];
}

- (void)shareDiagnostics {
    if (self.presentedViewController) return;
    const BOOL wasPaused = _explicitlyPaused;
    [self pause];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[self.diagnosticsReport] applicationActivities:nil];
    __weak BrumLibretroViewController *weakSelf = self;
    share.completionWithItemsHandler = ^(__unused UIActivityType activity, __unused BOOL completed, __unused NSArray *items, __unused NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (!wasPaused) [weakSelf resume]; });
    };
    if (share.popoverPresentationController) {
        UIView *anchor = _brumMenuButton ?: self.view;
        share.popoverPresentationController.sourceView = anchor;
        share.popoverPresentationController.sourceRect = anchor.bounds;
    }
    [self presentViewController:share animated:YES completion:nil];
}

- (void)showStartupFailure {
    if (_failurePresented || self.presentedViewController || !self.view.window) return;
    _failurePresented = YES;
    NSString *detail = _diagnostics.failureDetail;
    if (detail.length > 600) detail = [detail substringToIndex:600];
    NSString *message = _startupError.localizedDescription ?: @"O núcleo interrompeu a execução.";
    if (detail.length) message = [message stringByAppendingFormat:@"\n\nAviso do núcleo:\n%@", detail];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Não foi possível executar o jogo" message:message preferredStyle:UIAlertControllerStyleAlert];
    __weak BrumLibretroViewController *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Copiar relatório" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string = weakSelf.diagnosticsReport;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Voltar" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        [weakSelf closeEmulator];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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
    // Do not probe serializeSize() before the first emulated frame: PPSSPP allocates
    // GPU state lazily on frame 1 and dereferences gpu inside DoState().
    const size_t size = (_sessionFrames > 0 && _core.serializeSize) ? _core.serializeSize() : 0;
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
    _frameCadence.reset();
    if (shouldPause) {
        _input.clear();
        _n64CButtonMask = 0;
        [self releaseVirtualControls];
        [_primaryDPad reset];
        [_secondaryDPad reset];
        [_virtualStick reset];
        _virtualStick.enabled = NO;
        [_rightVirtualStick reset];
        _rightVirtualStick.enabled = NO;
        _pointerPressed = NO;
        _pointerLatchFrames = 0;
        _pointerX = 0;
        _pointerY = 0;
        _touchReticle.hidden = YES;
        if (_audioQueue) AudioQueuePause(_audioQueue);
        os_unfair_lock_lock(&_audioLock); _audioRead = 0; _audioWrite = 0; _audioCount = 0; os_unfair_lock_unlock(&_audioLock);
        [self persistSaveRAM];
        return;
    }
    const BOOL isPSP = [_emulatedSystemID isEqualToString:@"psp"];
    _virtualStick.enabled = (isPSP || !_dpadMode) && !_controlsHidden;
    _rightVirtualStick.enabled = YES;
    if (!_audioQueue) return;
    NSError *error = nil;
    if (![AVAudioSession.sharedInstance setActive:YES error:&error]) {
        [self reportAudioFailure:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL: %@", error.localizedDescription]];
        return;
    }
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) [self reportAudioFailure:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL (%d)", (int)status]];
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

- (void)refreshVideoFilterPresentation {
    if (!_screen || !_singleScreenLayer) return;
    NSString *magFilter = ([_videoFilterMode isEqualToString:@"bilinear_subtle"] || [_videoFilterMode isEqualToString:@"sharp_bilinear"]) ? kCAFilterLinear : kCAFilterNearest;
    _screen.layer.magnificationFilter = magFilter;
    _singleScreenLayer.magnificationFilter = magFilter;
    for (CALayer *layer in _screenLayers) layer.magnificationFilter = magFilter;
    if (_scanlineOverlayLayer) {
        [_scanlineOverlayLayer removeFromSuperlayer];
        _scanlineOverlayLayer = nil;
    }
    if ([_videoFilterMode isEqualToString:@"crt_scanlines"] || [_videoFilterMode isEqualToString:@"lcd_grid"]) {
        _scanlineOverlayLayer = [CALayer layer];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), NO, 1.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        if ([_videoFilterMode isEqualToString:@"crt_scanlines"]) {
            [[UIColor colorWithWhite:0 alpha:0.22] setFill];
            CGContextFillRect(ctx, CGRectMake(0, 1, 4, 1));
            CGContextFillRect(ctx, CGRectMake(0, 3, 4, 1));
        } else {
            [[UIColor colorWithWhite:0 alpha:0.16] setFill];
            CGContextFillRect(ctx, CGRectMake(0, 3, 4, 1));
            CGContextFillRect(ctx, CGRectMake(3, 0, 1, 4));
        }
        UIImage *tile = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (tile) {
            _scanlineOverlayLayer.backgroundColor = [UIColor colorWithPatternImage:tile].CGColor;
            _scanlineOverlayLayer.zPosition = 2;
            [_screen.layer addSublayer:_scanlineOverlayLayer];
        }
    }
    [self layoutScreens];
}

- (void)applyVirtualControlsStyle {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id opacityPref = [defaults objectForKey:@"BrumVirtualControlsOpacity"];
    CGFloat alpha = opacityPref ? MIN(1.0, MAX(0.25, [defaults doubleForKey:@"BrumVirtualControlsOpacity"])) : 0.85;
    id scalePref = [defaults objectForKey:@"BrumVirtualControlsScale"];
    CGFloat scale = scalePref ? MIN(1.25, MAX(0.80, [defaults doubleForKey:@"BrumVirtualControlsScale"])) : 1.0;
    for (UIView *view in _padOverlayViews) {
        view.alpha = alpha;
    }
    if (_digitalPad) _digitalPad.alpha = alpha;
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scale, scale);
    if (_directionControl) _directionControl.transform = scaleTransform;
    if (_digitalPad) _digitalPad.transform = scaleTransform;
    if (_actionControl) _actionControl.transform = scaleTransform;
    if (_rightVirtualStick) _rightVirtualStick.transform = scaleTransform;
}

- (void)buildInterface {
    self.view.multipleTouchEnabled = YES;
    _virtualButtons = [NSMutableArray array];
    _padOverlayViews = [NSMutableArray array];
    _virtualFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    id hapticPreference = [NSUserDefaults.standardUserDefaults objectForKey:@"BrumVirtualControlHapticsEnabled"];
    _virtualHapticsEnabled = !hapticPreference || [hapticPreference boolValue];
    if (_virtualHapticsEnabled) [_virtualFeedback prepare];
    _performanceHUDEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"BrumCorePerformanceHUD"];
    _screen = [[UIImageView alloc] init];
    _screen.translatesAutoresizingMaskIntoConstraints = NO;
    _screen.multipleTouchEnabled = YES;
    _screen.backgroundColor = [UIColor colorWithWhite:0.02 alpha:1];
    _screen.layer.magnificationFilter = kCAFilterNearest;
    _screen.clipsToBounds = YES;
    _screen.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *touch = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(screenTouch:)];
    touch.minimumPressDuration = 0;
    touch.allowableMovement = CGFLOAT_MAX;
    touch.cancelsTouchesInView = NO;
    touch.delegate = self;
    [_screen addGestureRecognizer:touch];
    [self.view addSubview:_screen];
    _singleScreenLayer = [CALayer layer];
    _singleScreenLayer.contentsGravity = kCAGravityResize;
    [_screen.layer addSublayer:_singleScreenLayer];

    _touchReticle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    _touchReticle.layer.cornerRadius = 15;
    _touchReticle.layer.borderWidth = 2.0;
    _touchReticle.layer.borderColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:0.92].CGColor;
    _touchReticle.backgroundColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:0.18];
    _touchReticle.userInteractionEnabled = NO;
    _touchReticle.hidden = YES;
    _touchReticle.layer.zPosition = 3;
    [_screen addSubview:_touchReticle];

    _exitFallbackButton = [self controlButton:@"←  SAIR" identifier:-1];
    _exitFallbackButton.accessibilityIdentifier = @"brum-core-exit";
    _exitFallbackButton.hidden = (_startupError == nil);
    [_exitFallbackButton addTarget:self action:@selector(closeEmulator) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_exitFallbackButton];

    _brumMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _brumMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    _brumMenuButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.65];
    _brumMenuButton.layer.cornerRadius = 22;
    _brumMenuButton.layer.borderWidth = 1.0;
    _brumMenuButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.26].CGColor;
    _brumMenuButton.alpha = 0.50;
    UIImage *logoImage = [UIImage imageNamed:@"BrumLogo"];
    if (logoImage) {
        [_brumMenuButton setImage:logoImage forState:UIControlStateNormal];
        _brumMenuButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        _brumMenuButton.imageEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
    } else {
        [_brumMenuButton setImage:[UIImage systemImageNamed:@"gamecontroller.fill"] forState:UIControlStateNormal];
        _brumMenuButton.tintColor = UIColor.whiteColor;
    }
    _brumMenuButton.accessibilityLabel = @"Menu rápido BRUMCLASSICS";
    _brumMenuButton.accessibilityHint = @"Abre controles, ajustes, slots, dimensão de tela, gráficos, avanço rápido e saída.";
    [_brumMenuButton addTarget:self action:@selector(showBrumQuickMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_brumMenuButton];

    _fastForwardBadge = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"forward.fill"] imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBlack]]];
    _fastForwardBadge.translatesAutoresizingMaskIntoConstraints = NO;
    _fastForwardBadge.tintColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _fastForwardBadge.hidden = YES;
    _fastForwardBadge.accessibilityLabel = @"Avanço rápido ativo";
    [self.view addSubview:_fastForwardBadge];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusLabel.text = _retroAchievementsGameID > 0
        ? [NSString stringWithFormat:@"BRUM CORE · %@ · RA ID %ld", _coreDisplayName, (long)_retroAchievementsGameID]
        : [NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName];
    _statusLabel.textColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _statusLabel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.78];
    _statusLabel.layer.cornerRadius = 8;
    _statusLabel.clipsToBounds = YES;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _statusLabel.userInteractionEnabled = NO;
    _statusLabel.hidden = !_performanceHUDEnabled;
    _statusLabel.alpha = _performanceHUDEnabled ? 1 : 0;
    [self.view addSubview:_statusLabel];

    const char *systemID = _emulatedSystemID.UTF8String;
    const auto profile = brum::virtualControlProfile(systemID ? systemID : "");
    const BOOL isN64 = profile && profile->face == brum::VirtualFace::n64;
    const BOOL isDreamcast = [_emulatedSystemID isEqualToString:@"dreamcast"];
    const BOOL isGameCube = [_emulatedSystemID isEqualToString:@"gamecube"];
    const BOOL is3DS = [_emulatedSystemID isEqualToString:@"3ds"];
    const BOOL isSega = [@[@"md", @"segacd", @"32x"] containsObject:_emulatedSystemID];
    const BOOL isSaturn = [_emulatedSystemID isEqualToString:@"saturn"];
    const BOOL isPSP = [_emulatedSystemID isEqualToString:@"psp"];
    const BOOL hasAnalogPad = profile && profile->leftStick;
    UIView *up = hasAnalogPad ? [self analogPad] : [self directionPad];
    UIView *actions = profile ? [self profileActionPad:profile->face] : [UIView new];
    if (!profile) {
        [self showStateStatus:@"CONTROLE VIRTUAL INDISPONÍVEL PARA ESTE SISTEMA" error:YES];
        actions.translatesAutoresizingMaskIntoConstraints = NO;
        [actions.widthAnchor constraintEqualToConstant:1].active = YES;
        [actions.heightAnchor constraintEqualToConstant:1].active = YES;
    } else if (profile->face == brum::VirtualFace::arcadeSix) {
        [self showStateStatus:[NSString stringWithFormat:@"BRUM CORE · %@ · ARCADE 6 BOTÕES", _coreDisplayName] error:NO];
    }
    _directionControl = up;
    _actionControl = actions;
    UIButton *start = [self controlButton:@"START" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_START];
    NSString *selectLabel = isN64 ? @"Z" : isSega ? @"MODE" :
        [@[@"ws", @"wsc"] containsObject:_emulatedSystemID] ? @"GIRAR" : @"SELECT";
    NSArray<UIButton *> *menuButtons = profile && profile->select ? @[
        [self controlButton:selectLabel identifier:isN64 ? BRUM_RETRO_DEVICE_ID_JOYPAD_L2 : BRUM_RETRO_DEVICE_ID_JOYPAD_SELECT], start
    ] : profile ? @[start] : @[];
    UIStackView *menu = [[UIStackView alloc] initWithArrangedSubviews:menuButtons];
    UIButton *leftShoulder = [self controlButton:isDreamcast ? @"LT" : @"L" identifier:(isDreamcast || isGameCube || isSaturn) ? BRUM_RETRO_DEVICE_ID_JOYPAD_L2 : BRUM_RETRO_DEVICE_ID_JOYPAD_L];
    UIButton *rightShoulder = [self controlButton:isDreamcast ? @"RT" : @"R" identifier:(isDreamcast || isGameCube || isSaturn) ? BRUM_RETRO_DEVICE_ID_JOYPAD_R2 : BRUM_RETRO_DEVICE_ID_JOYPAD_R];
    leftShoulder.hidden = !profile || (!profile->shoulders && !profile->triggers);
    rightShoulder.hidden = leftShoulder.hidden;
    [self.view addSubview:leftShoulder]; [self.view addSubview:rightShoulder];
    if (!leftShoulder.hidden) {
        [_padOverlayViews addObject:leftShoulder];
        [_padOverlayViews addObject:rightShoulder];
    }
    if (isGameCube) {
        UIButton *z = [self controlButton:@"Z" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R];
        [self.view addSubview:z];
        [_padOverlayViews addObject:z];
        [NSLayoutConstraint activateConstraints:@[
            [z.trailingAnchor constraintEqualToAnchor:rightShoulder.leadingAnchor constant:-8],
            [z.centerYAnchor constraintEqualToAnchor:rightShoulder.centerYAnchor]
        ]];
    }
    if (is3DS) {
        UIButton *zl = [self controlButton:@"ZL" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L2];
        UIButton *zr = [self controlButton:@"ZR" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R2];
        [self.view addSubview:zl]; [self.view addSubview:zr];
        [_padOverlayViews addObject:zl]; [_padOverlayViews addObject:zr];
        [NSLayoutConstraint activateConstraints:@[
            [zl.leadingAnchor constraintEqualToAnchor:leftShoulder.trailingAnchor constant:8],
            [zl.centerYAnchor constraintEqualToAnchor:leftShoulder.centerYAnchor],
            [zr.trailingAnchor constraintEqualToAnchor:rightShoulder.leadingAnchor constant:-8],
            [zr.centerYAnchor constraintEqualToAnchor:rightShoulder.centerYAnchor]
        ]];
    }
    if ([_emulatedSystemID isEqualToString:@"psx"]) {
        [leftShoulder setTitle:@"L1" forState:UIControlStateNormal];
        [rightShoulder setTitle:@"R1" forState:UIControlStateNormal];
        UIButton *l2 = [self controlButton:@"L2" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L2];
        UIButton *r2 = [self controlButton:@"R2" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R2];
        [self.view addSubview:l2]; [self.view addSubview:r2];
        [_padOverlayViews addObject:l2]; [_padOverlayViews addObject:r2];
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
    [_padOverlayViews addObjectsFromArray:@[up, actions, menu]];
    if (isGameCube || is3DS) {
        _rightVirtualStick = [[BrumVirtualStick alloc] initWithFrame:CGRectZero];
        _rightVirtualStick.translatesAutoresizingMaskIntoConstraints = NO;
        _rightVirtualStick.accessibilityLabel = isGameCube ? @"Stick C" : @"C-Stick";
        [_rightVirtualStick addTarget:self action:@selector(rightVirtualStickChanged:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:_rightVirtualStick];
        [_padOverlayViews addObject:_rightVirtualStick];
        [NSLayoutConstraint activateConstraints:@[
            [_rightVirtualStick.widthAnchor constraintEqualToConstant:106],
            [_rightVirtualStick.heightAnchor constraintEqualToConstant:106],
            [_rightVirtualStick.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-102],
            [_rightVirtualStick.bottomAnchor constraintEqualToAnchor:actions.topAnchor constant:-10]
        ]];
    }
    if (hasAnalogPad) {
        _digitalPad = [self directionPad];
        _digitalPad.hidden = !isPSP;
        [self.view addSubview:_digitalPad];
        if (isPSP) {
            [_padOverlayViews addObject:_digitalPad];
        } else {
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
            [_padOverlayViews addObject:_padModeButton];
        }
    }

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_exitFallbackButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_exitFallbackButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [_exitFallbackButton.widthAnchor constraintEqualToConstant:92],
        [_brumMenuButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_brumMenuButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_brumMenuButton.widthAnchor constraintEqualToConstant:44],
        [_brumMenuButton.heightAnchor constraintEqualToConstant:44],
        [_fastForwardBadge.leadingAnchor constraintEqualToAnchor:_brumMenuButton.trailingAnchor constant:8],
        [_fastForwardBadge.centerYAnchor constraintEqualToAnchor:_brumMenuButton.centerYAnchor],
        [_statusLabel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_statusLabel.topAnchor constraintEqualToAnchor:_brumMenuButton.bottomAnchor constant:6],
        [_statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:24],
        [_statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-24],
        [_screen.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [_screen.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_screen.topAnchor constraintEqualToAnchor:self.view.topAnchor], [_screen.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [up.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:isPSP ? 24 : 26], [up.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:isPSP ? -14 : -24],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-30], [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-36],
        [menu.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [menu.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
        [leftShoulder.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18], [leftShoulder.topAnchor constraintEqualToAnchor:safe.topAnchor constant:isPSP ? 16 : 44],
        [rightShoulder.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18], [rightShoulder.topAnchor constraintEqualToAnchor:safe.topAnchor constant:isPSP ? 16 : 44]
    ]];
    if (hasAnalogPad) {
        if (isPSP) {
            [NSLayoutConstraint activateConstraints:@[
                [_digitalPad.centerXAnchor constraintEqualToAnchor:up.centerXAnchor],
                [_digitalPad.bottomAnchor constraintEqualToAnchor:up.topAnchor constant:-8]
            ]];
        } else {
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
    [self refreshVideoFilterPresentation];
    [self applyVirtualControlsStyle];
  }

- (UIButton *)controlButton:(NSString *)text identifier:(NSInteger)identifier {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.multipleTouchEnabled = YES;
    button.exclusiveTouch = NO;
    button.tag = identifier;
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setTitleColor:UIColor.blackColor forState:UIControlStateSelected];
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBlack];
    button.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.82];
    button.layer.cornerRadius = 18;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    button.layer.borderWidth = 1;
    if (identifier >= 0) {
        [button addTarget:self action:@selector(inputDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(inputDown:) forControlEvents:UIControlEventTouchDragEnter];
        [button addTarget:self action:@selector(inputUp:) forControlEvents:UIControlEventTouchDragExit | UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [_virtualButtons addObject:button];
    }
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:54].active = YES;
    [button.heightAnchor constraintEqualToConstant:44].active = YES;
    return button;
}

- (BrumVirtualDPad *)directionPad {
    BrumVirtualDPad *pad = [[BrumVirtualDPad alloc] initWithFrame:CGRectZero];
    pad.translatesAutoresizingMaskIntoConstraints = NO;
    pad.multipleTouchEnabled = YES;
    [pad addTarget:self action:@selector(dpadChanged:) forControlEvents:UIControlEventValueChanged];
    [pad addTarget:self action:@selector(dpadTouchDown:) forControlEvents:UIControlEventTouchDown];
    if (!_primaryDPad) _primaryDPad = pad;
    else _secondaryDPad = pad;
    const BOOL isPSP = [_emulatedSystemID isEqualToString:@"psp"];
    [pad.widthAnchor constraintEqualToConstant:isPSP ? 132 : 166].active = YES;
    [pad.heightAnchor constraintEqualToConstant:isPSP ? 116 : 132].active = YES;
    return pad;
}

- (void)dpadChanged:(BrumVirtualDPad *)pad {
    const uint8_t mask = _paused ? 0 : pad.mask;
    const uint8_t dirs[4] = {brum::up, brum::down, brum::left, brum::right};
    const unsigned ids[4] = {
        BRUM_RETRO_DEVICE_ID_JOYPAD_UP,
        BRUM_RETRO_DEVICE_ID_JOYPAD_DOWN,
        BRUM_RETRO_DEVICE_ID_JOYPAD_LEFT,
        BRUM_RETRO_DEVICE_ID_JOYPAD_RIGHT
    };
    for (int i = 0; i < 4; ++i) {
        const BOOL pressed = (mask & dirs[i]) != 0;
        const BOOL wasPressed = _input.pressed(ids[i]);
        _input.set(brum::InputSource::virtualPad, ids[i], pressed);
        if (pressed && !wasPressed) _input.latchButton(ids[i], 3);
    }
}

- (void)dpadTouchDown:(BrumVirtualDPad *)pad {
    if (_virtualHapticsEnabled && !_paused && !_stopped && pad.mask) [_virtualFeedback impactOccurred];
}

- (BrumVirtualStick *)analogPad {
    _virtualStick = [[BrumVirtualStick alloc] initWithFrame:CGRectZero];
    _virtualStick.translatesAutoresizingMaskIntoConstraints = NO;
    const CGFloat size = [_emulatedSystemID isEqualToString:@"psp"] ? 110 : 146;
    [_virtualStick.widthAnchor constraintEqualToConstant:size].active = YES;
    [_virtualStick.heightAnchor constraintEqualToConstant:size].active = YES;
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

- (UIStackView *)faceRows:(NSArray<NSArray<UIButton *> *> *)rows width:(CGFloat)width {
    NSMutableArray<UIStackView *> *rowViews = [NSMutableArray arrayWithCapacity:rows.count];
    for (NSArray<UIButton *> *buttons in rows) {
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:buttons];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.alignment = UIStackViewAlignmentCenter;
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 6;
        [rowViews addObject:row];
    }
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:rowViews];
    pad.translatesAutoresizingMaskIntoConstraints = NO;
    pad.axis = UILayoutConstraintAxisVertical;
    pad.alignment = UIStackViewAlignmentCenter;
    pad.spacing = 6;
    [pad.widthAnchor constraintGreaterThanOrEqualToConstant:width].active = YES;
    return pad;
}

- (UIStackView *)profileActionPad:(brum::VirtualFace)face {
    switch (face) {
        case brum::VirtualFace::one:
            return [self faceRows:@[@[[self controlButton:@"FIRE" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B]]] width:70];
        case brum::VirtualFace::two: {
            const BOOL pce = [_emulatedSystemID isEqualToString:@"pce"];
            const BOOL segaHandheld = [@[@"sms", @"gg"] containsObject:_emulatedSystemID];
            return [self faceRows:@[@[
                [self controlButton:pce ? @"II" : segaHandheld ? @"1" : @"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B],
                [self controlButton:pce ? @"I" : segaHandheld ? @"2" : @"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A]
            ]] width:120];
        }
        case brum::VirtualFace::n64: return [self n64ActionPad];
        case brum::VirtualFace::segaSix: return [self segaActionPad];
        case brum::VirtualFace::neoGeo:
            return [self faceRows:@[@[
                [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B],
                [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A],
                [self controlButton:@"C" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_Y],
                [self controlButton:@"D" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_X]
            ]] width:240];
        case brum::VirtualFace::wonderSwan:
            // Beetle WonderSwan's pinned map: X cursor = D-pad, Y cursor =
            // R2/R/L2/L. A and B remain the RetroPad A and B buttons.
            return [self faceRows:@[
                @[[self controlButton:@"Y▲" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R2]],
                @[[self controlButton:@"Y◀" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L],
                  [self controlButton:@"Y▶" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R]],
                @[[self controlButton:@"Y▼" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L2],
                  [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B],
                  [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A]]
            ] width:184];
        case brum::VirtualFace::arcadeSix:
            return [self faceRows:@[
                @[[self controlButton:@"1" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_Y],
                  [self controlButton:@"2" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_X],
                  [self controlButton:@"3" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_L]],
                @[[self controlButton:@"4" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B],
                  [self controlButton:@"5" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A],
                  [self controlButton:@"6" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_R]]
            ] width:184];
        case brum::VirtualFace::four:
        case brum::VirtualFace::sony: return [self actionPad];
    }
    NSLog(@"BRUM Core: perfil de controle virtual sem componente visual para %@", _emulatedSystemID);
    return [self faceRows:@[] width:1];
}

- (void)virtualStickChanged:(BrumVirtualStick *)stick {
    const BOOL ignoreStick = _dpadMode && ![_emulatedSystemID isEqualToString:@"psp"];
    [self setAnalogStick:0 axis:0 value:ignoreStick ? 0 : stick.horizontal source:BrumInputVirtualPad];
    [self setAnalogStick:0 axis:1 value:ignoreStick ? 0 : stick.vertical source:BrumInputVirtualPad];
}

- (void)rightVirtualStickChanged:(BrumVirtualStick *)stick {
    [self setAnalogStick:1 axis:0 value:stick.horizontal source:BrumInputVirtualPad];
    [self setAnalogStick:1 axis:1 value:stick.vertical source:BrumInputVirtualPad];
}

- (void)toggleAnalogPadMode {
    _dpadMode = !_dpadMode;
    [_virtualStick reset];
    [_primaryDPad reset];
    [_secondaryDPad reset];
    _virtualStick.hidden = _controlsHidden || _dpadMode;
    _virtualStick.enabled = !_dpadMode && !_paused;
    _digitalPad.hidden = _controlsHidden || !_dpadMode;
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return touch.view == _screen || touch.view == self.view;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)screenTouch:(UILongPressGestureRecognizer *)gesture {
    if (_paused || !_frameWidth || !_frameHeight || !(self.capabilities & BrumBackendTouch)) {
        _pointerPressed = NO;
        _pointerLatchFrames = 0;
        _pointerX = 0;
        _pointerY = 0;
        _touchReticle.hidden = YES;
        return;
    }
    CGPoint point = [gesture locationInView:_screen];
    if (_screenManager.screens.size() > 1) {
        const auto touch = brum::ScreenManager::hitTest({point.x, point.y}, _screenPlacements);
        _pointerPressed = touch.pressed && touch.screenID == "secondary" &&
            (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged);
        if (_pointerPressed) {
            _pointerLatchFrames = 4;
            _pointerX = (int16_t)lrint((touch.atlas.x * 2 - 1) * 32767);
            _pointerY = (int16_t)lrint((touch.atlas.y * 2 - 1) * 32767);
            // Dual-screen cores treat Y == 0 on the lower half as pen-up or boundary.
            _pointerY = MAX(1, _pointerY);
            _touchReticle.center = point;
            _touchReticle.hidden = NO;
        } else {
            _pointerX = 0;
            _pointerY = 0;
            _touchReticle.hidden = YES;
        }
        return;
    }
    const auto local = _singleViewport.toContent({point.x, point.y});
    _pointerPressed = local.has_value() &&
        (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged);
    if (_pointerPressed) {
        _pointerLatchFrames = 4;
        _pointerX = (int16_t)lrint((local->x * 2 - 1) * 32767);
        _pointerY = (int16_t)lrint((local->y * 2 - 1) * 32767);
        _touchReticle.center = point;
        _touchReticle.hidden = NO;
    } else {
        _touchReticle.hidden = YES;
    }
}

- (void)setButton:(NSUInteger)button source:(BrumInputSource)source pressed:(BOOL)pressed {
    if (button >= 16 || source > BrumInputRemote || (_paused && pressed)) return;
    _input.set(static_cast<brum::InputSource>(source), (unsigned)button, pressed);
    if (source == BrumInputVirtualPad && pressed) {
        _input.latchButton((unsigned)button, 3);
    }
}

- (void)releaseInputSource:(BrumInputSource)source {
    if (source <= BrumInputRemote) _input.release(static_cast<brum::InputSource>(source));
}

- (void)setAnalogStick:(NSUInteger)stick axis:(NSUInteger)axis value:(double)value source:(BrumInputSource)source {
    if (_paused || _stopped || source > BrumInputRemote || stick > 1 || axis > 1) return;
    _input.setAxis(static_cast<brum::InputSource>(source), (unsigned)stick, (unsigned)axis, value);
}

- (void)inputDown:(UIButton *)sender {
    if (sender.tag < 0 || _paused || _stopped || sender.selected) return;
    if (sender.tag >= 16 && sender.tag <= 19 && [_emulatedSystemID isEqualToString:@"n64"]) {
        _n64CButtonMask |= (uint8_t)(1u << (sender.tag - 16));
        [self updateN64CButtons];
    } else {
        [self setButton:(NSUInteger)sender.tag source:BrumInputVirtualPad pressed:YES];
    }
    [self setVirtualButton:sender pressed:YES];
    if (_virtualHapticsEnabled) [_virtualFeedback impactOccurred];
}

- (void)inputUp:(UIButton *)sender {
    if (sender.tag < 0 || !sender.selected) return;
    if (sender.tag >= 16 && sender.tag <= 19 && [_emulatedSystemID isEqualToString:@"n64"]) {
        _n64CButtonMask &= (uint8_t)~(1u << (sender.tag - 16));
        [self updateN64CButtons];
    } else {
        [self setButton:(NSUInteger)sender.tag source:BrumInputVirtualPad pressed:NO];
    }
    [self setVirtualButton:sender pressed:NO];
}

- (void)setVirtualButton:(UIButton *)button pressed:(BOOL)pressed {
    button.selected = pressed;
    button.transform = pressed ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    button.backgroundColor = pressed ? [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:0.98]
                                     : [UIColor colorWithWhite:0.1 alpha:0.82];
    button.layer.borderColor = (pressed ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.16]).CGColor;
    [button setTitleColor:pressed ? UIColor.blackColor : UIColor.whiteColor forState:UIControlStateNormal];
}

- (void)releaseVirtualControls {
    for (UIButton *button in _virtualButtons) {
        if (button.selected) [self setVirtualButton:button pressed:NO];
    }
}

- (BOOL)ensureHardwareDisplayDrawable {
    if (!_hardwareInitialized || !_hardwareContext || _hardwareContext.API < kEAGLRenderingAPIOpenGLES3 ||
        !_hardwareDisplayLayer || !_hardwareDisplayFramebuffer || !_hardwareDisplayRenderbuffer) {
        return NO;
    }
    const CGSize size = _hardwareDisplayLayer.bounds.size;
    if (size.width < 1.0 || size.height < 1.0) return NO;
    const CGFloat scale = _hardwareDisplayLayer.contentsScale >= 1.0 ? _hardwareDisplayLayer.contentsScale : 1.0;
    const GLint expectedW = (GLint)llround(size.width * scale);
    const GLint expectedH = (GLint)llround(size.height * scale);
    if (_hardwareDisplayReady && _hardwareDisplayWidth == expectedW && _hardwareDisplayHeight == expectedH) {
        return YES;
    }
    GLint prevReadFBO = 0, prevDrawFBO = 0, prevRenderbuffer = 0;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prevReadFBO);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &prevDrawFBO);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &prevRenderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _hardwareDisplayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _hardwareDisplayRenderbuffer);
    BOOL attached = [_hardwareContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_hardwareDisplayLayer];
    GLint rbW = 0, rbH = 0;
    if (attached) {
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &rbW);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &rbH);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _hardwareDisplayRenderbuffer);
    }
    _hardwareDisplayWidth = rbW;
    _hardwareDisplayHeight = rbH;
    _hardwareDisplayReady = attached && rbW > 0 && rbH > 0 &&
        glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)prevRenderbuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)prevReadFBO);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)prevDrawFBO);
    return _hardwareDisplayReady;
}

- (BOOL)presentHardwareFrameDirectWidth:(unsigned)width height:(unsigned)height {
    if (_screenProfileWidth != _frameWidth || _screenProfileHeight != _frameHeight) {
        _screenProfileWidth = _frameWidth;
        _screenProfileHeight = _frameHeight;
        _screenManager.screens = brum::libretroScreens(_coreID.UTF8String, _frameWidth, _frameHeight);
        [self updateDisplayModeButton];
        [self layoutScreens];
    }
    NSString *activeFilter = self.videoFilterMode ?: @"none";
    const BOOL usesCPUShader = [activeFilter isEqualToString:@"cas_sharpen"] ||
        [activeFilter isEqualToString:@"edge_upscale_2x"] ||
        [activeFilter isEqualToString:@"sharp_bilinear"];
    const BOOL canDirectPresent = _hardwareInitialized && _hardwareContext &&
        _hardwareContext.API >= kEAGLRenderingAPIOpenGLES3 &&
        _hardwareDisplayLayer && _hardwareDisplayFramebuffer && _hardwareDisplayRenderbuffer &&
        _screenManager.screens.size() == 1 && _singleViewport.valid() && !usesCPUShader;
    if (!canDirectPresent) {
        if (_hardwareDisplayLayer && !_hardwareDisplayLayer.hidden) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _hardwareDisplayLayer.hidden = YES;
            _singleScreenLayer.hidden = (_screenManager.screens.size() != 1);
            [CATransaction commit];
        }
        return NO;
    }
    if (_hardwareDisplayLayer.hidden || !_singleScreenLayer.hidden) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _singleScreenLayer.hidden = YES;
        _hardwareDisplayLayer.hidden = NO;
        [CATransaction commit];
    }
    if (![self ensureHardwareDisplayDrawable]) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _hardwareDisplayLayer.hidden = YES;
        _singleScreenLayer.hidden = NO;
        [CATransaction commit];
        return NO;
    }
    while (glGetError() != GL_NO_ERROR) {}
    GLint prevReadFBO = 0, prevDrawFBO = 0, prevReadBuffer = GL_COLOR_ATTACHMENT0, prevRenderbuffer = 0;
    const GLboolean hadScissor = glIsEnabled(GL_SCISSOR_TEST);
    GLboolean prevColorMask[4] = {GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE};
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &prevReadFBO);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &prevDrawFBO);
    glGetIntegerv(GL_READ_BUFFER, &prevReadBuffer);
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &prevRenderbuffer);
    glGetBooleanv(GL_COLOR_WRITEMASK, prevColorMask);
    if (hadScissor) glDisable(GL_SCISSOR_TEST);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, _hardwareFramebuffer);
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, _hardwareDisplayFramebuffer);
    const GLenum blitFilter = ([activeFilter isEqualToString:@"none"] && _integerScalingEnabled) ? GL_NEAREST : GL_LINEAR;
    const GLint dstY0 = _hardwareCallback.bottom_left_origin ? 0 : _hardwareDisplayHeight;
    const GLint dstY1 = _hardwareCallback.bottom_left_origin ? _hardwareDisplayHeight : 0;
    glBlitFramebuffer(0, 0, (GLint)width, (GLint)height,
                      0, dstY0, _hardwareDisplayWidth, dstY1,
                      GL_COLOR_BUFFER_BIT, blitFilter);
    const GLenum blitErr = glGetError();
    BOOL presented = NO;
    if (blitErr == GL_NO_ERROR) {
        glBindRenderbuffer(GL_RENDERBUFFER, _hardwareDisplayRenderbuffer);
        presented = [_hardwareContext presentRenderbuffer:GL_RENDERBUFFER];
    }
    glColorMask(prevColorMask[0], prevColorMask[1], prevColorMask[2], prevColorMask[3]);
    if (hadScissor) glEnable(GL_SCISSOR_TEST);
    glReadBuffer((GLenum)prevReadBuffer);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, (GLuint)prevReadFBO);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, (GLuint)prevDrawFBO);
    glBindRenderbuffer(GL_RENDERBUFFER, (GLuint)prevRenderbuffer);
    if (!presented) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _hardwareDisplayLayer.hidden = YES;
        _singleScreenLayer.hidden = NO;
        [CATransaction commit];
        return NO;
    }
    ++_presentedFrames;
    ++_nonBlackFrameCount;
    return YES;
}

- (void)presentFrame:(CGImageRef)image {
    if (_screenProfileWidth != _frameWidth || _screenProfileHeight != _frameHeight) {
        _screenProfileWidth = _frameWidth;
        _screenProfileHeight = _frameHeight;
        _screenManager.screens = brum::libretroScreens(_coreID.UTF8String, _frameWidth, _frameHeight);
        [self updateDisplayModeButton];
        [self layoutScreens];
    }
    if (_screenManager.screens.size() == 1) {
        for (CALayer *layer in _screenLayers) layer.hidden = YES;
        if (_hardwareDisplayLayer && !_hardwareDisplayLayer.hidden) {
            _hardwareDisplayLayer.hidden = YES;
            _singleScreenLayer.hidden = NO;
        }
        _singleScreenLayer.contents = (__bridge id)image;
        return;
    }
    BOOL addedLayers = NO;
    while (_screenLayers.count < _screenManager.screens.size()) {
        CALayer *layer = [CALayer layer];
        layer.magnificationFilter = ([_videoFilterMode isEqualToString:@"bilinear_subtle"] || [_videoFilterMode isEqualToString:@"sharp_bilinear"]) ? kCAFilterLinear : kCAFilterNearest;
        layer.contentsGravity = kCAGravityResize;
        [_screen.layer addSublayer:layer];
        [_screenLayers addObject:layer];
        addedLayers = YES;
    }
    _singleScreenLayer.hidden = YES;
    if (_hardwareDisplayLayer) _hardwareDisplayLayer.hidden = YES;
    if (addedLayers) [self layoutScreens];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in _screenLayers) layer.contents = (__bridge id)image;
    [CATransaction commit];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutScreens];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (brum::Rect)availableGameRect {
    return {0, 0, MAX(0, _screen.bounds.size.width), MAX(0, _screen.bounds.size.height)};
}

- (void)layoutScreens {
    _pointerPressed = NO;
    _pointerLatchFrames = 0;
    _pointerX = 0;
    _pointerY = 0;
    _touchReticle.hidden = YES;
    const brum::Rect available = [self availableGameRect];
    if (_screenManager.screens.size() < 2) {
        _screenPlacements.clear();
        const double aspectWidth = _contentAspectRatio > 0 && _frameHeight > 0
            ? _frameHeight * _contentAspectRatio : _frameWidth;
        _singleViewport = brum::calculateViewport(available, aspectWidth, _frameHeight,
            _screenFillsDisplay ? brum::ScaleMode::crop : brum::ScaleMode::fit);
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        const BOOL showSingle = _singleViewport.valid();
        const BOOL directActive = _hardwareDisplayLayer && !_hardwareDisplayLayer.hidden && showSingle;
        _singleScreenLayer.hidden = !showSingle || directActive;
        const CGRect targetFrame = CGRectMake(_singleViewport.frame.x, _singleViewport.frame.y,
                                              _singleViewport.frame.width, _singleViewport.frame.height);
        _singleScreenLayer.frame = targetFrame;
        if (_hardwareDisplayLayer) {
            if (!CGSizeEqualToSize(_hardwareDisplayLayer.bounds.size, targetFrame.size)) {
                _hardwareDisplayReady = NO;
            }
            _hardwareDisplayLayer.frame = targetFrame;
            if (!showSingle) _hardwareDisplayLayer.hidden = YES;
        }
        if (_scanlineOverlayLayer) {
            _scanlineOverlayLayer.hidden = !showSingle;
            _scanlineOverlayLayer.frame = targetFrame;
        }
        [CATransaction commit];
        return;
    }
    _singleScreenLayer.hidden = YES;
    if (_hardwareDisplayLayer) _hardwareDisplayLayer.hidden = YES;
    if (!_layoutManuallyChosen) {
        _screenManager.layout = _screen.bounds.size.width > _screen.bounds.size.height
            ? brum::Layout::horizontal : brum::Layout::vertical;
    }
    _screenPlacements = _screenManager.place(available);
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
    NSArray<NSString *> *titles = @[@"Superior em cima", @"Inferior em cima", @"Superior à esquerda", @"Inferior à esquerda", @"Somente superior", @"Somente inferior", @"Superior em destaque", @"Inferior em destaque"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        [menu addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            self->_screenManager.layout = static_cast<brum::Layout>(i);
            self->_layoutManuallyChosen = YES;
            self->_pointerPressed = NO;
            self->_pointerLatchFrames = 0;
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
    UIView *anchor = _brumMenuButton ?: self.view;
    menu.popoverPresentationController.sourceView = anchor;
    menu.popoverPresentationController.sourceRect = anchor.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)toggleFastForward {
    _fastForwardEnabled = !_fastForwardEnabled;
    _frameCadence.reset();
    os_unfair_lock_lock(&_audioLock);
    _audioRead = 0; _audioWrite = 0; _audioCount = 0;
    os_unfair_lock_unlock(&_audioLock);
    _fastForwardBadge.hidden = !_fastForwardEnabled;
    [self showStateStatus:(_fastForwardEnabled ? @"AVANÇO RÁPIDO · 5×" : [NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName]) error:NO];
}

- (void)toggleControlsVisibility {
    _manualControlsHidden = !_manualControlsHidden;
    [self applyVirtualControlsVisibility];
}

- (void)applyVirtualControlsVisibility {
    const BOOL hasPhysical = BrumActiveControllers().count > 0;
    const BOOL nextHidden = _manualControlsHidden || (_autoHideWithController && _virtualPadPort == 0 && hasPhysical);
    _controlsHidden = nextHidden;
    if (nextHidden) {
        [self releaseInputSource:BrumInputVirtualPad];
        [self releaseVirtualControls];
        [_primaryDPad reset];
        [_secondaryDPad reset];
        [_virtualStick reset];
        [_rightVirtualStick reset];
    }
    for (UIView *control in _padOverlayViews) {
        control.hidden = nextHidden;
    }
    const BOOL isPSP = [_emulatedSystemID isEqualToString:@"psp"];
    if (_digitalPad) _digitalPad.hidden = nextHidden || (!isPSP && !_dpadMode);
    if (_padModeButton) _padModeButton.hidden = nextHidden;
    if (_virtualStick) {
        _virtualStick.hidden = nextHidden || (!isPSP && _dpadMode);
        _virtualStick.enabled = !nextHidden && !_paused && (isPSP || !_dpadMode);
    }
    [self applyVirtualControlsStyle];
    [self layoutScreens];
}

- (void)physicalControllerChanged:(NSNotification *)notification {
    [self releaseInputSource:BrumInputController];
    [self syncPhysicalControllerUIWithToast:YES];
}

- (void)syncPhysicalControllerUIWithToast:(BOOL)showToast {
    GCController *controller = BrumActiveControllers().firstObject;
    [self applyVirtualControlsVisibility];
    if (!showToast || _stopped) return;
    if (controller) {
        NSString *name = controller.vendorName ?: @"Controle físico";
        [self showStateStatus:[NSString stringWithFormat:@"CONTROLE CONECTADO · %@", name.uppercaseString] error:NO];
    } else {
        [self showStateStatus:@"CONTROLE DESCONECTADO · MODO TÁTIL" error:NO];
    }
}

- (void)toggleDisplayMode {
    if (self.capabilities & BrumBackendMultipleScreens) { [self showScreenMenu]; return; }
    _screenFillsDisplay = !_screenFillsDisplay;
    [self updateDisplayModeButton];
    [self layoutScreens];
}

- (void)updateDisplayModeButton {
    const BOOL multiScreen = _screenManager.screens.size() > 1;
    _brumMenuButton.accessibilityValue = multiScreen ? @"Duas telas" : (_screenFillsDisplay ? @"Preencher tela" : @"Mostrar imagem inteira");
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
        UIView *anchor = _brumMenuButton ?: self.view;
        menu.popoverPresentationController.sourceView = anchor;
        menu.popoverPresentationController.sourceRect = anchor.bounds;
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
    if (_raRuntime) _raRuntime->reset();
    if (_pokedexTracker) _pokedexTracker->reset();
    os_unfair_lock_lock(&_audioLock); _audioRead = 0; _audioWrite = 0; _audioCount = 0; os_unfair_lock_unlock(&_audioLock);
    [self showStateStatus:[NSString stringWithFormat:@"SLOT %ld CARREGADO", (long)slot] error:NO];
}

- (void)showStateStatus:(NSString *)text error:(BOOL)error {
    _statusLabel.text = [NSString stringWithFormat:@"  %@  ", text ?: @""];
    _statusLabel.textColor = error ? UIColor.systemRedColor : [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _statusLabel.hidden = NO;
    _statusLabel.alpha = 1;
    const NSUInteger token = ++_statusToastToken;
    __weak BrumLibretroViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_stopped || strongSelf->_statusToastToken != token) return;
        if (!strongSelf->_performanceHUDEnabled && !strongSelf->_startupError) {
            strongSelf->_statusLabel.alpha = 0;
            strongSelf->_statusLabel.hidden = YES;
        }
    });
}

- (void)showBrumQuickMenu {
    if (_stopped || self.presentedViewController) return;
    const BOOL wasPaused = _explicitlyPaused;
    [self pause];
    NSString *title = _gameTitle.length ? _gameTitle : _coreDisplayName;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:title
                                                                   message:[NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *padLabel = _manualControlsHidden ? @"Mostrar controles na tela" : @"Ocultar controles na tela";
    [menu addAction:[UIAlertAction actionWithTitle:padLabel style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self toggleControlsVisibility];
        if (!wasPaused) [self resume];
    }]];
    if (_padModeButton) {
        NSString *stickLabel = _dpadMode ? @"Controle esquerdo: Analógico" : @"Controle esquerdo: D-Pad";
        [menu addAction:[UIAlertAction actionWithTitle:stickLabel style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self toggleAnalogPadMode];
            if (!wasPaused) [self resume];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Ajuste de controles" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self showControlsAdjustmentMenu:wasPaused];
    }]];
    UIAlertAction *slotsAction = [UIAlertAction actionWithTitle:@"Estados rápidos (Slots)" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (!wasPaused) _explicitlyPaused = NO;
        [self showStateMenu];
    }];
    slotsAction.enabled = _gameLoaded && (self.capabilities & BrumBackendSaveState) != 0;
    [menu addAction:slotsAction];

    if (_screenManager.screens.size() > 1) {
        [menu addAction:[UIAlertAction actionWithTitle:@"Dimensão e layout das telas" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if (!wasPaused) _explicitlyPaused = NO;
            [self showScreenMenu];
        }]];
    } else {
        NSString *displayTitle = _screenFillsDisplay
            ? @"Dimensão de tela: Mostrar imagem inteira"
            : @"Dimensão de tela: Preencher tela";
        [menu addAction:[UIAlertAction actionWithTitle:displayTitle style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            if (self->_screenFillsDisplay) {
                self->_screenFillsDisplay = NO;
                [self updateDisplayModeButton];
                [self layoutScreens];
            } else {
                [self toggleDisplayMode];
            }
            if (!wasPaused) [self resume];
        }]];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Gráficos e filtros (ao vivo)" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self showVideoFilterMenu:wasPaused];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:(_fastForwardEnabled ? @"Avanço rápido (5×): Desativar" : @"Avanço rápido (5×): Ativar")
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction *action) {
        [self toggleFastForward];
        if (!wasPaused) [self resume];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Diagnóstico da sessão" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (!wasPaused) _explicitlyPaused = NO;
        [self shareDiagnostics];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Sair do jogo" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self closeEmulator];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Voltar ao jogo" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        if (!wasPaused) [self resume];
    }]];
    if (menu.popoverPresentationController) {
        UIView *anchor = _brumMenuButton ?: self.view;
        menu.popoverPresentationController.sourceView = anchor;
        menu.popoverPresentationController.sourceRect = anchor.bounds;
    }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)showControlsAdjustmentMenu:(BOOL)wasPaused {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"AJUSTE DE CONTROLES"
                                                                    message:@"Opacidade e escala aplicadas imediatamente na tela."
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *opacities = @[
        @{@"label": @"Opacidade 25% (bem discreta)", @"val": @0.25},
        @{@"label": @"Opacidade 45% (equilibrada)", @"val": @0.45},
        @{@"label": @"Opacidade 70%", @"val": @0.70},
        @{@"label": @"Opacidade 90%", @"val": @0.90}
    ];
    for (NSDictionary *item in opacities) {
        double v = [item[@"val"] doubleValue];
        [sheet addAction:[UIAlertAction actionWithTitle:item[@"label"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setDouble:v forKey:@"BrumVirtualControlsOpacity"];
            [self applyVirtualControlsStyle];
            if (!wasPaused) [self resume];
        }]];
    }
    NSArray<NSDictionary *> *scales = @[
        @{@"label": @"Tamanho compacto (85%)", @"val": @0.85},
        @{@"label": @"Tamanho padrão (100%)", @"val": @1.00},
        @{@"label": @"Tamanho ampliado (115%)", @"val": @1.15}
    ];
    for (NSDictionary *item in scales) {
        double v = [item[@"val"] doubleValue];
        [sheet addAction:[UIAlertAction actionWithTitle:item[@"label"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [defaults setDouble:v forKey:@"BrumVirtualControlsScale"];
            [self applyVirtualControlsStyle];
            if (!wasPaused) [self resume];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Voltar" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        if (!wasPaused) [self resume];
    }]];
    if (sheet.popoverPresentationController) {
        UIView *anchor = _brumMenuButton ?: self.view;
        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showVideoFilterMenu:(BOOL)wasPaused {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"GRÁFICOS E FILTROS"
                                                                    message:@"Aplicado instantaneamente sem reiniciar o jogo."
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray<NSDictionary *> *filters = @[
        @{@"title": @"Original (Pixel nítido)", @"mode": @"none"},
        @{@"title": @"Sharp Bilinear (Nitidez equilibrada)", @"mode": @"sharp_bilinear"},
        @{@"title": @"Bilinear sutil (Suave)", @"mode": @"bilinear_subtle"},
        @{@"title": @"CAS Sharpen (Realce fino)", @"mode": @"cas_sharpen"},
        @{@"title": @"Edge Upscale 2×", @"mode": @"edge_upscale_2x"},
        @{@"title": @"Scanlines CRT", @"mode": @"crt_scanlines"},
        @{@"title": @"Grade LCD portátil", @"mode": @"lcd_grid"}
    ];
    for (NSDictionary *entry in filters) {
        NSString *mode = entry[@"mode"];
        NSString *label = [_videoFilterMode isEqualToString:mode] ? [NSString stringWithFormat:@"✓ %@", entry[@"title"]] : entry[@"title"];
        [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            self.videoFilterMode = mode;
            [self refreshVideoFilterPresentation];
            [self showStateStatus:[NSString stringWithFormat:@"FILTRO: %@", entry[@"title"]] error:NO];
            if (!wasPaused) [self resume];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Voltar" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        if (!wasPaused) [self resume];
    }]];
    if (sheet.popoverPresentationController) {
        UIView *anchor = _brumMenuButton ?: self.view;
        sheet.popoverPresentationController.sourceView = anchor;
        sheet.popoverPresentationController.sourceRect = anchor.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (BOOL)startCore:(NSError **)error {
    if (_gameLoaded) return YES;
    if (_stopped || !_coreHandle) return NO;
    if (BrumCurrentHost && BrumCurrentHost != self) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:12 userInfo:@{NSLocalizedDescriptionKey: @"Encerre a sessão atual antes de abrir outro jogo."}];
        return NO;
    }
    BrumCurrentHost = self;
    [_diagnostics enterStage:@"initialize_core"];
    _core.setEnvironment(BrumEnvironment);
    _core.setVideo(BrumVideo);
    _core.setAudio(BrumAudioSample);
    _core.setAudioBatch(BrumAudioBatch);
    _core.setInputPoll(BrumInputPoll);
    _core.setInputState(BrumInputState);
    _core.initialize();
    _coreInitialized = YES;
    if (_shutdownRequested) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:14 userInfo:@{NSLocalizedDescriptionKey: @"O núcleo interrompeu a própria inicialização. Consulte o aviso registrado no relatório."}];
        return NO;
    }
    if (_core.setController) {
        for (unsigned port = 0; port < 4; port++) {
            _core.setController(port, BRUM_RETRO_DEVICE_JOYPAD);
        }
    }

    brum_retro_system_info systemInfo = {};
    _core.getSystemInfo(&systemInfo);
    [_diagnostics enterStage:@"inspect_content"];
    if (!systemInfo.valid_extensions || !brum::acceptsContentExtension(systemInfo.valid_extensions, _romURL.pathExtension.UTF8String ?: "")) {
        NSString *formats = systemInfo.valid_extensions ? [NSString stringWithUTF8String:systemInfo.valid_extensions] : @"nenhum";
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:15 userInfo:@{NSLocalizedDescriptionKey:
            [NSString stringWithFormat:@"O núcleo %@ desta build não aceita .%@. Formatos informados pelo próprio núcleo: %@. O arquivo original foi preservado.", _coreDisplayName, _romURL.pathExtension, formats ?: @"inválidos"]}];
        return NO;
    }
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
    [_diagnostics enterStage:@"load_content"];
    if (!_core.loadGame(&gameInfo)) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O núcleo %@ recusou este arquivo. Confirme que a ROM é válida para %@.", _coreDisplayName, _emulatedSystemID.uppercaseString]}];
        return NO;
    }
    _gameLoaded = YES;
    if (_shutdownRequested) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:16 userInfo:@{NSLocalizedDescriptionKey: @"O núcleo interrompeu o carregamento do conteúdo. Consulte os avisos de formato, BIOS ou arquivos ausentes no relatório."}];
        return NO;
    }
    [_diagnostics enterStage:@"initialize_graphics"];
    if (![self initializeHardware:error]) return NO;
    [self restoreSaveRAM];
    if (_romData && _romData.length > 0) {
        [self startRetroAchievementsSession];
    } else {
        __weak BrumLibretroViewController *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            BrumLibretroViewController *strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_stopped) return;
            [strongSelf startRetroAchievementsSession];
        });
    }
    [self startPokedexCaptureSession];
    brum_retro_system_av_info avInfo = {};
    _core.getAVInfo(&avInfo);
    if (_hasPendingAVInfo) { avInfo = _pendingAVInfo; _hasPendingAVInfo = NO; }
    if (!BrumValidGeometry(&avInfo.geometry) || !brum::validAVTiming(avInfo.timing.fps, avInfo.timing.sample_rate)) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:17 userInfo:@{NSLocalizedDescriptionKey: @"O núcleo informou geometria ou cadência de áudio/vídeo inválida. A execução foi interrompida antes de usar esses valores."}];
        return NO;
    }
    _contentAspectRatio = avInfo.geometry.aspect_ratio;
    _screenManager.screens = brum::libretroScreens(_coreID.UTF8String, avInfo.geometry.base_width, avInfo.geometry.base_height);
    [_diagnostics enterStage:@"initialize_audio"];
    if (![self startAudio:avInfo.timing.sample_rate error:error]) return NO;
    [_diagnostics enterStage:@"first_frame"];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(runFrame)];
    [self configureDisplayCadence:avInfo.timing.fps];
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}

- (void)configureDisplayCadence:(double)framesPerSecond {
    _frameCadence.setRate(framesPerSecond);
    if (!_displayLink) return;
    const UIScreen *screen = self.view.window.screen ?: UIScreen.mainScreen;
    const double refresh = MAX(1, screen.maximumFramesPerSecond);
    const float preferred = (float)MIN(_frameCadence.rate(), refresh);
    if (@available(iOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(preferred, (float)refresh, preferred);
    } else {
        _displayLink.preferredFramesPerSecond = (NSInteger)llround(preferred);
    }
}

- (BOOL)startAudio:(double)sampleRate error:(NSError **)error {
    if (!_audioRing || !_audioCapacity) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:19 userInfo:@{NSLocalizedDescriptionKey: @"Não foi possível reservar o buffer de áudio. Encerre aplicativos que estejam usando memória e tente novamente."}];
        return NO;
    }
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
    _contentAspectRatio = info.geometry.aspect_ratio;
    _screenProfileWidth = 0;
    [self configureDisplayCadence:info.timing.fps];
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
        [self reportAudioFailure:[NSString stringWithFormat:@"ÁUDIO INDISPONÍVEL: %@", error.localizedDescription ?: @"falha ao mudar a taxa"]];
    }
}

- (void)runFrame {
    if (_stopped || !_gameLoaded || _paused) return;
    if (_shutdownRequested) { [self handleCoreShutdown]; return; }
    if (_hardwareInitialized) [EAGLContext setCurrentContext:_hardwareContext];
    const CFTimeInterval started = _performanceHUDEnabled ? CACurrentMediaTime() : 0;
    NSUInteger frameCount = _fastForwardEnabled ? 5 : _frameCadence.framesDue(CACurrentMediaTime());
    if (_hardwareInitialized && !_fastForwardEnabled && frameCount > 1) frameCount = 1;
    if (frameCount == 0) return;
    for (NSUInteger frame = 0; frame < frameCount; frame++) {
        _suppressVideo = frame + 1 < frameCount;
        _core.run();
        _input.tickLatches();
        if (!_pointerPressed && _pointerLatchFrames > 0) --_pointerLatchFrames;
        if (_raRuntime) _raRuntime->doFrame();
        if (_pokedexTracker) _pokedexTracker->doFrame();
        ++_sessionFrames;
        if (_performanceHUDEnabled) ++_measuredFrames;
        if (_shutdownRequested) break;
    }
    _suppressVideo = NO;
    if (_shutdownRequested) { [self handleCoreShutdown]; return; }
    [self applyPendingAVInfo];
    if (_videoCallbackCount == 120 && _nonBlackFrameCount == 0 && [_emulatedSystemID isEqualToString:@"psp"]) {
        os_unfair_lock_lock(&_audioLock);
        const uint64_t producedNow = _audioSamplesProduced;
        os_unfair_lock_unlock(&_audioLock);
        if (producedNow == 0 || _presentedFrames == 0) {
            [_diagnostics recordMessage:@"Aviso PPSSPP: 120 quadros sem vídeo visível ou áudio gerado." level:2];
            [self showStateStatus:@"PPSSPP sem vídeo — toque no logo para diagnóstico" error:YES];
            [self captureDiagnosticsMetrics];
            [_diagnostics checkpoint];
        }
    }
    if (!_readyDelivered && _presentedFrames > 0) {
        _readyDelivered = YES;
        [self captureDiagnosticsMetrics];
        [_diagnostics markRunning];
        if (_onReady) _onReady();
    }
    if (_performanceHUDEnabled) {
        const CFTimeInterval now = CACurrentMediaTime();
        _coreRunSeconds += now - started;
        if (_metricsStartedAt == 0) _metricsStartedAt = now;
        const CFTimeInterval elapsed = now - _metricsStartedAt;
        if (elapsed >= 1.0) {
            _statusLabel.hidden = NO;
            _statusLabel.alpha = 1;
            _statusLabel.text = [NSString stringWithFormat:@"  BRUM CORE · %.1f FPS · core+host %.1f ms · vídeo %.1f ms · térmico %ld  ",
                _measuredFrames / elapsed, _measuredFrames ? 1000.0 * _coreRunSeconds / _measuredFrames : 0,
                _measuredFrames ? 1000.0 * _hostVideoSeconds / _measuredFrames : 0,
                (long)NSProcessInfo.processInfo.thermalState];
            _metricsStartedAt = now;
            _coreRunSeconds = 0;
            _hostVideoSeconds = 0;
            _measuredFrames = 0;
        }
    }
}

- (void)startRetroAchievementsSession {
    const uint32_t consoleId = BrumRAConsoleIDForSystem(_emulatedSystemID);
    NSString *username = [BrumRASessionCredentials storedUsername];
    NSString *token = [BrumRASessionCredentials storedRuntimeToken];
    if (consoleId == 0 || !username.length || !token.length) return;

    __weak BrumLibretroViewController *weakSelf = self;
    brum::RetroAchievementsCallbacks cb;
    cb.userAgent = "BRUMCLASSICSMobile/0.24.0";
    cb.httpPost = [](const std::string &urlStr,
                     const std::string &postData,
                     const std::string &contentType,
                     brum::RetroAchievementsCallbacks::HttpDoneFn done) {
        NSString *nsUrl = [NSString stringWithUTF8String:urlStr.c_str()];
        NSURL *url = nsUrl ? [NSURL URLWithString:nsUrl] : nil;
        if (!url) {
            done(-1, "");
            return;
        }
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15.0];
        [req setValue:@"BRUMCLASSICSMobile/0.24.0" forHTTPHeaderField:@"User-Agent"];
        if (!postData.empty()) {
            req.HTTPMethod = @"POST";
            req.HTTPBody = [NSData dataWithBytes:postData.data() length:postData.size()];
            NSString *ct = contentType.empty() ? @"application/x-www-form-urlencoded" : [NSString stringWithUTF8String:contentType.c_str()];
            [req setValue:ct forHTTPHeaderField:@"Content-Type"];
        }
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *err) {
            if (err || ![response isKindOfClass:NSHTTPURLResponse.class]) {
                done(-2, "");
                return;
            }
            const NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
            std::string bodyStr;
            if (data.length > 0 && data.length <= 16 * 1024 * 1024) {
                bodyStr.assign((const char *)data.bytes, data.length);
            }
            done((int)statusCode, bodyStr);
        }];
        [task resume];
    };
    cb.getCoreMemory = [weakSelf](uint32_t memId, void **outData, size_t *outSize) {
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_gameLoaded || strongSelf->_stopped || !strongSelf->_core.getMemoryData || !strongSelf->_core.getMemorySize) {
            *outData = nullptr;
            *outSize = 0;
            return;
        }
        *outData = strongSelf->_core.getMemoryData(memId);
        *outSize = strongSelf->_core.getMemorySize(memId);
    };
    cb.onConfirmedUnlock = [weakSelf](const brum::ConfirmedAchievementUnlock &unlock) {
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_achievementOverlay) return;
        NSString *evt = [NSString stringWithUTF8String:unlock.eventId.c_str()] ?: @"";
        NSString *ach = [NSString stringWithFormat:@"%u", unlock.achievementId];
        NSString *title = [NSString stringWithUTF8String:unlock.title.c_str()] ?: @"Conquista desbloqueada";
        NSString *desc = [NSString stringWithUTF8String:unlock.description.c_str()] ?: @"";
        NSString *badge = unlock.badgeUrl.empty() ? nil : [NSString stringWithUTF8String:unlock.badgeUrl.c_str()];
        [strongSelf->_achievementOverlay enqueueUnlockWithEventID:evt
                                                   achievementID:ach
                                                           title:title
                                                          detail:desc
                                                          points:(NSInteger)unlock.points
                                                        badgeURL:badge];
    };
    cb.onStatusChanged = [weakSelf](const brum::RetroAchievementsStatus &status) {
        NSString *msg = status.message.empty() ? nil : [NSString stringWithUTF8String:status.message.c_str()];
        if (!msg.length) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            BrumLibretroViewController *strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_stopped) return;
            [strongSelf->_diagnostics recordMessage:[NSString stringWithFormat:@"RA: %@", msg] level:1];
        });
    };

    _raRuntime = std::make_unique<brum::RetroAchievementsRuntime>(std::move(cb));
    _raRuntime->loginWithToken(username.UTF8String, token.UTF8String);

    std::vector<retro_memory_descriptor> mapped;
    mapped.reserve(_memoryDescriptors.size());
    for (const auto &d : _memoryDescriptors) {
        retro_memory_descriptor item{};
        item.flags = d.flags;
        item.ptr = d.ptr;
        item.offset = d.offset;
        item.start = d.start;
        item.select = d.select;
        item.disconnect = d.disconnect;
        item.len = d.len;
        item.addrspace = d.addrspace;
        mapped.push_back(item);
    }
    retro_memory_map map{mapped.empty() ? nullptr : mapped.data(), (unsigned)mapped.size()};
    const char *romPath = _romURL.path.fileSystemRepresentation ?: "";
    _raRuntime->startGame(consoleId, romPath, (const uint8_t *)_romData.bytes, (size_t)_romData.length, mapped.empty() ? nullptr : &map);
}

- (void)startPokedexCaptureSession {
    _pokedexTracker.reset();
    if (!_romData || _romData.length < 0xC0) return;
    const auto romInfo = brum::pokedex::identifyFireRedRom((const uint8_t *)_romData.bytes, (size_t)_romData.length);
    if (!romInfo.isFireRed || !romInfo.supportedRamLayout) return;

    __weak BrumLibretroViewController *weakSelf = self;
    auto busReader = [weakSelf](uint32_t gbaAddress, uint8_t *outBuffer, size_t length) -> bool {
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_gameLoaded || strongSelf->_stopped || !outBuffer || length == 0) return false;
        for (const auto &desc : strongSelf->_memoryDescriptors) {
            if (!desc.ptr || desc.len == 0) continue;
            const size_t addr = (size_t)gbaAddress;
            if (addr >= desc.start && addr <= desc.start + desc.len && length <= (desc.start + desc.len - addr)) {
                memcpy(outBuffer, (const uint8_t *)desc.ptr + (addr - desc.start), length);
                return true;
            }
        }
        if (strongSelf->_core.getMemoryData && strongSelf->_core.getMemorySize) {
            const void *sysRam = strongSelf->_core.getMemoryData(BRUM_RETRO_MEMORY_SYSTEM_RAM);
            const size_t sysSize = strongSelf->_core.getMemorySize(BRUM_RETRO_MEMORY_SYSTEM_RAM);
            if (sysRam && sysSize >= 0x40000 && gbaAddress >= 0x02000000u && gbaAddress < 0x02040000u &&
                length <= (size_t)(0x02040000u - gbaAddress)) {
                memcpy(outBuffer, (const uint8_t *)sysRam + (gbaAddress - 0x02000000u), length);
                return true;
            }
        }
        return false;
    };

    auto onCapture = [weakSelf](const brum::pokedex::FireRedCaptureEvent &ev) {
        BrumLibretroViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *loc = [NSString stringWithUTF8String:ev.metLocationName.c_str()] ?: @"Localização desconhecida";
        NSString *src = [NSString stringWithUTF8String:ev.storageSource.c_str()] ?: @"party";
        NSString *code = [NSString stringWithUTF8String:ev.gameCode.c_str()] ?: @"BPRE";
        NSDictionary *info = @{
            @"nationalDexNumber": @((NSInteger)ev.nationalDexNumber),
            @"isShiny": @(ev.isShiny),
            @"category": ev.isShiny ? @"shiny" : @"normal",
            @"captureLocation": loc,
            @"storageSource": src,
            @"gameCode": code,
            @"romRevision": @((NSInteger)ev.romRevision),
            @"gameTitle": strongSelf->_gameTitle ?: @"Pokémon FireRed Version",
            @"canonicalGameID": strongSelf->_canonicalGameID ?: @"",
            @"systemID": strongSelf->_emulatedSystemID ?: @"gba"
        };
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:@"BrumPokedexCaptureDetectedNotification"
                                                              object:nil
                                                            userInfo:info];
        });
    };

    _pokedexTracker = std::make_unique<brum::pokedex::FireRedCaptureTracker>(romInfo, busReader, onCapture, 15u);
    void *saveRam = _core.getMemoryData ? _core.getMemoryData(BRUM_RETRO_MEMORY_SAVE_RAM) : nullptr;
    size_t saveSize = _core.getMemorySize ? _core.getMemorySize(BRUM_RETRO_MEMORY_SAVE_RAM) : 0;
    if (saveRam && saveSize >= 0xE000) {
        const auto snap = brum::pokedex::inspectFireRedSave128K((const uint8_t *)saveRam, saveSize);
        if (snap.valid) {
            _pokedexTracker->seedBaselineFromSave(snap);
        }
    }
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
    // stopCore is also called after startup failure. Exiting the UI remains
    // possible in that state, and delivers the frontend callback only once.
    if (_exitDelivered) return;
    _exitDelivered = YES;
    [self stopCore];
    if (_onExit) _onExit();
}

- (void)handleCoreShutdown {
    if (_stopped) return;
    [_displayLink invalidate]; _displayLink = nil;
    if (_raRuntime) {
        _raRuntime->unloadGame();
        _raRuntime.reset();
    }
    _pokedexTracker.reset();
    [_achievementOverlay invalidate];
    _startupError = [NSError errorWithDomain:BrumLibretroErrorDomain code:18 userInfo:@{NSLocalizedDescriptionKey: @"O núcleo interrompeu o jogo. Consulte o aviso registrado no relatório para identificar a causa."}];
    [self captureDiagnosticsMetrics];
    [_diagnostics recordFailure:_startupError.localizedDescription];
    [self stopCore];
    _exitFallbackButton.hidden = NO;
    _statusLabel.text = @"O NÚCLEO INTERROMPEU O JOGO";
    _statusLabel.textColor = UIColor.systemRedColor;
    _statusLabel.hidden = NO;
    _statusLabel.alpha = 1;
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:^{ [self showStartupFailure]; }];
    } else { [self showStartupFailure]; }
}

- (void)stopCore {
    if (_stopped) return;
    _stopped = YES;
    _hasPendingAVInfo = NO;
    _input.clear();
    [self releaseVirtualControls];
    [_primaryDPad reset];
    [_secondaryDPad reset];
    _pointerPressed = NO;
    _pointerLatchFrames = 0;
    [self captureDiagnosticsMetrics];
    [_diagnostics markStopped];
    [_displayLink invalidate]; _displayLink = nil;
    if (_raRuntime) {
        _raRuntime->unloadGame();
        _raRuntime.reset();
    }
    _pokedexTracker.reset();
    [_achievementOverlay invalidate];
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

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // A full-screen sharing sheet is not the end of the game session.
    if (!self.presentedViewController) [self stopCore];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopCore];
    if (_coreHandle) dlclose(_coreHandle);
    if (_rgbColorSpace) { CGColorSpaceRelease(_rgbColorSpace); _rgbColorSpace = NULL; }
    free(_audioRing);
}

@end

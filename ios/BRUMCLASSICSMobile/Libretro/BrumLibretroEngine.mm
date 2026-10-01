#import "BrumLibretroEngine.h"
#import "BrumLibretroAPI.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CommonCrypto/CommonDigest.h>
#import <GameController/GameController.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <math.h>
#import <os/lock.h>
#import <stdlib.h>
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
    unsigned _pixelFormat;
    uint32_t _inputMask;
    CADisplayLink *_displayLink;
    UIImageView *_screen;
    UILabel *_statusLabel;
    UIButton *_fastForwardButton;
    UIButton *_displayModeButton;
    UIButton *_stateButton;
    NSURL *_romURL;
    NSData *_romData;
    NSString *_gameTitle;
    NSString *_systemDirectory;
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
    NSString *_saveIdentifier;
    NSString *_legacySaveBasename;
    NSMutableDictionary<NSString *, NSString *> *_variables;
    BrumEmulatorExitHandler _onExit;
    NSError *_startupError;
    AudioQueueRef _audioQueue;
    int16_t *_audioRing;
    size_t _audioCapacity;
    size_t _audioRead;
    size_t _audioWrite;
    size_t _audioCount;
    os_unfair_lock _audioLock;
}

- (void)closeEmulator;
- (void)stopCore;
- (void)persistSaveRAM;
- (void)updateDisplayModeButton;
- (void)showStateMenu;
- (void)saveStateAtSlot:(NSInteger)slot;
- (void)loadStateAtSlot:(NSInteger)slot;
- (void)showStateStatus:(NSString *)text error:(BOOL)error;
@end

static void *BrumLoadSymbol(void *handle, const char *name) {
    dlerror();
    return dlsym(handle, name);
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
        case BRUM_RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
            *(const char **)data = host->_saveDirectory.fileSystemRepresentation;
            return true;
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
                if (key.length && value.length) host->_variables[key] = value;
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
        case BRUM_RETRO_ENVIRONMENT_SET_MESSAGE: {
            const brum_retro_message *message = (const brum_retro_message *)data;
            if (message && message->msg) {
                NSString *text = [NSString stringWithUTF8String:message->msg];
                dispatch_async(dispatch_get_main_queue(), ^{ host->_statusLabel.text = text; });
            }
            return true;
        }
        case BRUM_RETRO_ENVIRONMENT_SHUTDOWN: {
            dispatch_async(dispatch_get_main_queue(), ^{ [host closeEmulator]; });
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
    if (!host || host->_suppressVideo || !data || data == BrumHardwareFrameBuffer || !width || !height) return;
    NSMutableData *pixels = [NSMutableData dataWithLength:(NSUInteger)width * height * 4];
    uint32_t *target = (uint32_t *)pixels.mutableBytes;
    for (unsigned y = 0; y < height; y++) {
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
        host->_screen.layer.contents = (__bridge id)image;
        host->_screen.layer.contentsGravity = host->_screenFillsDisplay ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
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

static void BrumInputPoll(void) {}

static int16_t BrumInputState(unsigned port, unsigned device, unsigned index, unsigned identifier) {
    BrumLibretroViewController *host = BrumCurrentHost;
    if (!host || port != 0 || device != BRUM_RETRO_DEVICE_JOYPAD || index != 0 || identifier > 15) return 0;
    BOOL pressed = (host->_inputMask & (1u << identifier)) != 0;
    GCExtendedGamepad *gamepad = GCController.controllers.firstObject.extendedGamepad;
    if (gamepad) {
        switch (identifier) {
            case BRUM_RETRO_DEVICE_ID_JOYPAD_UP: pressed |= gamepad.dpad.up.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_DOWN: pressed |= gamepad.dpad.down.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_LEFT: pressed |= gamepad.dpad.left.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_RIGHT: pressed |= gamepad.dpad.right.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_A: pressed |= gamepad.buttonA.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_B: pressed |= gamepad.buttonB.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_START: pressed |= gamepad.buttonMenu.isPressed; break;
            case BRUM_RETRO_DEVICE_ID_JOYPAD_SELECT:
                if (@available(iOS 13.0, *)) pressed |= gamepad.buttonOptions.isPressed;
                break;
            default: break;
        }
    }
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
    _saveIdentifier = [saveIdentifier copy];
    _legacySaveBasename = [legacySaveBasename copy];
    _onExit = [onExit copy];
    _variables = [NSMutableDictionary dictionary];
    _pixelFormat = BRUM_RETRO_PIXEL_FORMAT_0RGB1555;
    _screenFillsDisplay = YES;
    _audioLock = OS_UNFAIR_LOCK_INIT;
    _audioCapacity = 262144;
    _audioRing = (int16_t *)calloc(_audioCapacity, sizeof(int16_t));
    NSError *startupError = nil;
    if (![self prepareDirectories:&startupError] || ![self loadCore:&startupError]) _startupError = startupError;
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
    NSString *saveName = [_contentSHA256 stringByAppendingPathExtension:@"srm"];
    _savePath = [[saves URLByAppendingPathComponent:saveName] path];
    _saveManifestPath = [[saves URLByAppendingPathComponent:[_contentSHA256 stringByAppendingPathExtension:@"save.json"]] path];

    // Releases anteriores usavam somente o nome do arquivo. Copiamos o save
    // antigo uma única vez; nunca o apagamos, para que a migração seja reversível.
    NSString *legacyName = [_legacySaveBasename stringByAppendingPathExtension:@"srm"];
    NSString *legacyPath = [[savesRoot URLByAppendingPathComponent:legacyName] path];
    NSFileManager *manager = NSFileManager.defaultManager;
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
        _statusLabel.text = error.localizedDescription ?: @"Não foi possível iniciar o jogo.";
        _statusLabel.textColor = UIColor.systemRedColor;
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    [self persistSaveRAM];
}

- (void)buildInterface {
    _screen = [[UIImageView alloc] init];
    _screen.translatesAutoresizingMaskIntoConstraints = NO;
    _screen.backgroundColor = [UIColor colorWithWhite:0.02 alpha:1];
    _screen.layer.magnificationFilter = kCAFilterNearest;
    _screen.clipsToBounds = YES;
    _screen.userInteractionEnabled = NO;
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
    _statusLabel.text = [NSString stringWithFormat:@"BRUM CORE · %@", _coreDisplayName];
    _statusLabel.textColor = [UIColor colorWithRed:0.62 green:1 blue:0.23 alpha:1];
    _statusLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    [self.view addSubview:_statusLabel];

    UIStackView *up = [self directionPad];
    UIStackView *actions = [self actionPad];
    UIStackView *menu = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self controlButton:@"SELECT" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_SELECT],
        [self controlButton:@"START" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_START]
    ]];
    menu.translatesAutoresizingMaskIntoConstraints = NO;
    menu.axis = UILayoutConstraintAxisHorizontal;
    menu.spacing = 10;
    [self.view addSubview:up]; [self.view addSubview:actions]; [self.view addSubview:menu];

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
        [menu.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [menu.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16]
    ]];
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

- (UIStackView *)actionPad {
    UIButton *b = [self controlButton:@"B" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_B];
    UIButton *a = [self controlButton:@"A" identifier:BRUM_RETRO_DEVICE_ID_JOYPAD_A];
    b.layer.cornerRadius = 31; a.layer.cornerRadius = 31;
    [b.widthAnchor constraintEqualToConstant:62].active = YES; [b.heightAnchor constraintEqualToConstant:62].active = YES;
    [a.widthAnchor constraintEqualToConstant:62].active = YES; [a.heightAnchor constraintEqualToConstant:62].active = YES;
    UIStackView *pad = [[UIStackView alloc] initWithArrangedSubviews:@[b, a]];
    pad.translatesAutoresizingMaskIntoConstraints = NO; pad.axis = UILayoutConstraintAxisHorizontal; pad.spacing = 18;
    return pad;
}

- (void)inputDown:(UIButton *)sender { if (sender.tag >= 0) _inputMask |= 1u << sender.tag; }
- (void)inputUp:(UIButton *)sender { if (sender.tag >= 0) _inputMask &= ~(1u << sender.tag); }

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
    if (!_gameLoaded || _stopped) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"ESTADOS RÁPIDOS"
                                                                   message:@"O save normal continua separado. Escolha um dos três slots locais."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger slot = 1; slot <= 3; slot++) {
        NSInteger selected = slot;
        [menu addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Salvar no slot %ld", (long)slot]
                                                 style:UIAlertActionStyleDefault
                                               handler:^(__unused UIAlertAction *action) { [self saveStateAtSlot:selected]; }]];
        UIAlertAction *load = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Carregar slot %ld", (long)slot]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(__unused UIAlertAction *action) { [self loadStateAtSlot:selected]; }];
        load.enabled = [NSFileManager.defaultManager fileExistsAtPath:[self statePathForSlot:slot]];
        [menu addAction:load];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
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
    _romData = [NSData dataWithContentsOfURL:_romURL options:NSDataReadingMappedIfSafe error:error];
    if (!_romData) return NO;
    brum_retro_game_info gameInfo = {};
    gameInfo.path = _romURL.path.fileSystemRepresentation;
    if (!systemInfo.need_fullpath) { gameInfo.data = _romData.bytes; gameInfo.size = _romData.length; }
    if (!_core.loadGame(&gameInfo)) {
        if (error) *error = [NSError errorWithDomain:BrumLibretroErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"O núcleo %@ recusou este arquivo. Confirme que a ROM é válida para %@.", _coreDisplayName, _emulatedSystemID.uppercaseString]}];
        return NO;
    }
    _gameLoaded = YES;
    [self restoreSaveRAM];
    brum_retro_system_av_info avInfo = {};
    _core.getAVInfo(&avInfo);
    [self startAudio:avInfo.timing.sample_rate];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(runFrame)];
    if (@available(iOS 15.0, *)) {
        float fps = (float)MAX(30.0, MIN(120.0, avInfo.timing.fps));
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
    } else { _displayLink.preferredFramesPerSecond = (NSInteger)llround(avInfo.timing.fps); }
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}

- (void)startAudio:(double)sampleRate {
    if (sampleRate <= 0) return;
    AudioStreamBasicDescription format = {};
    format.mSampleRate = sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBytesPerPacket = 4; format.mFramesPerPacket = 1; format.mBytesPerFrame = 4;
    format.mChannelsPerFrame = 2; format.mBitsPerChannel = 16;
    if (AudioQueueNewOutput(&format, BrumAudioQueueOutput, (__bridge void *)self, NULL, NULL, 0, &_audioQueue) != noErr) return;
    for (NSUInteger index = 0; index < 3; index++) {
        AudioQueueBufferRef buffer = NULL;
        if (AudioQueueAllocateBuffer(_audioQueue, 8192, &buffer) == noErr) {
            memset(buffer->mAudioData, 0, 8192); buffer->mAudioDataByteSize = 8192;
            AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
        }
    }
    AudioQueueStart(_audioQueue, NULL);
}

- (void)runFrame {
    if (_stopped || !_gameLoaded) return;
    NSUInteger frameCount = _fastForwardEnabled ? 5 : 1;
    for (NSUInteger frame = 0; frame < frameCount; frame++) {
        _suppressVideo = frame + 1 < frameCount;
        _core.run();
    }
    _suppressVideo = NO;
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

- (void)stopCore {
    if (_stopped) return;
    _stopped = YES;
    [_displayLink invalidate]; _displayLink = nil;
    if (_audioQueue) { AudioQueueStop(_audioQueue, true); AudioQueueDispose(_audioQueue, true); _audioQueue = NULL; }
    [self persistSaveRAM];
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

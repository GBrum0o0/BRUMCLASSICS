#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, BrumInputSource) {
    BrumInputVirtualPad, BrumInputController, BrumInputKeyboard, BrumInputRemote,
};
typedef NS_OPTIONS(NSUInteger, BrumBackendCapabilities) {
    BrumBackendVideo = 1 << 0,
    BrumBackendAudio = 1 << 1,
    BrumBackendController = 1 << 2,
    BrumBackendTouch = 1 << 3,
    BrumBackendMultipleScreens = 1 << 4,
    BrumBackendSave = 1 << 5,
    BrumBackendSaveState = 1 << 6,
    BrumBackendFastForward = 1 << 7,
    BrumBackendAchievements = 1 << 8,
    BrumBackendRewind = 1 << 9,
    BrumBackendStreaming = 1 << 10,
    BrumBackendRemoteInput = 1 << 11,
};

// A prepared session owns a game identity, configuration and save directory.
// Calls are serialized on the main/session thread by the iOS frontend.
// Optional features are advertised only after the loaded backend negotiates them.
@protocol BrumBackendSession <NSObject>
@property(nonatomic, readonly) BrumBackendCapabilities capabilities;
@property(nonatomic, readonly, getter=isPaused) BOOL paused;
- (BOOL)startCore:(NSError * _Nullable * _Nullable)error;
- (void)runFrame;
- (void)pause;
- (void)resume;
- (void)stopCore;
// Standard 16-button joypad order. Call on the session thread. Releasing one
// source preserves the others; keyboard/remote transports are not yet wired.
- (void)setButton:(NSUInteger)button source:(BrumInputSource)source pressed:(BOOL)pressed;
- (void)releaseInputSource:(BrumInputSource)source;
- (void)setAnalogStick:(NSUInteger)stick axis:(NSUInteger)axis value:(double)value source:(BrumInputSource)source;
- (void)persistSaveRAM;
- (void)saveStateAtSlot:(NSInteger)slot;
- (void)loadStateAtSlot:(NSInteger)slot;
@end
NS_ASSUME_NONNULL_END

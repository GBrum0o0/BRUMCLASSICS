#import <UIKit/UIKit.h>
#import "BrumBackend.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^BrumEmulatorExitHandler)(void);
typedef void (^BrumEmulatorReadyHandler)(void);

@interface BrumLibretroViewController : UIViewController <BrumBackendSession>

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
                        onExit:(BrumEmulatorExitHandler)onExit NS_DESIGNATED_INITIALIZER;

@property(nonatomic, readonly) NSString *diagnosticsReport;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                          bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

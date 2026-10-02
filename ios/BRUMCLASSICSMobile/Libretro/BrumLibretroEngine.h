#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BrumEmulatorExitHandler)(void);

@interface BrumLibretroViewController : UIViewController

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
                        onExit:(BrumEmulatorExitHandler)onExit NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                          bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BrumEmulatorExitHandler)(void);

@interface BrumLibretroViewController : UIViewController

- (instancetype)initWithROMURL:(NSURL *)romURL
                         title:(NSString *)title
                        onExit:(BrumEmulatorExitHandler)onExit NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                          bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

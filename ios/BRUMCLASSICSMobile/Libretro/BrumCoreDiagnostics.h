#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Local, bounded startup evidence. No network transport or ROM/firmware bytes.
@interface BrumCoreDiagnostics : NSObject
- (instancetype)initWithContext:(NSDictionary<NSString *, id> *)context
                      reportURL:(nullable NSURL *)reportURL
                  redactedPaths:(NSArray<NSString *> *)redactedPaths;
- (void)enterStage:(NSString *)stage;
- (void)recordMessage:(NSString *)message level:(NSInteger)level;
- (void)recordFailure:(NSString *)message;
- (void)markRunning;
- (void)markStopped;
- (void)setMetrics:(NSDictionary<NSString *, NSNumber *> *)metrics;
@property(nonatomic, readonly) NSDictionary<NSString *, id> *snapshot;
@property(nonatomic, readonly) NSString *reportText;
@property(nonatomic, readonly) NSString *failureDetail;
@end

NS_ASSUME_NONNULL_END

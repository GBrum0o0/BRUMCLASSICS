#import "BrumCoreDiagnostics.h"

@implementation BrumCoreDiagnostics {
    NSDictionary *_context;
    NSURL *_reportURL;
    NSArray<NSString *> *_redactedPaths;
    NSMutableArray<NSDictionary *> *_messages;
    NSDictionary *_metrics;
    NSString *_stage;
    NSString *_outcome;
    NSString *_failure;
    NSString *_attemptID;
    NSDate *_startedAt;
    NSDictionary *_previousAttempt;
    NSString *_lastError;
    NSString *_lastWarning;
}

- (instancetype)initWithContext:(NSDictionary<NSString *,id> *)context reportURL:(NSURL *)reportURL redactedPaths:(NSArray<NSString *> *)redactedPaths {
    self = [super init];
    if (!self) return nil;
    _context = [context copy];
    _reportURL = reportURL;
    _redactedPaths = [redactedPaths sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return a.length > b.length ? NSOrderedAscending : a.length < b.length ? NSOrderedDescending : NSOrderedSame;
    }];
    _messages = [NSMutableArray array];
    _metrics = @{};
    _stage = @"prepare_directories";
    _outcome = @"starting";
    _attemptID = NSUUID.UUID.UUIDString;
    _startedAt = NSDate.date;
    NSData *data = reportURL ? [NSData dataWithContentsOfURL:reportURL] : nil;
    NSDictionary *previous = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if ([previous isKindOfClass:NSDictionary.class] && [previous[@"schemaVersion"] isEqual:@1]) {
        // Preserve only a compact previous marker, never a recursively nested report.
        NSMutableDictionary *marker = [NSMutableDictionary dictionary];
        for (NSString *key in @[@"attemptID", @"stage", @"outcome", @"startedAt"]) {
            if ([previous[key] isKindOfClass:NSString.class]) marker[key] = previous[key];
        }
        _previousAttempt = [marker copy];
    }
    [self persist];
    return self;
}

- (NSString *)sanitized:(NSString *)text {
    NSString *result = text;
    for (NSString *path in _redactedPaths) {
        if (path.length) result = [result stringByReplacingOccurrencesOfString:path withString:@"<local>"];
    }
    if (result.length <= 2048) return result;
    NSUInteger length = 2048;
    unichar last = [result characterAtIndex:length - 1];
    if (last >= 0xD800 && last <= 0xDBFF) --length;
    return [result substringToIndex:length];
}

- (void)enterStage:(NSString *)stage {
    @synchronized (self) {
        if ([_outcome isEqualToString:@"failed"] || [_outcome isEqualToString:@"stopped"]) return;
        _stage = [stage copy];
        [self persist];
    }
}

- (void)recordMessage:(NSString *)message level:(NSInteger)level {
    if (!message.length) return;
    @synchronized (self) {
        // Ignore debug chatter; warnings/errors remain available even when the
        // core exits. No filesystem work from native worker/log callbacks.
        if (level < 1) return;
        NSString *text = [self sanitized:message];
        if (level >= 3) _lastError = text;
        else if (level == 2) _lastWarning = text;
        NSDictionary *last = _messages.lastObject;
        if ([last[@"text"] isEqualToString:text] && [last[@"level"] integerValue] == level) return;
        [_messages addObject:@{@"level": @(level), @"text": text, @"stage": _stage}];
        if (_messages.count > 32) [_messages removeObjectAtIndex:0];
    }
}

- (void)recordFailure:(NSString *)message {
    @synchronized (self) {
        _outcome = @"failed";
        _failure = [self sanitized:message];
        [self persist];
    }
}

- (void)markRunning {
    @synchronized (self) {
        if (![_outcome isEqualToString:@"starting"]) return;
        _stage = @"running";
        _outcome = @"running";
        [self persist];
    }
}

- (void)markStopped {
    @synchronized (self) {
        // Resource teardown must not erase the cause/phase of a failed start.
        if (![_outcome isEqualToString:@"failed"]) _outcome = @"stopped";
        [self persist];
    }
}

- (void)setMetrics:(NSDictionary<NSString *,NSNumber *> *)metrics {
    @synchronized (self) { _metrics = [metrics copy]; }
}

- (NSDictionary<NSString *,id> *)snapshot {
    @synchronized (self) {
        NSMutableDictionary *report = [NSMutableDictionary dictionaryWithDictionary:@{
            @"schemaVersion": @1, @"attemptID": _attemptID, @"context": _context,
            @"stage": _stage, @"outcome": _outcome, @"messages": [_messages copy], @"metrics": _metrics,
            @"startedAt": [NSISO8601DateFormatter stringFromDate:_startedAt timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0] formatOptions:NSISO8601DateFormatWithInternetDateTime]
        }];
        if (_failure) report[@"failure"] = _failure;
        if (_lastError) report[@"lastCoreError"] = _lastError;
        if (_lastWarning) report[@"lastCoreWarning"] = _lastWarning;
        if (_previousAttempt) report[@"previousAttempt"] = _previousAttempt;
        return report;
    }
}

- (NSString *)failureDetail {
    @synchronized (self) {
        return _lastError ?: _lastWarning ?: @"";
    }
}

- (NSString *)reportText {
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.snapshot options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"Relatório indisponível.";
}

- (void)persist {
    if (!_reportURL) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.snapshot options:NSJSONWritingSortedKeys error:nil];
    if (!data) return;
    NSFileManager *manager = NSFileManager.defaultManager;
    [manager createDirectoryAtURL:_reportURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    [data writeToURL:_reportURL options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:nil];
}
@end

#import "ITXPerf.h"
#import "ITXPrefs.h"
#import "ITXLog.h"
#import <objc/message.h>

static CFAbsoluteTime sLaunchTime = 0;
static NSTimeInterval sLaunchCost = 0;

void ITXPerfMarkLaunch(void) {
    sLaunchTime = CFAbsoluteTimeGetCurrent();
}

void ITXPerfReportFirstFrame(void) {
    if (sLaunchTime <= 0 || sLaunchCost > 0) return;
    sLaunchCost = (CFAbsoluteTimeGetCurrent() - sLaunchTime) * 1000.0;
    ITXLog(@"首帧就绪：%.0f ms（插件加载 → 首个页面出现）", sLaunchCost);
}

NSTimeInterval ITXPerfLaunchCost(void) {
    return sLaunchCost;
}

void ITXDeferReinvoke(id target, SEL sel, NSTimeInterval delay) {
    if (!target || !sel) return;
    if (delay < 0) delay = 0;

    __weak id weakTarget = target;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong id strongTarget = weakTarget;
        if (!strongTarget) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [strongTarget performSelector:sel];
#pragma clang diagnostic pop
    });
}

#pragma mark - 图片并发

/// 只在当前值比上限更大（或为 0，即“不限制”）时才压到上限
static void ITXCapNumber(id object, NSString *key, double cap) {
    if (!object || key.length == 0) return;
    @try {
        NSNumber *current = [object valueForKey:key];
        if (![current isKindOfClass:[NSNumber class]]) return;
        double value = current.doubleValue;
        if (value > 0 && value <= cap) return;
        [object setValue:@(cap) forKey:key];
    } @catch (__unused NSException *e) {
    }
}

void ITXPerfApplyImageLimits(void) {
    if (!ITXOn(ITXKeyImageLimit)) return;

    static BOOL done = NO;
    if (done) return;
    done = YES;

    const NSInteger kMaxDownloads = 4;
    const NSInteger kMaxPrefetch = 2;
    const NSUInteger kMaxMemoryCost = 64 * 1024 * 1024;
    const NSInteger kMaxMemoryCount = 200;

    @try {
        Class downloaderClass = NSClassFromString(@"SDWebImageDownloader");
        if (downloaderClass) {
            id downloader = ((id (*)(id, SEL))objc_msgSend)(downloaderClass,
                                                           @selector(sharedDownloader));
            id config = [downloader valueForKey:@"config"];
            ITXCapNumber(config, @"maxConcurrentDownloads", kMaxDownloads);
            // downloader 初始化时把 config 的值同步到了队列，这里补一次才真正生效
            id downloadQueue = [downloader valueForKey:@"downloadQueue"];
            @try {
                [downloadQueue setValue:@(kMaxDownloads) forKey:@"maxConcurrentOperationCount"];
            } @catch (__unused NSException *e) {
            }
        }

        Class prefetcherClass = NSClassFromString(@"SDWebImagePrefetcher");
        if (prefetcherClass) {
            id prefetcher = ((id (*)(id, SEL))objc_msgSend)(prefetcherClass,
                                                           @selector(sharedImagePrefetcher));
            ITXCapNumber(prefetcher, @"maxConcurrentPrefetchCount", kMaxPrefetch);
        }

        Class cacheClass = NSClassFromString(@"SDImageCache");
        if (cacheClass) {
            id cache = ((id (*)(id, SEL))objc_msgSend)(cacheClass, @selector(sharedImageCache));
            id config = [cache valueForKey:@"config"];
            ITXCapNumber(config, @"maxMemoryCost", kMaxMemoryCost);
            ITXCapNumber(config, @"maxMemoryCount", kMaxMemoryCount);
            // NSCache 的上限由 SDImageCache 内部同步，这里补一次
            id memoryCache = [cache valueForKey:@"memoryCache"];
            @try {
                [memoryCache setValue:@(kMaxMemoryCost) forKey:@"totalCostLimit"];
                [memoryCache setValue:@(kMaxMemoryCount) forKey:@"countLimit"];
            } @catch (__unused NSException *e) {
            }
        }
        ITXLog(@"图片并发已限制：下载 %ld 路 / 预取 %ld 路 / 内存 %lu MB",
               (long)kMaxDownloads, (long)kMaxPrefetch, (unsigned long)(kMaxMemoryCost / 1024 / 1024));
    } @catch (NSException *e) {
        ITXLog(@"图片并发设置失败：%@", e.reason);
    }
}

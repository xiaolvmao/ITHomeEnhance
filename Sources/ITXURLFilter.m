#import "ITXURLFilter.h"
#import "ITXPrefs.h"
#import "ITXLog.h"

static BOOL ITXHostMatches(NSString *host, NSArray<NSString *> *suffixes) {
    for (NSString *suffix in suffixes) {
        if ([host isEqualToString:suffix]) return YES;
        if ([host hasSuffix:[@"." stringByAppendingString:suffix]]) return YES;
    }
    return NO;
}

NSURL *ITXBlockedURLPlaceholder(void) {
    static NSURL *url;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        url = [NSURL URLWithString:@"https://127.0.0.1:1/itx-blocked"];
    });
    return url;
}

BOOL ITXShouldBlockURLString(NSString *urlString) {
    if (urlString.length < 8) return NO;

    // 热路径：先用字符串预筛，绝大多数正常请求在这里就返回了
    static NSArray<NSString *> *hints;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hints = @[
            @"gdt.qq.com", @"appsplash", @"umeng", @"umsns", @"umops",
            @"dat.ruanmei.com", @"mmstat.com", @"trace.qq.com",
            @"orbit.jd.com", @"bdsp.x.jd.com", @"puata.info", @"union.ruanmei.com",
            @"mall.ithome.com", @"shop.asmx", @"getshopsignforios",
        ];
    });
    BOOL maybe = NO;
    for (NSString *hint in hints) {
        if ([urlString rangeOfString:hint].location != NSNotFound) {
            maybe = YES;
            break;
        }
    }
    if (!maybe) return NO;

    NSURLComponents *comps = [NSURLComponents componentsWithString:urlString];
    NSString *host = comps.host.lowercaseString;
    if (host.length == 0) return NO;
    NSString *path = comps.path ?: @"";

    // ---- 开屏广告接口 ----
    if (ITXOn(ITXKeyLaunchAd) || ITXOn(ITXKeyAdHost)) {
        if ([host isEqualToString:@"napi.ithome.com"] && [path containsString:@"/api/appsplash/get"]) {
            return YES;
        }
    }

    // ---- 广告投放/素材域名 ----
    if (ITXOn(ITXKeyAdHost)) {
        static NSArray<NSString *> *adHosts;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            adHosts = @[
                @"mi.gdt.qq.com",       // 广点通 H5 广告
                @"v.gdt.qq.com",
                @"union.ruanmei.com",   // 睿美广告跳转
                @"c.umsns.com",
            ];
        });
        if (ITXHostMatches(host, adHosts)) return YES;
    }

    // ---- 信息流广告 ----
    if (ITXOn(ITXKeyFeedAd)) {
        if ([host isEqualToString:@"mi.gdt.qq.com"] || [host isEqualToString:@"v.gdt.qq.com"]) {
            return YES;
        }
    }

    // ---- 商城模块 ----
    if (ITXOn(ITXKeyHideMall)) {
        if ([host isEqualToString:@"mall.ithome.com"]) return YES;
        if ([host hasSuffix:@"ruanmei.com"] && [path hasPrefix:@"/api/shop.asmx"]) return YES;
        if ([host isEqualToString:@"napi.ithome.com"] && [path containsString:@"/getshopsignforios"]) return YES;
    }

    // ---- 埋点/统计上报 ----
    if (ITXOn(ITXKeyBlockStats)) {
        static NSArray<NSString *> *statHosts;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            statHosts = @[
                @"umeng.com",
                @"umengcloud.com",
                @"umsns.com",
                @"umops.com",
                @"dat.ruanmei.com",
                @"wgo.mmstat.com",
                @"h.trace.qq.com",
                @"orbit.jd.com",
                @"bdsp.x.jd.com",
                @"yumao.puata.info",
            ];
        });
        if (ITXHostMatches(host, statHosts)) return YES;
    }

    return NO;
}

NSURL *ITXRewriteURL(NSURL *url) {
    if (!url) return nil;
    if (ITXShouldBlockURLString(url.absoluteString)) {
        // 同一域名只记前几条，避免刷日志、减少 IO
        static NSMutableDictionary<NSString *, NSNumber *> *counts;
        static NSLock *lock;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            counts = [NSMutableDictionary dictionary];
            lock = [NSLock new];
        });
        NSString *host = url.host ?: @"?";
        [lock lock];
        NSInteger n = counts[host].integerValue;
        counts[host] = @(n + 1);
        [lock unlock];
        if (n < 3) {
            ITXLog(@"拦截请求 %@%@", host, url.path ?: @"");
        }
        return ITXBlockedURLPlaceholder();
    }
    return url;
}

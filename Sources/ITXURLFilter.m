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

    // 只解析一次，避免每个请求都建 NSURL
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
        ITXLog(@"拦截请求 %@", [url.host stringByAppendingString:url.path ?: @""]);
        return ITXBlockedURLPlaceholder();
    }
    return url;
}

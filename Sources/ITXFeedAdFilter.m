//
//  ITXFeedAdFilter.m
//

#import "ITXFeedAdFilter.h"
#import "ITXLog.h"
#import "ITXPrefs.h"
#import <objc/message.h>
#import <objc/runtime.h>

// 已知的推广落地页 host，作为 isAd 没标出来时的兜底判断
static NSArray<NSString *> *ITXPromotionHosts(void) {
    static NSArray<NSString *> *hosts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hosts = @[
            @"mall.ithome.com",
            @"union.ruanmei.com",
            @"item.jd.com",
            @"u.jd.com",
            @"3.cn",
            @"s.click.taobao.com",
            @"uland.taobao.com",
            @"item.taobao.com",
            @"detail.tmall.com",
            @"p.pinduoduo.com",
            @"mobile.yangkeduo.com",
        ];
    });
    return hosts;
}

static NSString *ITXStringFromObject(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try {
        id v = [obj valueForKey:key];
        if ([v isKindOfClass:[NSString class]]) return v;
    } @catch (__unused NSException *e) {
    }
    return nil;
}

BOOL ITXObjectIsAd(id obj) {
    if (!obj) return NO;

    // ITNewsModel / Feed / RMNewsCarouseFeedItemModel 上的广告标记。
    // isAd 是服务端直接下发的；isDaogou 是「辣品导购」这类带货条目，
    // 在首页同样是推广位，一并处理。
    static SEL sIsAd, sIsDaogou;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sIsAd = sel_registerName("isAd");
        sIsDaogou = sel_registerName("isDaogou");
    });

    // 用 respondsToSelector 而不是读 ivar，免得漏掉声明在父类上的情况
    SEL flags[2] = {sIsAd, sIsDaogou};
    for (int i = 0; i < 2; i++) {
        SEL sel = flags[i];
        if (!sel || ![obj respondsToSelector:sel]) continue;
        @try {
            BOOL flag = ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
            if (flag) return YES;
        } @catch (__unused NSException *e) {
        }
    }

    // 兜底：链接指向已知推广域名
    NSString *link = ITXStringFromObject(obj, @"link");
    if (link.length > 6) {
        NSString *lower = link.lowercaseString;
        for (NSString *host in ITXPromotionHosts()) {
            if ([lower containsString:host]) return YES;
        }
    }
    return NO;
}

// 列表里的条目可能被包好几层：container → feedContent、section viewModel → contentModel、
// 模型盒子 → boxValueData。逐层拆到真正带数据的那一层再判断。
static id ITXUnwrapFeed(id feed) {
    id cur = feed;
    for (int depth = 0; depth < 4; depth++) {
        if (!cur) return nil;
        id next = nil;
        @try {
            if ([cur respondsToSelector:@selector(feedContent)]) {
                next = ((id (*)(id, SEL))objc_msgSend)(cur, @selector(feedContent));
            }
            if (!next && [cur respondsToSelector:@selector(contentModel)]) {
                next = ((id (*)(id, SEL))objc_msgSend)(cur, @selector(contentModel));
            }
            if (!next && [cur respondsToSelector:@selector(boxValueData)]) {
                next = ((id (*)(id, SEL))objc_msgSend)(cur, @selector(boxValueData));
            }
        } @catch (__unused NSException *e) {
            return cur;
        }
        if (!next || next == cur) return cur;
        cur = next;
    }
    return cur;
}

BOOL ITXFeedIsAd(id feed) {
    if (!feed) return NO;
    if (ITXObjectIsAd(feed)) return YES;
    id inner = ITXUnwrapFeed(feed);
    if (!inner || inner == feed) return NO;
    return ITXObjectIsAd(inner);
}

NSArray *ITXStripFeedAds(NSArray *list) {
    if (![list isKindOfClass:[NSArray class]] || list.count == 0) return list;

    // 第一次拿到非空列表时留一条痕迹，方便在「运行日志」里确认过滤已接管
    static BOOL announced;
    if (!announced) {
        announced = YES;
        ITXLog(@"信息流过滤已接管，当前 %lu 条", (unsigned long)list.count);
    }

    NSMutableArray *kept = nil;
    NSMutableArray<NSString *> *removed = nil;
    NSUInteger index = 0;
    for (id obj in list) {
        if (ITXFeedIsAd(obj)) {
            if (!kept) {
                kept = [NSMutableArray arrayWithArray:[list subarrayWithRange:NSMakeRange(0, index)]];
            }
            NSString *title = ITXStringFromObject(obj, @"title");
            if (title.length == 0) {
                title = ITXStringFromObject(ITXUnwrapFeed(obj), @"title");
            }
            if (!removed) removed = [NSMutableArray array];
            [removed addObject:title.length ? title : @"(无标题)"];
        } else if (kept) {
            [kept addObject:obj];
        }
        index++;
    }

    if (removed.count > 0) {
        // 列表刷新很频繁，合并成一条日志，只列前三条标题
        NSString *sample = [[removed subarrayWithRange:NSMakeRange(0, MIN(removed.count, 3))]
            componentsJoinedByString:@" | "];
        ITXLog(@"剔除 %lu 条信息流广告：%@", (unsigned long)removed.count, sample);
    }
    return kept ?: list;
}

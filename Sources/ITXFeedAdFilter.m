//
//  ITXFeedAdFilter.m
//

#import "ITXFeedAdFilter.h"
#import "ITXLog.h"
#import "ITXPrefs.h"
#import <objc/message.h>
#import <objc/runtime.h>

// 已知的推广落地页 host，作为标记字段没命中的兜底判断
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

// App 里广告标记的命名并不统一：
//   RMNewsArticleModel      -> isAdvertise（首页信息流真正用的模型）
//   ITNewsModel / Feed      -> isAd
//   ITLaunchAdModel         -> isad（小写 d）
//   Feed                    -> isDaogou（辣品导购，首页同样是推广位）
static NSArray<NSString *> *ITXAdFlagNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[@"isAdvertise", @"isAd", @"isad", @"isDaogou"];
    });
    return names;
}

// 有些推广位只在标签上体现（角标文案），兜底扫一遍标签
static BOOL ITXLabelsMarkAd(id obj) {
    static NSArray<NSString *> *labelKeys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        labelKeys = @[@"feedLabels", @"listTags", @"smallTags"];
    });

    for (NSString *key in labelKeys) {
        id value = nil;
        @try {
            value = [obj valueForKey:key];
        } @catch (__unused NSException *e) {
            continue;
        }
        if (![value isKindOfClass:[NSArray class]]) continue;

        for (id item in (NSArray *)value) {
            NSString *text = nil;
            if ([item isKindOfClass:[NSString class]]) {
                text = item;
            } else {
                text = ITXStringFromObject(item, @"title");
                if (text.length == 0) text = ITXStringFromObject(item, @"name");
            }
            if (text.length == 0 || text.length > 8) continue;
            if ([text containsString:@"广告"] || [text containsString:@"推广"] || [text containsString:@"赞助"]) {
                return YES;
            }
            if ([[text uppercaseString] isEqualToString:@"AD"]) return YES;
        }
    }
    return NO;
}

BOOL ITXObjectIsAd(id obj) {
    if (!obj) return NO;

    // 用 respondsToSelector 而不是读 ivar，免得漏掉声明在父类上的情况
    for (NSString *name in ITXAdFlagNames()) {
        SEL sel = sel_registerName(name.UTF8String);
        if (![obj respondsToSelector:sel]) continue;
        @try {
            BOOL flag = ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
            if (flag) return YES;
        } @catch (__unused NSException *e) {
        }
    }

    if (ITXLabelsMarkAd(obj)) return YES;

    // 兜底：链接指向已知推广域名
    NSString *link = ITXStringFromObject(obj, @"link");
    if (link.length == 0) link = ITXStringFromObject(obj, @"shareUrl");
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

    // 第一次拿到非空列表时留一条痕迹，方便在「运行日志」里确认过滤已接管；
    // 顺带记一下实际进来的模型类名，万一还有漏网的广告，凭这条就能定位。
    static BOOL announced;
    if (!announced) {
        announced = YES;
        NSMutableOrderedSet *classes = [NSMutableOrderedSet orderedSet];
        for (id obj in list) {
            [classes addObject:NSStringFromClass([obj class])];
            if (classes.count >= 8) break;
        }
        ITXLog(@"信息流过滤已接管，%lu 条，类型：%@",
               (unsigned long)list.count,
               [[classes array] componentsJoinedByString:@", "]);
    }

    NSMutableArray *kept = nil;
    NSMutableArray<NSString *> *removed = nil;
    NSUInteger index = 0;
    for (id obj in list) {
        if (ITXFeedIsAd(obj)) {
            if (!kept) {
                kept = [NSMutableArray arrayWithArray:[list subarrayWithRange:NSMakeRange(0, index)]];
            }
            id inner = ITXUnwrapFeed(obj);
            NSString *title = ITXStringFromObject(inner, @"title");
            if (title.length == 0) title = ITXStringFromObject(obj, @"title");
            if (!removed) removed = [NSMutableArray array];
            [removed addObject:[NSString stringWithFormat:@"%@(%@)", title.length ? title : @"无标题",
                                NSStringFromClass([(inner ?: obj) class])]];
        } else if (kept) {
            [kept addObject:obj];
        }
        index++;
    }

    if (removed.count > 0) {
        // 列表刷新很频繁，合并成一条日志，只列前三条
        NSString *sample = [[removed subarrayWithRange:NSMakeRange(0, MIN(removed.count, 3))]
            componentsJoinedByString:@" | "];
        ITXLog(@"剔除 %lu 条信息流广告：%@", (unsigned long)removed.count, sample);
    }
    return kept ?: list;
}

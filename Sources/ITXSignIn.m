#import "ITXSignIn.h"
#import "ITXPrefs.h"
#import "ITXLog.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>

static NSString *const kITXLastSignDate  = @"itx_lastSignDate";
static NSString *const kITXLastSignState = @"itx_lastSignState";

static BOOL sRunning = NO;

static NSString *ITXToday(void) {
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
    });
    return [fmt stringFromDate:[NSDate date]];
}

static NSString *ITXNow(void) {
    static NSDateFormatter *fmt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"MM-dd HH:mm";
    });
    return [fmt stringFromDate:[NSDate date]];
}

NSString *ITXSignInStatusText(void) {
    NSString *state = [[NSUserDefaults standardUserDefaults] stringForKey:kITXLastSignState];
    return state.length ? state : @"尚未执行";
}

static void ITXMarkState(NSString *state) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:[NSString stringWithFormat:@"%@ %@", ITXNow(), state] forKey:kITXLastSignState];
    [d synchronize];
    ITXLog(@"签到状态：%@", state);
}

#pragma mark - 原生自动签到流程

static BOOL ITXRunNativeSignIn(void) {
    Class centerClass = NSClassFromString(@"ITSignInAutomaticallyCenter");
    if (!centerClass) {
        ITXLog(@"未找到 ITSignInAutomaticallyCenter，准备走接口兜底");
        return NO;
    }

    id center = nil;
    @try {
        if ([centerClass respondsToSelector:@selector(sharedCenter)]) {
            center = ((id (*)(id, SEL))objc_msgSend)(centerClass, @selector(sharedCenter));
        }
    } @catch (__unused NSException *e) {
    }

    if (!center) {
        ITXLog(@"sharedCenter 取不到实例");
        return NO;
    }

    @try {
        if ([center respondsToSelector:@selector(setStoredEnabled:)]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(center, @selector(setStoredEnabled:), YES);
        }
        if ([center respondsToSelector:@selector(setEnabled:)]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(center, @selector(setEnabled:), YES);
        }
        if ([center respondsToSelector:@selector(makeManagerIfNeeded)]) {
            ((void (*)(id, SEL))objc_msgSend)(center, @selector(makeManagerIfNeeded));
        }
        if ([center respondsToSelector:@selector(requestSignInAutomatically)]) {
            ((void (*)(id, SEL))objc_msgSend)(center, @selector(requestSignInAutomatically));
            ITXLog(@"已触发原生自动签到");
            return YES;
        }
    } @catch (NSException *e) {
        ITXLog(@"原生签到异常：%@", e.reason);
    }
    return NO;
}

#pragma mark - 接口兜底

static void ITXDirectSignIn(void (^completion)(BOOL ok, NSString *message)) {
    NSURL *url = [NSURL URLWithString:@"https://my.ruanmei.com/api/usersign/autosign"];
    if (!url) {
        if (completion) completion(NO, @"URL 构造失败");
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 15;

    NSMutableArray<NSString *> *cookiePairs = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url]) {
        [cookiePairs addObject:[NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value]];
    }
    if (cookiePairs.count) {
        [req setValue:[cookiePairs componentsJoinedByString:@"; "] forHTTPHeaderField:@"Cookie"];
    }

    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    NSString *version = info[@"CFBundleShortVersionString"] ?: @"";
    [req setValue:[NSString stringWithFormat:@"ITHomeClient/%@ (iPhone; iOS %@; Scale/3.00)",
                   version, [UIDevice currentDevice].systemVersion]
        forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"https://my.ruanmei.com/" forHTTPHeaderField:@"Referer"];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithRequest:req
                                        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
        NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSInteger code = [(NSHTTPURLResponse *)resp statusCode];

        if (error) {
            if (completion) completion(NO, error.localizedDescription);
            return;
        }
        if (code != 200) {
            if (completion) completion(NO, [NSString stringWithFormat:@"HTTP %ld", (long)code]);
            return;
        }
        if (text.length > 200) text = [text substringToIndex:200];
        if (completion) completion(YES, text ?: @"");
    }];
    [task resume];
}

#pragma mark - 调度

static void ITXAttempt(BOOL allowDirect) {
    if (!ITXOn(ITXKeyAutoSign)) return;
    if ([[[NSUserDefaults standardUserDefaults] stringForKey:kITXLastSignDate] isEqualToString:ITXToday()]) {
        return;
    }
    if (sRunning) return;
    sRunning = YES;

    BOOL native = ITXRunNativeSignIn();

    // 原生流程无论成功与否，都给一次接口兜底；重复签到的返回值是幂等的
    if (!allowDirect) {
        sRunning = NO;
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(native ? 6.0 : 1.0) * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        ITXDirectSignIn(^(BOOL ok, NSString *message) {
            sRunning = NO;
            if (ok) {
                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                [d setObject:ITXToday() forKey:kITXLastSignDate];
                [d synchronize];
                ITXMarkState([message containsString:@"签到成功"] ? @"签到成功" : @"已签到");
                ITXLog(@"签到接口返回：%@", message);
            } else {
                ITXMarkState([NSString stringWithFormat:@"失败：%@", message]);
            }
        });
    });
}

void ITXAutoSignInSchedule(void) {
    if (!ITXOn(ITXKeyAutoSign)) return;

    // 启动 8 秒后第一次（等登录态与 App 配置加载完）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)8.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        ITXAttempt(YES);
    });

    // 冷启动可能还没登录，25 秒再补一次
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)25.0 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        if (![[[NSUserDefaults standardUserDefaults] stringForKey:kITXLastSignDate] isEqualToString:ITXToday()]) {
            sRunning = NO;
            ITXAttempt(YES);
        }
    });
}

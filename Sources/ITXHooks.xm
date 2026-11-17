//
//  ITXHooks.xm
//  所有 hook 点都在这里，按功能分组，开关关闭时原样走 %orig。
//
//  目标 App：IT之家（com.ruanmei.ithome）9.52
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "ITXPrefs.h"
#import "ITXLog.h"
#import "ITXURLFilter.h"
#import "ITXSignIn.h"
#import "ITXEntryView.h"
#import "ITXSettingsViewController.h"

#pragma mark - 开屏广告

// ITLaunchAdManager.shareManager 在启动时把缓存的广告投到窗口上，
// 直接跳过即可；广告数据本身也被下面的域名规则拦掉。
%hook ITLaunchAdManager

- (void)setupITLaunchAd {
    if (ITXOn(ITXKeyLaunchAd)) {
        ITXLog(@"跳过开屏广告");
        return;
    }
    %orig;
}

%end

// 开屏广告的下载/缓存，拦掉可以省掉后台流量
%hook NSADInfoManager

- (void)loadADInfoFromLocalIfNeeded {
    if (ITXOn(ITXKeyLaunchAd) && ITXOn(ITXKeyAdHost)) return;
    %orig;
}

- (void)reloadADInfo {
    if (ITXOn(ITXKeyLaunchAd) && ITXOn(ITXKeyAdHost)) return;
    %orig;
}

%end

#pragma mark - 信息流广告

// 列表里的推广卡片由 NSListADInfoManager 决定要不要插、插几条
%hook NSListADInfoManager

- (BOOL)hasAdByType:(id)type {
    if (ITXOn(ITXKeyFeedAd)) return NO;
    return %orig;
}

- (BOOL)hasOtherAdByType:(id)type {
    if (ITXOn(ITXKeyFeedAd)) return NO;
    return %orig;
}

- (BOOL)hasOtherAdByType:(id)type forList:(id)list {
    if (ITXOn(ITXKeyFeedAd)) return NO;
    return %orig;
}

- (void)reloadADInfoFromData:(id)data {
    if (ITXOn(ITXKeyFeedAd)) return;
    %orig;
}

- (void)loadADInfo {
    if (ITXOn(ITXKeyFeedAd)) return;
    %orig;
}

- (void)loadLpADInfo {
    if (ITXOn(ITXKeyFeedAd)) return;
    %orig;
}

%end

#pragma mark - 文章详情页广告

%hook RMNewsDetailWebADView

- (void)setSwiperAdapter:(id)adapter display:(BOOL)display {
    if (ITXOn(ITXKeyDetailAd)) {
        ((UIView *)self).hidden = YES;
        return;
    }
    %orig;
}

%end

%hook RMNewsDetailWebADViewAdapter

- (NSInteger)numberOfItemsInSwiperView:(id)swiperView {
    if (ITXOn(ITXKeyDetailAd)) return 0;
    return %orig;
}

%end

#pragma mark - 自动签到

// 原生自动签到要求「阅读任务完成」，这里直接告诉它已完成
%hook ITSignInAutomaticallyManager

- (BOOL)isSatisfyTaskCompletion {
    if (ITXOn(ITXKeyAutoSign)) return YES;
    return %orig;
}

%end

#pragma mark - 版本更新弹窗

%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    if (ITXOn(ITXKeyBlockUpdate) && viewControllerToPresent) {
        NSString *className = NSStringFromClass([viewControllerToPresent class]);
        if ([className containsString:@"VersionUpgrade"] ||
            [className containsString:@"UpgradeAlert"] ||
            [className containsString:@"UpdateAlert"]) {
            ITXLog(@"拦截更新弹窗 %@", className);
            if (completion) completion();
            return;
        }
    }
    %orig;
}

%end

#pragma mark - 第三方跳转拦截

static BOOL ITXShouldBlockOpenURL(NSURL *url) {
    if (!ITXOn(ITXKeyBlockJump) || !url) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if (scheme.length == 0) return NO;
    static NSSet<NSString *> *blocked;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        blocked = [NSSet setWithArray:@[
            @"itms-apps",         // App Store：评分/更新/推广
            @"taobao",
            @"tbopen",
            @"tmall",
            @"openapp.jdmobile",
            @"openjd",
            @"jingdong",
            @"pinduoduo",
            @"snssdk1128",        // 抖音
            @"kwai",              // 快手
        ]];
    });
    if ([blocked containsObject:scheme]) {
        ITXLog(@"拦截跳转 %@", scheme);
        return YES;
    }
    return NO;
}

%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    if (ITXShouldBlockOpenURL(url)) return NO;
    return %orig;
}

- (void)openURL:(NSURL *)url
        options:(NSDictionary *)options
completionHandler:(void (^)(BOOL success))completion {
    if (ITXShouldBlockOpenURL(url)) {
        if (completion) completion(NO);
        return;
    }
    %orig;
}

%end

#pragma mark - 请求层过滤

// 广告 / 埋点请求统一在构造阶段改写到本地占位地址，
// 连接会立刻失败，宿主代码走正常的 error 分支，不会卡 UI。
%hook NSURLRequest

+ (instancetype)requestWithURL:(NSURL *)URL {
    return %orig(ITXRewriteURL(URL));
}

+ (instancetype)requestWithURL:(NSURL *)URL
                   cachePolicy:(NSURLRequestCachePolicy)cachePolicy
               timeoutInterval:(NSTimeInterval)timeoutInterval {
    return %orig(ITXRewriteURL(URL), cachePolicy, timeoutInterval);
}

%end

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)URL {
    %orig(ITXRewriteURL(URL));
}

%end

#pragma mark - 设置入口

%hook ITSettingViewController

- (void)viewDidLoad {
    %orig;
    ((void (*)(id, SEL))objc_msgSend)(self, @selector(itx_installEnhanceEntry));
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    ((void (*)(id, SEL))objc_msgSend)(self, @selector(itx_installEnhanceEntry));
}

%new
- (void)itx_installEnhanceEntry {
    UITableView *table = nil;
    @try {
        table = [(NSObject *)self valueForKey:@"tableView"];
    } @catch (__unused NSException *e) {
    }
    if (![table isKindOfClass:[UITableView class]]) return;

    static const NSInteger kITXEntryTag = 0x4954;  // 'IT'

    UIView *current = table.tableFooterView;
    if (current && (current.tag == kITXEntryTag || [current isKindOfClass:[ITXEntryView class]])) {
        return;  // 已装好
    }

    __weak typeof(self) weakSelf = self;
    ITXEntryView *entry = [ITXEntryView entryWithHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [ITXSettingsViewController openFrom:(UIViewController *)strongSelf];
        }
    }];

    CGFloat width = CGRectGetWidth(table.bounds);
    if (width <= 0) width = CGRectGetWidth([UIScreen mainScreen].bounds);

    // 原页面可能自带 footer（例如「退出登录」），有就保留，把入口排在它下面
    CGFloat oldHeight = 0;
    if (current && current.subviews.count > 0) {
        oldHeight = MAX(CGRectGetHeight(current.frame), 44);
    }

    if (oldHeight > 1) {
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, oldHeight + 68)];
        container.tag = kITXEntryTag;
        current.frame = CGRectMake(0, 0, width, oldHeight);
        current.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        entry.frame = CGRectMake(0, oldHeight, width, 68);
        entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [container addSubview:current];
        [container addSubview:entry];
        table.tableFooterView = container;
    } else {
        entry.tag = kITXEntryTag;
        entry.frame = CGRectMake(0, 0, width, 68);
        entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        table.tableFooterView = entry;
    }
    ITXLog(@"设置页入口已注入");
}

%end

#pragma mark - 启动

%ctor {
    @autoreleasepool {
        ITXPrefsRegisterDefaults();
        ITXLog(@"IT之家增强 1.0.0 已加载");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            ITXAutoSignInSchedule();
        });
    }
}

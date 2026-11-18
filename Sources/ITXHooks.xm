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
#import "ITXFeedAdFilter.h"
#import "ITXSignIn.h"
#import "ITXPerf.h"
#import "ITXEntryView.h"
#import "ITXSettingsViewController.h"

// SDWebImage 的属性声明，只为拿到 setter 签名，不参与实现
@interface SDWebImageDownloaderConfig : NSObject
@property (nonatomic, assign) NSInteger maxConcurrentDownloads;
@end

@interface SDWebImagePrefetcher : NSObject
@property (nonatomic, assign) NSUInteger maxConcurrentPrefetchCount;
@end

@interface SDImageCacheConfig : NSObject
@property (nonatomic, assign) NSUInteger maxMemoryCost;
@property (nonatomic, assign) NSUInteger maxMemoryCount;
@end

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

// 开屏素材预下载：广告都拦了就没必要提前下图片/视频，纯占流量和磁盘
- (void)batchDownloadImageAndCache:(id)models {
    if (!ITXOn(ITXKeySplashPreload)) {
        static BOOL logged = NO;
        if (!logged) {
            logged = YES;
            ITXLog(@"跳过开屏图片素材预下载");
        }
        return;
    }
    %orig;
}

- (void)batchDownloadVideoAndCache:(id)models {
    if (!ITXOn(ITXKeySplashPreload)) {
        static BOOL logged = NO;
        if (!logged) {
            logged = YES;
            ITXLog(@"跳过开屏视频素材预下载");
        }
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

// 首页穿插在新闻之间的广告是服务端下发的 ITNewsModel（isAd=YES），
// 列表装配时直接混进同一个数组，不会经过 NSListADInfoManager，
// 所以真正的拦截点在「交给 IGListKit 之前」把数组洗一遍。
%hook ITFeedFlowViewController

- (NSArray *)objectsForListAdapter:(id)adapter {
    NSArray *list = %orig;
    if (ITXOn(ITXKeyFeedAd)) return ITXStripFeedAds(list);
    return list;
}

%end

// 有些页面把数据源转交给内核层的 Swift 实现，这里再洗一次（幂等）
%hook _TtC11RMKernelKit25FeedListAdapterDataSource

- (NSArray *)objectsForListAdapter:(id)adapter {
    NSArray *list = %orig;
    if (ITXOn(ITXKeyFeedAd)) return ITXStripFeedAds(list);
    return list;
}

%end

// 基类兜底：个别栏目页直接用 ITListAdapterViewController，没走 FeedFlow 那套
%hook ITListAdapterViewController

- (NSArray *)objectsForListAdapter:(id)adapter {
    NSArray *list = %orig;
    if (ITXOn(ITXKeyFeedAd)) return ITXStripFeedAds(list);
    return list;
}

%end

// App 自己的过滤通道。这个方法的返回值语义静态确认不了（返回 YES 是「过滤掉」还是
// 「保留」看不出来），但只在我们认定是广告时返回 YES：
//   - 若是「过滤掉」 -> 广告被丢掉，符合预期
//   - 若是「保留」   -> 广告被保留，等同于没改，不会误伤正常条目
// 两种语义下都不会把列表搞坏，所以放心加成第二道网。
%hook ITFeedFlowViewModel

- (BOOL)isFilterOutFeed:(id)feed {
    if (ITXOn(ITXKeyFeedAd) && ITXFeedIsAd(feed)) return YES;
    return %orig;
}

%end

// 第三道网：万一广告还是进了列表，把它的高度压成 0，至少不会显示出来。
// 文章 section 一条新闻一个 section，尺寸在这里算。
%hook RMNewsHomeArticleSectionController

- (void)didUpdateToObject:(id)object {
    %orig;
    static BOOL logged;
    if (!logged) {
        logged = YES;
        ITXLog(@"信息流 section 对象类型：%@", NSStringFromClass([object class]));
    }
}

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    if (ITXOn(ITXKeyFeedAd)) {
        // self 在这个编译单元里只是前向声明，先落成 id 再发消息
        id slf = (id)self;
        id model = nil;
        @try {
            model = [slf valueForKey:@"articleModel"];
        } @catch (__unused NSException *e) {
        }
        if (model && ITXFeedIsAd(model)) return CGSizeZero;
    }
    return %orig;
}

%end

// 顶部轮播里的推广位：focusNewsData 是 RMNewsCarouseFeedItemModel 数组
%hook RMNewsSwiperFeedModel

- (NSArray *)focusNewsData {
    NSArray *data = %orig;
    if (ITXOn(ITXKeyFeedAd)) return ITXStripFeedAds(data);
    return data;
}

%end

// 列表里的推广卡片由 NSListADInfoManager 决定要不要插、插几条。
// 和上面的条目级过滤互不依赖，两处都拦更稳。
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

// 阅读计时器：为了「每日阅读时长」任务每秒累加，纯耗电。
// 签到判定已经放行，不需要它再记时。
- (id)createReadingTimer {
    if (ITXOn(ITXKeySavePower)) {
        static BOOL logged = NO;
        if (!logged) {
            logged = YES;
            ITXLog(@"已关闭阅读计时器");
        }
        return nil;
    }
    return %orig;
}

// 活跃时长统计（前台停留），同样只是为任务服务
- (id)createActiveWorkItem {
    if (ITXOn(ITXKeySavePower)) return nil;
    return %orig;
}

%end

#pragma mark - 阅读历史上报

// 每翻一篇文章都会打一次 newsreadhistory/post，这里做「首次立即 + 窗口内合并」，
// 高频阅读时请求数能降一个数量级。
%hook ITUpdateReadHistoryManager

- (void)updateReadHistory {
    if (!ITXOn(ITXKeyReadHistory)) {
        %orig;
        return;
    }

    static NSTimeInterval lastPush = 0;
    static BOOL pending = NO;
    static const NSTimeInterval kWindow = 150.0;   // 2.5 分钟一次

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (lastPush <= 0 || now - lastPush >= kWindow) {
        lastPush = now;
        pending = NO;
        %orig;
        return;
    }

    if (pending) return;
    pending = YES;
    ITXDeferReinvoke(self, _cmd, kWindow - (now - lastPush));
}

%end

#pragma mark - 启动优化：第三方 SDK 延后初始化

// 闸门模式：第一次进来只登记并借主队列重入，第二次进来标记已消费、放行 %orig。
// 这样既不用在 hook 里塞 block 调 %orig，也不会递归。
static BOOL sHeldAliBaiChuan = NO;
static BOOL sHeldJDKepler = NO;
static BOOL sHeldBugly = NO;

%hook AppDelegate

- (void)configureAliBaiChuan {
    if (ITXOn(ITXKeyFastLaunch) && !sHeldAliBaiChuan) {
        sHeldAliBaiChuan = YES;
        ITXLog(@"阿里百川初始化推迟到首帧后");
        ITXDeferReinvoke(self, _cmd, 1.2);
        return;
    }
    %orig;
}

- (void)configureJDKepler {
    if (ITXOn(ITXKeyFastLaunch) && !sHeldJDKepler) {
        sHeldJDKepler = YES;
        ITXLog(@"京东开普勒初始化推迟到首帧后");
        ITXDeferReinvoke(self, _cmd, 1.6);
        return;
    }
    %orig;
}

- (void)configureBugly {
    if (ITXOn(ITXKeyFastLaunch) && !sHeldBugly) {
        sHeldBugly = YES;
        ITXLog(@"Bugly 崩溃上报推迟到首帧后");
        ITXDeferReinvoke(self, _cmd, 2.0);
        return;
    }
    %orig;
}

// 商城模块：不注册 Central、不配置，首页商品卡与商城请求一起跳过
- (void)configureShopMall {
    if (ITXOn(ITXKeyHideMall)) {
        ITXLog(@"跳过商城模块初始化");
        return;
    }
    %orig;
}

%end

// SignalR 长连接：启动即建连，会占一个 socket 并周期性心跳
%hook ITSignalRBasisManager

- (void)openConnection {
    static BOOL held = NO;
    if (ITXOn(ITXKeyFastLaunch) && !held) {
        held = YES;
        ITXLog(@"SignalR 长连接推迟 2.5s 建立");
        ITXDeferReinvoke(self, _cmd, 2.5);
        return;
    }
    %orig;
}

%end

// 腾讯播放器鉴权：带参数的方法没法用无参重入，先存参数、延后回放
static NSString *sLicenceURL = nil;
static NSString *sLicenceKey = nil;
static BOOL sLicenceDeferred = NO;

%hook TXLiveBase

+ (void)setLicenceURL:(NSString *)url key:(NSString *)key {
    if (ITXOn(ITXKeyFastLaunch) && !sLicenceDeferred && url.length > 0) {
        sLicenceDeferred = YES;
        sLicenceURL = [url copy];
        sLicenceKey = [key copy];
        ITXLog(@"腾讯播放器鉴权推迟到首帧后");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)1.8 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            // 再次调用会重新进入本 hook；闸门已置位，这次直接走 %orig
            Class cls = objc_getClass("TXLiveBase");
            if (!cls) return;
            ((void (*)(id, SEL, id, id))objc_msgSend)(cls,
                                                      @selector(setLicenceURL:key:),
                                                      sLicenceURL,
                                                      sLicenceKey);
        });
        return;
    }
    %orig;
}

%end

#pragma mark - 商城模块

// 商城 Central 负责把商品/价格监控挂到首页信息流上，
// 不注册之后 RMShopMall 的 cell 不会被装配进来。
%hook _TtC12ITHomeClient17ITShopMallCentral

+ (void)registerCentral {
    if (ITXOn(ITXKeyHideMall)) {
        ITXLog(@"跳过商城 Central 注册");
        return;
    }
    %orig;
}

%end

// 首页「大家都在买」商品卡：高度压成 0，整块不再占位
%hook ITFeedFlowProductTopSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    if (ITXOn(ITXKeyHideMall)) return CGSizeZero;
    return %orig;
}

%end

#pragma mark - 图片并发

// 新建设的 downloader / cache 直接用收敛后的默认配置
%hook SDWebImageDownloaderConfig

+ (instancetype)defaultDownloaderConfig {
    id config = %orig;
    if (ITXOn(ITXKeyImageLimit) && config) {
        [(SDWebImageDownloaderConfig *)config setMaxConcurrentDownloads:4];
    }
    return config;
}

%end

%hook SDImageCacheConfig

+ (instancetype)defaultCacheConfig {
    id config = %orig;
    if (ITXOn(ITXKeyImageLimit) && config) {
        SDImageCacheConfig *cacheConfig = (SDImageCacheConfig *)config;
        cacheConfig.maxMemoryCost = 64 * 1024 * 1024;
        cacheConfig.maxMemoryCount = 200;
    }
    return config;
}

%end

%hook SDWebImagePrefetcher

+ (instancetype)sharedImagePrefetcher {
    id prefetcher = %orig;
    if (ITXOn(ITXKeyImageLimit) && prefetcher) {
        [(SDWebImagePrefetcher *)prefetcher setMaxConcurrentPrefetchCount:2];
    }
    return prefetcher;
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

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 第一个页面出现即为首帧就绪，只记录一次
    ITXPerfReportFirstFrame();
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

// 广告 / 埋点 / 商城请求统一在构造阶段改写到本地占位地址，
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
        ITXPerfMarkLaunch();
        ITXPrefsRegisterDefaults();
        ITXLog(@"IT之家增强 1.1.0 已加载");

        // 首帧之后再动图片并发，避免把 downloader 的 session 提前建起来
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)2.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            ITXPerfApplyImageLimits();
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)1.0 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            ITXAutoSignInSchedule();
        });
    }
}

#import "ITXPrefs.h"

NSString *const ITXPrefsChangedNotification = @"com.itx.ithomeenhance.prefsChanged";

static NSString *const kITXPrefix = @"itx_";

static NSString *ITXKeyName(ITXKey key) {
    switch (key) {
        case ITXKeyLaunchAd:     return @"launchAd";
        case ITXKeyFeedAd:       return @"feedAd";
        case ITXKeyDetailAd:     return @"detailAd";
        case ITXKeyAdHost:       return @"adHost";
        case ITXKeyAutoSign:     return @"autoSign";
        case ITXKeyBlockUpdate:  return @"blockUpdate";
        case ITXKeyBlockJump:    return @"blockJump";
        case ITXKeyBlockStats:   return @"blockStats";
        case ITXKeyFastLaunch:   return @"fastLaunch";
        case ITXKeySavePower:    return @"savePower";
        case ITXKeyReadHistory:  return @"readHistory";
        case ITXKeyHideMall:     return @"hideMall";
        case ITXKeySplashPreload:return @"splashPreload";
        case ITXKeyImageLimit:   return @"imageLimit";
        case ITXKeyCount:        break;
    }
    return @"unknown";
}

static NSString *ITXDefaultsKey(ITXKey key) {
    return [kITXPrefix stringByAppendingString:ITXKeyName(key)];
}

void ITXPrefsRegisterDefaults(void) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        // 广告净化
        ITXDefaultsKey(ITXKeyLaunchAd):     @YES,
        ITXDefaultsKey(ITXKeyFeedAd):       @YES,
        ITXDefaultsKey(ITXKeyDetailAd):     @YES,
        ITXDefaultsKey(ITXKeyAdHost):       @YES,
        // 功能增强
        ITXDefaultsKey(ITXKeyAutoSign):     @YES,
        ITXDefaultsKey(ITXKeyBlockUpdate):  @YES,
        ITXDefaultsKey(ITXKeyBlockJump):    @NO,   // 默认不动，避免影响正常分享/支付
        ITXDefaultsKey(ITXKeyBlockStats):   @YES,
        // 性能与省电
        ITXDefaultsKey(ITXKeyFastLaunch):   @YES,
        ITXDefaultsKey(ITXKeySavePower):    @YES,
        ITXDefaultsKey(ITXKeyReadHistory):  @YES,
        ITXDefaultsKey(ITXKeyHideMall):     @NO,   // 会动到首页模块，默认关
        ITXDefaultsKey(ITXKeySplashPreload):@NO,   // 默认不预下载开屏素材
        ITXDefaultsKey(ITXKeyImageLimit):   @YES,
    }];
}

void ITXPrefsResetToDefaults(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (ITXKey key = 0; key < ITXKeyCount; key++) {
        [d removeObjectForKey:ITXDefaultsKey(key)];
    }
    [d synchronize];
    ITXPrefsRegisterDefaults();
    [[NSNotificationCenter defaultCenter] postNotificationName:ITXPrefsChangedNotification object:nil];
}

BOOL ITXOn(ITXKey key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:ITXDefaultsKey(key)];
}

void ITXSetOn(ITXKey key, BOOL on) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:on forKey:ITXDefaultsKey(key)];
    [d synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:ITXPrefsChangedNotification object:nil];
}

NSString *ITXKeyTitle(ITXKey key) {
    switch (key) {
        case ITXKeyLaunchAd:     return @"去掉开屏广告";
        case ITXKeyFeedAd:       return @"去掉信息流广告";
        case ITXKeyDetailAd:     return @"去掉文章页广告";
        case ITXKeyAdHost:       return @"拦截广告域名";
        case ITXKeyAutoSign:     return @"自动签到";
        case ITXKeyBlockUpdate:  return @"屏蔽更新弹窗";
        case ITXKeyBlockJump:    return @"拦截第三方跳转";
        case ITXKeyBlockStats:   return @"关闭统计上报";
        case ITXKeyFastLaunch:   return @"精简启动 SDK";
        case ITXKeySavePower:    return @"关闭阅读计时";
        case ITXKeyReadHistory:  return @"阅读上报合并";
        case ITXKeyHideMall:     return @"隐藏商城模块";
        case ITXKeySplashPreload:return @"预下载开屏素材";
        case ITXKeyImageLimit:   return @"限制图片并发";
        case ITXKeyCount:        break;
    }
    return @"";
}

NSString *ITXKeyDetail(ITXKey key) {
    switch (key) {
        case ITXKeyLaunchAd:     return @"跳过启动图后的全屏广告";
        case ITXKeyFeedAd:       return @"首页/列表里的推广卡片";
        case ITXKeyDetailAd:     return @"正文中的广告位与广告接口";
        case ITXKeyAdHost:       return @"规则级拦截广告与素材请求";
        case ITXKeyAutoSign:     return @"启动后自动完成每日签到";
        case ITXKeyBlockUpdate:  return @"不再弹出新版本提示";
        case ITXKeyBlockJump:    return @"阻止跳转淘宝/京东等外部 App";
        case ITXKeyBlockStats:   return @"拦截友盟等埋点日志上报";
        case ITXKeyFastLaunch:   return @"阿里百川 / 京东开普勒 / Bugly 延后到首帧后 · 重启生效";
        case ITXKeySavePower:    return @"不再为阅读任务跑后台计时器";
        case ITXKeyReadHistory:  return @"同步请求合并提交，最短间隔 2.5 分钟";
        case ITXKeyHideMall:     return @"首页商品卡与商城请求整块跳过 · 重启生效";
        case ITXKeySplashPreload:return @"关掉后不再提前下载开屏图片/视频";
        case ITXKeyImageLimit:   return @"下载并发降到 4 路，内存缓存上限 64 MB";
        case ITXKeyCount:        break;
    }
    return @"";
}

NSString *ITXGroupTitle(ITXGroup group) {
    switch (group) {
        case ITXGroupAd:          return @"广告净化";
        case ITXGroupFeature:     return @"功能增强";
        case ITXGroupPerformance: return @"性能与省电";
        case ITXGroupOther:       return @"其他";
        case ITXGroupCount:       break;
    }
    return @"";
}

NSArray<NSNumber *> *ITXGroupKeys(ITXGroup group) {
    switch (group) {
        case ITXGroupAd:
            return @[@(ITXKeyLaunchAd), @(ITXKeyFeedAd), @(ITXKeyDetailAd), @(ITXKeyAdHost)];
        case ITXGroupFeature:
            return @[@(ITXKeyAutoSign), @(ITXKeyBlockUpdate), @(ITXKeyBlockJump), @(ITXKeyBlockStats)];
        case ITXGroupPerformance:
            return @[@(ITXKeyFastLaunch), @(ITXKeyImageLimit), @(ITXKeyReadHistory),
                     @(ITXKeySavePower), @(ITXKeySplashPreload), @(ITXKeyHideMall)];
        case ITXGroupOther:
        case ITXGroupCount:
            break;
    }
    return @[];
}

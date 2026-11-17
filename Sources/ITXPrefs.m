#import "ITXPrefs.h"

NSString *const ITXPrefsChangedNotification = @"com.itx.ithomeenhance.prefsChanged";

static NSString *const kITXPrefix = @"itx_";

static NSString *ITXKeyName(ITXKey key) {
    switch (key) {
        case ITXKeyLaunchAd:    return @"launchAd";
        case ITXKeyFeedAd:      return @"feedAd";
        case ITXKeyDetailAd:    return @"detailAd";
        case ITXKeyAdHost:      return @"adHost";
        case ITXKeyAutoSign:    return @"autoSign";
        case ITXKeyBlockUpdate: return @"blockUpdate";
        case ITXKeyBlockJump:   return @"blockJump";
        case ITXKeyBlockStats:  return @"blockStats";
    }
    return @"unknown";
}

static NSString *ITXDefaultsKey(ITXKey key) {
    return [kITXPrefix stringByAppendingString:ITXKeyName(key)];
}

void ITXPrefsRegisterDefaults(void) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        ITXDefaultsKey(ITXKeyLaunchAd):    @YES,
        ITXDefaultsKey(ITXKeyFeedAd):      @YES,
        ITXDefaultsKey(ITXKeyDetailAd):    @YES,
        ITXDefaultsKey(ITXKeyAdHost):      @YES,
        ITXDefaultsKey(ITXKeyAutoSign):    @YES,
        ITXDefaultsKey(ITXKeyBlockUpdate): @YES,
        ITXDefaultsKey(ITXKeyBlockJump):   @NO,   // 默认不动，避免影响正常分享/支付
        ITXDefaultsKey(ITXKeyBlockStats):  @YES,
    }];
}

void ITXPrefsResetToDefaults(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (ITXKey key = ITXKeyLaunchAd; key <= ITXKeyBlockStats; key++) {
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
        case ITXKeyLaunchAd:    return @"去掉开屏广告";
        case ITXKeyFeedAd:      return @"去掉信息流广告";
        case ITXKeyDetailAd:    return @"去掉文章页广告";
        case ITXKeyAdHost:      return @"拦截广告域名";
        case ITXKeyAutoSign:    return @"自动签到";
        case ITXKeyBlockUpdate: return @"屏蔽更新弹窗";
        case ITXKeyBlockJump:   return @"拦截第三方跳转";
        case ITXKeyBlockStats:  return @"关闭统计上报";
    }
    return @"";
}

NSString *ITXKeyDetail(ITXKey key) {
    switch (key) {
        case ITXKeyLaunchAd:    return @"跳过启动图后的全屏广告";
        case ITXKeyFeedAd:      return @"首页/列表里的推广卡片";
        case ITXKeyDetailAd:    return @"正文中的广告位与广告接口";
        case ITXKeyAdHost:      return @"规则级拦截广告与素材请求";
        case ITXKeyAutoSign:    return @"启动后自动完成每日签到";
        case ITXKeyBlockUpdate: return @"不再弹出新版本提示";
        case ITXKeyBlockJump:   return @"阻止跳转淘宝/京东等外部 App";
        case ITXKeyBlockStats:  return @"拦截友盟等埋点日志上报";
    }
    return @"";
}

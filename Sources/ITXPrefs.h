//
//  ITXPrefs.h
//  开关存储：直接写 App 自己的 NSUserDefaults，卸载重装前一直有效
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ITXKey) {
    ITXKeyLaunchAd = 0,   // 去掉开屏广告
    ITXKeyFeedAd,         // 去掉信息流广告
    ITXKeyDetailAd,       // 去掉文章页广告
    ITXKeyAdHost,         // 拦截广告域名
    ITXKeyAutoSign,       // 自动签到
    ITXKeyBlockUpdate,    // 屏蔽版本更新弹窗
    ITXKeyBlockJump,      // 拦截第三方 App 跳转（含 App Store）
    ITXKeyBlockStats,     // 关闭统计上报
};

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT NSString *const ITXPrefsChangedNotification;

void ITXPrefsRegisterDefaults(void);
/// 清掉用户改动并回到出厂默认
void ITXPrefsResetToDefaults(void);
BOOL ITXOn(ITXKey key);
void ITXSetOn(ITXKey key, BOOL on);

NSString *ITXKeyTitle(ITXKey key);
NSString *ITXKeyDetail(ITXKey key);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

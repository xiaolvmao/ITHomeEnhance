//
//  ITXPrefs.h
//  开关存储：直接写 App 自己的 NSUserDefaults，卸载重装前一直有效
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ITXKey) {
    // 广告净化
    ITXKeyLaunchAd = 0,   // 去掉开屏广告
    ITXKeyFeedAd,         // 去掉信息流广告
    ITXKeyDetailAd,       // 去掉文章页广告
    ITXKeyAdHost,         // 拦截广告域名
    // 功能增强
    ITXKeyAutoSign,       // 自动签到
    ITXKeyBlockUpdate,    // 屏蔽版本更新弹窗
    ITXKeyBlockJump,      // 拦截第三方 App 跳转（含 App Store）
    ITXKeyBlockStats,     // 关闭统计上报
    // 性能与省电
    ITXKeyFastLaunch,     // 延迟第三方 SDK 初始化
    ITXKeySavePower,      // 关闭阅读计时器
    ITXKeyReadHistory,    // 阅读历史上报合并
    ITXKeyHideMall,       // 隐藏商城模块
    ITXKeySplashPreload,  // 预下载开屏素材（默认关）
    ITXKeyImageLimit,     // 限制图片并发
    ITXKeyCount           // 哨兵，永远是最后一个
};

/// 分组定义，设置面板按这个顺序渲染
typedef NS_ENUM(NSInteger, ITXGroup) {
    ITXGroupAd = 0,
    ITXGroupFeature,
    ITXGroupPerformance,
    ITXGroupOther,
    ITXGroupCount
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

NSString *ITXGroupTitle(ITXGroup group);
/// 该分组包含的开关，元素是 NSNumber 包装的 ITXKey
NSArray<NSNumber *> *ITXGroupKeys(ITXGroup group);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

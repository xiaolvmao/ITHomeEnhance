//
//  ITXPerf.h
//  启动计时、延迟重入调用、图片并发收敛
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// 在 %ctor 里调用，记下插件加载时刻
void ITXPerfMarkLaunch(void);
/// 首个页面出现时调用，只记一次
void ITXPerfReportFirstFrame(void);
/// 插件加载到首帧的毫秒数，0 表示还没记到
NSTimeInterval ITXPerfLaunchCost(void);

/// 延迟 delay 秒后在主队列上重新调用 sel。
/// 目标方法里的 hook 用一个一次性标记做闸门：第一次只登记不执行，
/// 第二次进来就放行走 %orig，因此不会递归。
void ITXDeferReinvoke(id _Nullable target, SEL sel, NSTimeInterval delay);

/// 把 SDWebImage 的下载并发与内存缓存上限压下来；开关关闭时什么都不做
void ITXPerfApplyImageLimits(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

//
//  ITXSignIn.h
//  自动签到：优先驱动 App 自带的 ITSignInAutomatically 流程，
//  不可用时走 https://my.ruanmei.com/api/usersign/autosign 兜底。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// App 启动后调用，内部自行延迟，避免和启动期的登录态刷新抢时序
void ITXAutoSignInSchedule(void);

/// 面板上展示的状态文案
NSString *ITXSignInStatusText(void);

NS_ASSUME_NONNULL_END

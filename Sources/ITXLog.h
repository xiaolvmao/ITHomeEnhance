//
//  ITXLog.h
//  轻量日志：内存环形缓冲 + 落盘，设置面板里可直接查看
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

void ITXLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

/// 最近 N 条日志（新的在前）
NSArray<NSString *> *ITXLogLines(void);
void ITXLogClear(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

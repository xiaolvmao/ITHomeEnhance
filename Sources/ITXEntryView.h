//
//  ITXEntryView.h
//  注入到「设置」列表底部的入口卡片
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ITXEntryView : UIView

+ (instancetype)entryWithHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END

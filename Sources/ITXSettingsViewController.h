//
//  ITXSettingsViewController.h
//  开关面板
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ITXSettingsViewController : UITableViewController

/// 优先 push 进当前导航栈，没有导航栈就模态呈现
+ (void)openFrom:(UIViewController *)host;

@end

NS_ASSUME_NONNULL_END

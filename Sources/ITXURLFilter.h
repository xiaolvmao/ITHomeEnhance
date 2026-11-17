//
//  ITXURLFilter.h
//  域名/路径级规则过滤：广告素材、开屏接口、埋点上报
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 命中规则返回 YES
BOOL ITXShouldBlockURLString(NSString *_Nullable urlString);

/// 命中后把请求改写到这个地址，让连接快速失败而不是挂起
NSURL *ITXBlockedURLPlaceholder(void);

/// 把被拦截的请求改写掉；不需要改写时原样返回
NSURL *_Nullable ITXRewriteURL(NSURL *_Nullable url);

NS_ASSUME_NONNULL_END

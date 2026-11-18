//
//  ITXFeedAdFilter.h
//  信息流广告识别与剔除
//
//  首页「新闻 / 最新」列表里的广告不是由 NSListADInfoManager 插的，
//  而是服务端直接在 JSON 里下发带 isAd=YES 的 ITNewsModel（或 Feed），
//  列表装配时和普通新闻混在同一个数组里，所以只能在数据出口处剔除。
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 对象自身是否被标记为广告（ITNewsModel / Feed / RMNewsCarouseFeedItemModel 都有 isAd）
BOOL ITXObjectIsAd(id _Nullable obj);

/// 把 ITFeedFlowContainerModel 这类包装拆开看里面的 feedContent，再判断是不是广告
BOOL ITXFeedIsAd(id _Nullable feed);

/// 返回剔除广告后的数组；没有广告时原样返回同一个对象，避免无谓的内存分配
NSArray *_Nullable ITXStripFeedAds(NSArray *_Nullable list);

#ifdef __cplusplus
}
#endif

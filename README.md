# IT之家增强 · ITHomeEnhance

面向 **IT之家 iOS 9.52** 的 TrollStore 注入插件（dylib）。功能入口放在 App 内「设置」页底部，选项全部是原生开关样式。

> 只针对已脱壳的 IPA 使用；App Store 原包注入后无法启动。

## 功能

| 分组 | 开关 | 做法 |
| --- | --- | --- |
| 广告净化 | 去掉开屏广告 | 跳过 `ITLaunchAdManager.setupITLaunchAd`，同时拦截 `napi.ithome.com/api/appsplash/get` |
| | 去掉信息流广告 | `NSListADInfoManager` 的 `hasAdByType:` / `hasOtherAdByType:` 一律返回 NO，广告数据不再装载 |
| | 去掉文章页广告 | `RMNewsDetailWebADView` 不显示，广告位数据源直接返回 0 条 |
| | 拦截广告域名 | 广点通 `mi.gdt.qq.com`、`union.ruanmei.com` 等请求在构造阶段改写到本地占位地址，立即失败 |
| 功能增强 | 自动签到 | 驱动 App 自带的 `ITSignInAutomaticallyCenter`，并放行 `isSatisfyTaskCompletion`；失败时回退到 `usersign/autosign` 接口 |
| | 屏蔽更新弹窗 | 拦截 `VersionUpgrade*` 控制器的 present |
| | 拦截第三方跳转 | 拦下淘宝/京东/拼多多/抖音/快手/`itms-apps` 等 scheme（默认关闭） |
| | 关闭统计上报 | 拦截友盟、`dat.ruanmei.com`、`wgo.mmstat.com` 等埋点请求 |
| 性能与省电 | 精简启动 SDK | `AppDelegate` 的 `configureAliBaiChuan` / `configureJDKepler` / `configureBugly` 推迟到首帧后，`TXLiveBase` 鉴权延后 1.8 s，SignalR 长连接延后 2.5 s |
| | 限制图片并发 | `SDWebImageDownloaderConfig` 并发降到 4 路，`SDImageCacheConfig` 内存上限 64 MB / 200 张，`SDWebImagePrefetcher` 预取降到 2 路 |
| | 阅读上报合并 | `ITUpdateReadHistoryManager.updateReadHistory` 做「首次立即 + 2.5 分钟窗口合并」，高频阅读时请求数降一个量级 |
| | 关闭阅读计时 | `ITSignInAutomaticallyManager` 的 `createReadingTimer` / `createActiveWorkItem` 直接返回 nil，不再为阅读任务跑计时器 |
| | 预下载开屏素材 | 默认关闭，`batchDownloadImageAndCache:` / `batchDownloadVideoAndCache:` 直接跳过 |
| | 隐藏商城模块 | 跳过 `configureShopMall` 与 `ITShopMallCentral.registerCentral`，首页商品卡高度压 0，并拦掉 `mall.ithome.com` / `shop.asmx` 请求 |

另有「查看运行日志」，出问题可以直接把日志发出来定位；面板底部会显示本次启动的首帧耗时（插件加载 → 首个页面出现）。

## 安装

### 方式一：TrollFools（最省事）

1. 下载 CI 产物里的 `ITHomeEnhance.dylib`
2. TrollFools → 选择 IT之家 → 注入 → 选中 dylib
3. 打开 App，「我的 → 设置」拉到最底部即可看到「增强设置」

### 方式二：注入 IPA 后交给 TrollStore

```bash
pip install lief
python tools/inject_ipa.py IT之家-9.52.ipa ITHomeEnhance.dylib -o IT之家-9.52-enhance.ipa
```

把输出的 IPA 拖进 TrollStore 安装即可（TrollStore 安装时会重新签名，注入导致的签名失效不用管）。

### 方式三：越狱设备

用 CI 产物里的 `.deb`，`dpkg -i` 后注销（respring）。

## 编译

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
make package
```

或者直接推送到 GitHub，Actions 会自动在 macOS 上编译并上传 `ITHomeEnhance.dylib` 与 `.deb`。

## 实现说明

工程不依赖 CydiaSubstrate：`Sources/ITXSubstrate.m` 用 ObjC runtime 的 `class_replaceMethod` 实现了一个 `MSHookMessageEx`，Logos 语法照常使用，因此 TrollStore 无根环境下也能正常工作。

所有目标类的选择都来自对 9.52 二进制的静态分析（ObjC 元数据 + 符号表），关键类：

- `ITLaunchAdManager` / `NSADInfoManager` —— 开屏广告加载、播放与素材预下载
- `NSListADInfoManager` —— 列表广告投放（含广点通 / InMobi / 京东 / 阿里妈妈四路数据）
- `RMNewsDetailWebADView(Adapter)` —— 正文广告位
- `ITSignInAutomaticallyCenter` / `ITSignInAutomaticallyManager` —— 原生自动签到与阅读计时
- `ITUpdateReadHistoryManager` —— 阅读历史上报
- `AppDelegate` / `ITSignalRBasisManager` / `TXLiveBase` —— 启动路径上的第三方 SDK
- `ITShopMallCentral` / `ITFeedFlowProductTopSectionController` —— 商城模块与首页商品卡
- `ITSettingViewController` —— 设置页（入口挂在其 `tableView.tableFooterView` 上）

### 延迟初始化怎么做到不递归

带开关的 hook 没法在 block 里安全地调 `%orig`，这里统一用「闸门 + 主队列重入」：第一次进来只登记、用一个静态标记占位，然后 `dispatch_after` 到主队列再调一次同名 selector；第二次进来标记已消费，直接放行走 `%orig`。带参数的方法（`TXLiveBase.setLicenceURL:key:`）会先把参数存到静态变量，重入时用 `objc_msgSend` 回放。

## 已知限制

- 广告域名拦截走的是 `NSURLRequest` / `NSMutableURLRequest` 构造阶段改写，个别用 `CFNetwork` 直连的 SDK 不受影响
- 自动签到依赖登录态，未登录时只会在日志里留一条失败记录
- 「精简启动 SDK」「隐藏商城模块」只在启动时读一次，改了要重启 App 才生效
- 「关闭阅读计时」会把 `createReadingTimer` 一起关掉；如果某天自动签到失效，先把这个开关关掉试试
- App 版本升级后类名/方法名可能变化，日志里出现「方法不存在」即说明该 hook 已失效

## 还能继续优化的地方

- **FSPlayer 预加载**：`RMShopMall` 里的视频预取没有对外的配置入口（Swift 内部结构体），只能在 cell 装配阶段拦截
- **图片解码降采样**：`SDWebImageCoder` 走默认全尺寸解码，列表里的缩略图可以按 cell 尺寸降采样，内存还能再降
- **分享 SDK 延迟**：微信/微博/QQ 的注册（`configureShare`）也可以挪到首帧后，但分享面板首次弹出会多等一点
- **启动图缓存**：`setLaunchImageOrGifWithModel:` 读的是本地缓存目录，可以顺手清理历史素材

## 免责声明

仅供学习与个人设备使用，请勿分发修改后的 IPA。插件只做本地行为调整，不修改任何服务端数据。

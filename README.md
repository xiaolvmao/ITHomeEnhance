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

另有「查看运行日志」，出问题可以直接把日志发出来定位。

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

- `ITLaunchAdManager` / `NSADInfoManager` —— 开屏广告加载与播放
- `NSListADInfoManager` —— 列表广告投放（含广点通 / InMobi / 京东 / 阿里妈妈四路数据）
- `RMNewsDetailWebADView(Adapter)` —— 正文广告位
- `ITSignInAutomaticallyCenter` / `ITSignInAutomaticallyManager` —— 原生自动签到
- `ITSettingViewController` —— 设置页（入口挂在其 `tableView.tableFooterView` 上）

## 已知限制

- 广告域名拦截走的是 `NSURLRequest` / `NSMutableURLRequest` 构造阶段改写，个别用 `CFNetwork` 直连的 SDK 不受影响
- 自动签到依赖登录态，未登录时只会在日志里留一条失败记录
- App 版本升级后类名/方法名可能变化，日志里出现「方法不存在」即说明该 hook 已失效

## 还能继续优化的地方

分析 9.52 二进制后整理出的候选，都没写进 1.0.0（改动风险高于收益，先在真机验证现有 hook 更稳妥）：

1. **启动 SDK 初始化**：阿里百川 `AlibcTradeSDK`、京东 Kepler、腾讯播放器、SignalR 长连接都在启动路径上，可以整体推迟到首帧之后，冷启动预计还能省几百毫秒
2. **阅读计时器**：`ITSignInAutomaticallyManager` 的 `createReadingTimer` / `createActiveWorkItem` 即使不用自动签到也在后台跑，可单独关掉省电
3. **阅读历史上报**：`ITNewsReadCloud` / `ITUpdateReadHistoryManager` 上报频率偏高，可合并成批量提交
4. **商城模块**：首页「大家都在买」相关 `RMShopMall*` 模块数据量大，可整块隐藏，首屏能少一次请求
5. **开屏素材预下载**：`batchDownloadImageAndCache` / `batchDownloadVideoAndCache` 目前跟随开屏开关一起跳过，可拆成独立开关
6. **图片并发**：弱网下 `SDWebImage` 与 `FSPlayer` 的预加载并发偏高，可调低以降低内存峰值

## 免责声明

仅供学习与个人设备使用，请勿分发修改后的 IPA。插件只做本地行为调整，不修改任何服务端数据。

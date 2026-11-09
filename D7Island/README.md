# D7Island — iPhone 14 Pro 尺寸的假灵动岛（iPhone 7 / iOS 15 rootless）

SpringBoard 级 overlay：黑胶囊悬浮在所有 App 之上，点按有触感并展开。尺寸 1:1 照搬 iPhone 14 Pro。

## 一、尺寸（源码 `src/D7Island.m` 顶部 6 个宏）

| 参数 | iPhone 14 Pro 实测（基准 393×852pt） | iPhone 7 采用值（屏宽 375pt） |
|---|---|---|
| 折叠宽 | 126 | **126** |
| 折叠高 | 37 | **37** |
| 折叠圆角 | 18.5（= 高/2，标准胶囊） | **18.5** |
| 展开宽 | 371（左右各留 11pt） | **353**（等比换算，保持 11pt 边距） |
| 展开高 | 88 | **88** |
| 顶部距 | 11 | **11** |

折叠态 x = (375 − 126) / 2 = **124.5**，左右各剩 124.5pt —— iPhone 7 状态栏的时间（左）与电池（右）**完整露出**，观感与刘海机一致。
展开态 353pt 宽会盖住整条状态栏，与 14 Pro 展开时行为相同。

## 二、行为

- 折叠：纯黑胶囊，无内容。
- 点按：`UIImpactFeedbackGenerator` Medium 触感 + spring 展开（damping 0.74）。
- 展开内容：左 56×56 封面（圆角 12）；无播放时显示 时间 + 电量%。
- 播放中：封面 + 歌名 + 歌手。播放状态走 **MediaRemote 私有符号**（`dlsym` 取
  `MRMediaRemoteGetNowPlayingInfo` / `MRMediaRemoteGetNowPlayingApplicationIsPlaying`），
  因为 SpringBoard 进程里 `MPNowPlayingInfoCenter.nowPlayingInfo` 基本取不到值；取不到时自动回落到时间/电量。
- 3.5 秒无操作自动收起。
- 触摸：`D7Win -pointInside:withEvent:` 仅在岛体内返回 YES，其余区域全部穿透。

## 三、构建（GitHub Actions，零本地依赖）

本机是 Windows 且 GitHub 下行实测只有约 24 KB/s，本地编译不现实。Actions 的 runner 在 GitHub 自己的网络上下 SDK，与本机带宽无关。

1. 打开 https://github.com/new ，仓库名 `D7Island`，Public，创建。
2. 进入仓库 → **Add file → Upload files**，把整个 `D7Island` 文件夹拖进去（拖文件夹会保留 `src/` 和 `.github/` 的目录结构；`Makefile`、`control`、`D7Island.plist`、`README.md` 也要一起传）。
3. 点 **Commit changes**。
4. 到 **Actions** 页签，`build` 会自动跑（约 3–5 分钟）。绿色勾后进入这次运行，底部 **Artifacts** 下载 `D7Island-deb`。
5. 解压得到 `com.d7.island_1.0_iphoneos-arm64.deb`（几百 KB）。

> Theos 的 SDK 仓库（`theos/sdks`）里 `iPhoneOS15.6.sdk` 是**目录**不是压缩包，workflow 已用 `git sparse-checkout` 单独取出该目录，别改成下载 `.tar.xz`。

本地构建（需要 macOS 或 Linux + Theos + iPhoneOS15.6.sdk）：

```bash
export THEOS=~/theos
make package FINALPACKAGE=1
```

## 四、安装（palera1n rootless + Filza）

1. 把 deb 放到手机 `/var/mobile/Documents/`。两种传法：
   - Filza 的 WebDAV：Filza → 底部「WebDAV」→ 打开服务器，Windows 浏览器访问 `http://<设备IP>:1111` 直接拖文件上去；
   - 或用 iCloud 云盘 / 邮件把 deb 发给自己，在手机上「用 Filza 打开」。
2. Filza 里进入 `/var/mobile/Documents/`，点 deb → 右上 **Install**。
3. 装完自动装到 `/var/jb/Library/MobileSubstrate/DynamicLibraries/D7Island.dylib` + `.plist`。
4. 注销：Filza 里执行 `killall -9 SpringBoard`（或 Sileo 的 Respring）。
5. 桌面顶部出现 126×37 的黑胶囊即成功。

## 五、调试

```bash
idevicesyslog | grep D7Island
```

启动会打印两行：`MediaRemote symbols: info=... playing=...` 与 `island up: collapsed 126x37 @ y=11`。

## 六、已知限制

1. **不显示** → `windowScene` 没挂上。代码已遍历 `connectedScenes` 取 ForegroundActive，并在启动早期每 0.5s 重试、最多 20 秒。
2. **整屏点不动** → `pointInside` 收口失效或父视图开了 `userInteractionEnabled`；本工程已规避。
3. **横屏**：岛仍在原位会压内容，V1 未处理。
4. **来电**：状态栏变 40pt 时展开态与通话横幅会叠，V1 未处理。
5. LCD 上纯黑没问题，但深色 App 背景下对比度弱，观感不如 OLED。

# 保姆级流程：从零到黑胶囊出现在 iPhone 7 上

全程约 **15 分钟**（其中 Actions 跑 3–5 分钟是你不用动手的等待）。

前置条件：iPhone 7 已做 palera1n **无根**越狱（桌面上有 Sileo），且装了 **Filza**。

若没有 Filza，见「阶段 4 的 B 方案」。



***

## 阶段 1：准备（2 分钟）



1. 手机解锁，桌面找到 **Sileo**（紫红色图标），点开能正常显示源列表 → 越狱活着。

2. 找到 **Filza**（蓝色文件夹图标），点开能看到 `/var/` 目录 → 文件管理器可用。

3. 电脑上确认工程目录存在：

   `C:\Users\1\Doubao\chats\2026-11-09\new-chat-1\D7Island`

   里面有：`Makefile`、`control`、`D7Island.plist`、`README.md`、`src\D7Island.m`、`.github\workflows\build.yml`、`layout\...\D7Island.plist`

> 检查点：这两件事有一件不成立就停下，先解决越狱 / Filza，后面全部动作都依赖它们。



***

## 阶段 2：建 GitHub 仓库（2 分钟）



1. 浏览器打开 [https://github.com](https://github.com) ，登录（没有账号先注册，邮箱验证完即可）。

2. 右上角 **+** → **New repository**。

3. 填写：

* **Repository name**：`D7Island`

* **Description**：留空也行，填 `Dynamic island overlay for iPhone 7`

* 选 **Public**

* **不要**勾 Add a README /.gitignore/license

1. 点 **Create repository**。

> 检查点：跳转到一个空仓库页面，中间显示 "Quick setup — if you've done this kind of thing before"。



***

## 阶段 3：上传文件 + 建 workflow（4 分钟）

### 3.1 先拖文件夹



1. 在空仓库页面，点中间那行 **uploading an existing file**（或右上 **Add file → Upload files**）。

2. 打开资源管理器，把整个 `D7Island` 文件夹**拖进**浏览器虚线框区域。

3. 等文件列表出现后，滚到底部点绿色 **Commit changes**。

> 检查点：仓库首页能看到 
>
> `Makefile`
>
> 、
>
> `control`
>
> 、
>
> `D7Island.plist`
>
> 、
>
> `README.md`
>
> 、
>
> `src`
>
> 、
>
> `layout`
>
>  几个条目。

### 3.2 手动补 workflow（**必做**）

浏览器拖拽经常吞掉以 `.` 开头的隐藏目录，`.github` 大概率没传上去，所以这一步手工建。



1. 仓库页 → **Add file → Create new file**。

2. 文件名输入框里直接填：`.github/workflows/build.yml`（带斜杠，GitHub 会自动建目录）。

3. 把下面这段**整段**粘贴进编辑区（删掉原有的空内容）：



```
name: build

on:
  push:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install deps
        run: |
          sudo apt-get update
          sudo apt-get install -y make git ldid

      - name: Fetch Theos
        run: |
          git clone --recursive --depth 1 https://github.com/theos/theos.git "$HOME/theos"
          echo "THEOS=$HOME/theos" >> "$GITHUB_ENV"

      - name: Fetch iOS 15.6 SDK
        run: |
          git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git /tmp/sdks
          cd /tmp/sdks
          git sparse-checkout set iPhoneOS15.6.sdk
          mkdir -p "$HOME/theos/sdks"
          cp -R /tmp/sdks/iPhoneOS15.6.sdk "$HOME/theos/sdks/"
          ls "$HOME/theos/sdks"

      - name: Build package
        run: make package FINALPACKAGE=1

      - uses: actions/upload-artifact@v4
        with:
          name: D7Island-deb
          path: packages/*.deb
```



1. 页面向下滚，**Commit changes** → 弹窗里再点一次 **Commit changes**。

> 检查点：仓库顶部出现 
>
> **Actions**
>
>  页签，里面有一条正在跑（黄点）的 
>
> `build`
>
> 。



***

## 阶段 4：等出包并下载（4 分钟，多为等待）



1. 点 **Actions** → 左边 **build** → 中间那条运行记录。

2. 黄点转绿勾（约 3–5 分钟）。展开每一步可看日志。

3. 绿勾后往下滚到底部 **Artifacts** → 点 **D7Island-deb** 下载。

4. 解压 zip，得到 `com.d7.island_1.0_iphoneos-arm64.deb`（几百 KB）。

**红叉怎么办**：点进失败的那一步，把红色日志整段复制给我，我改源码或 workflow。

最常见只有两种：`ldid` 装不上（改成 `sudo apt-get install -y ldid2 || sudo apt-get install -y ldid`）、SDK 目录名不对。

> 检查点：手里有一个 
>
> `.deb`
>
>  文件，文件名就是上面那个。



***

## 阶段 5：把 deb 传进手机（3 分钟）

### 方式 A：Filza 自带 WebDAV（最快，推荐）



1. 手机 Filza → 底部标签 **WebDAV**（有的版本叫 **Web Server**）→ 打开开关 → 记下地址，形如 `http://192.168.1.23:1111`。

2. 手机和电脑连同一个 WiFi。

3. 电脑浏览器打开这个地址，把 deb **拖进**网页里的文件列表，落到 `/var/mobile/Documents/`。

### 方式 B：iCloud 云盘

电脑打开 [https://www.icloud.com](https://www.icloud.com) → iCloud Drive → 上传 deb；手机「文件」App → iCloud 云盘 → 长按 deb → 共享 → **用 Filza 打开**。

### 方式 C：邮件

把 deb 作为附件发给自己，手机邮件里点附件 → 共享 → Filza。

> 检查点：手机 Filza 打开 
>
> `/var/mobile/Documents/`
>
> ，能看到那个 deb。



***

## 阶段 6：安装 + 注销（2 分钟）

### A 方案：Filza 点装



1. Filza 进入 `/var/mobile/Documents/`。

2. 点那个 deb 文件 → 弹出菜单里点 **Install**（有的版本是右上 **安装**）。

3. 等提示 `Finished` / `完成`。

4. 回到 Filza，左上角点 **⚙︎** → 或直接进 `/var/jb/Library/MobileSubstrate/DynamicLibraries/` 确认两个文件存在：

* `D7Island.dylib`

* `D7Island.plist`

1. 注销：Filza 里点右上 **终端 / Execute** 输入 `killall -9 SpringBoard`，或在 Sileo 里点 **Respring**。

### B 方案：没有 Filza，用终端



1. Sileo 里装 **NewTerm 3**（免费）。

2. 打开 NewTerm，输入：



```
su
```

密码 `alpine`（palera1n 无根默认 root 密码），然后：



```
dpkg -i /var/mobile/Documents/com.d7.island_1.0_iphoneos-arm64.deb
killall -9 SpringBoard
```

> 检查点：注销后回到锁屏 / 桌面。



***

## 阶段 7：验证与调整（1 分钟）

**应该看到**：桌面顶部正中一块 126×37 的纯黑胶囊，顶边距屏幕 11pt；左边时间、右边电池都露在外面。

**点一下**：轻微 “哒” 的触感，胶囊弹开到 353×88，左边一个方形封面位，右边显示时间 + 电量 %；若有音乐在播，显示封面 + 歌名 + 歌手。3.5 秒后自动收回。

**想改参数**（`src/D7Island.m` 顶部，改完重新走阶段 3 的 Commit，Actions 会自动重跑出包）：



| 想改的东西 | 改哪个宏                   | 说明                            |
| ----- | ---------------------- | ----------------------------- |
| 宽度    | `K_COLL_W` / `K_EXP_W` | 折叠 126、展开 353，改宽度后 x 会自动重新居中  |
| 高度    | `K_COLL_H` / `K_EXP_H` | 折叠 37、展开 88                   |
| 上下位置  | `K_TOP`                | 11 是照搬 14 Pro；想让它贴住屏幕顶边改 0    |
| 圆角    | `K_COLL_R` / `K_EXP_R` | 18.5 是标准胶囊（= 折叠高 / 2）；想更方改 14 |



***

## 排障表



| 现象                | 原因                      | 处理                                                                                                  |
| ----------------- | ----------------------- | --------------------------------------------------------------------------------------------------- |
| 注销后什么都没有          | dylib 没装进打包路径           | Filza 看 `/var/jb/Library/MobileSubstrate/DynamicLibraries/` 有没有 `D7Island.dylib`；没有就重装 deb          |
| 什么都没有，但 dylib 在   | ElleKit 没注入 SpringBoard | 先确认别的插件（比如任意 Sileo 装的小插件）能生效；不能则是越狱注入层问题，不是这个插件的问题                                                  |
| 黑块出现，但桌面点不动       | `pointInside` 收口失效      | 报给我，我改 `D7Win` 的判定                                                                                  |
| 只在部分 App 里消失      | 全屏 App 抢了窗口层级           | V1 已知限制，可后续 hook 全屏布局                                                                               |
| 横屏时压内容            | 未处理横屏                   | V1 已知限制                                                                                             |
| 来电时和通话横幅叠         | 状态栏变 40pt               | V1 已知限制                                                                                             |
| 装完白苹果 / 进安全模式     | 极少数情况                   | 用 Filza 删掉 `/var/jb/Library/MobileSubstrate/DynamicLibraries/D7Island.dylib` 后 respring 即可回退，不会破坏越狱 |
| Filza 装 deb 报依赖错误 | dpkg 依赖检查               | 本插件只依赖 `firmware (>= 15.0)`，不应发生；若报错把提示发我                                                           |



***

## 一次性回退

Filza 里删这两个文件，respring，桌面恢复原样：



```
/var/jb/Library/MobileSubstrate/DynamicLibraries/D7Island.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/D7Island.plist
```
# TRunner

**基于 AutoHotkey v2 的快速启动工具** 

| 项目 | 说明 |
|------|------|
| 版本 | **V0.27.8** |
| 作者 | 寻月 |
| 更新日期 | 2026-09-17 |
| 源代码 | https://github.com/delphixt/TRunner |
| 运行环境 | Windows + [AutoHotkey v2.0+](https://www.autohotkey.com/) |
| 配置文件 | `Settings.json`（UTF-8） |

TRunner 通过**按住鼠标右键并拖动**，在指针位置弹出圆形扇区菜单，一键启动程序、打开文件夹/网址、执行内置函数，或展开多级子菜单。也支持热键弹出、程序快速搜索、Profile 按窗口自动切换等能力。

初衷是自己使用，满足自己日常使用需求，所以并没有进行过多的优化，自身能力有限，也可能还有很多BUG，欢迎反馈或贡献代码。

---

## 目录

1. [功能特性](#功能特性)
2. [快速开始](#快速开始)
3. [基本操作](#基本操作)
4. [快捷键](#快捷键)
5. [扇区类型与编号](#扇区类型与编号)
6. [配置文件 Settings.json](#配置文件-settingsjson)
7. [Profile 自动切换](#profile-自动切换)
8. [内置配置编辑器](#内置配置编辑器)
9. [托盘菜单](#托盘菜单)
10. [内置功能函数](#内置功能函数)
11. [源码结构](#源码结构)
12. [视觉与交互架构](#视觉与交互架构)
13. [常见问题 FAQ](#常见问题-faq)
14. [版本说明](#版本说明)
15. [许可与致谢](#许可与致谢)

---

## 功能特性

### 圆形启动菜单
- 右键拖动弹出，圆心固定在按下位置
- 单圈 / 双圈 / 三圈自动布局（按扇区数量）
- 鼠标方向辅助线 + 当前扇区半透明高亮
- 四层分层窗口渲染（GDI+），点击穿透，不抢焦点
- 仅在菜单显示时临时置顶，空闲不占用 TOPMOST

### 三种扇区类型
| 类型 | 作用 |
|------|------|
| `run` | 启动程序 / 打开文件 / 文件夹 / URL |
| `menu` | 多级子菜单（可无限嵌套，支持图标与分隔线） |
| `function` | 调用脚本内置功能（截图、置顶、音量等） |

### 实用工具
- **程序快速搜索**（Listary 风格）：中文名 / 拼音首字母 / 英文
- **窗口管理**：居中、半屏、跨屏、置顶、隐藏/恢复
- **截图**：全屏 / 区域 / 活动窗口
- **剪贴板历史**：首次使用才启动监控
- **硬件信息**、**定时提醒**、**定时关机/重启/锁屏**
- **阻止熄屏**、**音量与媒体控制**

### 体验优化
- 配置热重载（检测 `Settings.json` 修改）
- Profile 按前台窗口自动切换扇区
- 图标缓存、分批加载程序列表
- 功能按需初始化，关闭时完整释放资源

---

## 快速开始

### 1. 安装 AutoHotkey v2

从官网安装 **AutoHotkey 2.0 或更高版本**（64 位 Windows 推荐 64 位 AHK）。

### 2. 获取 TRunner

将本仓库（或发布包）解压到本地目录，例如：

```text
C:\Apps\TRunner\
```

确保同目录下有：

- 入口脚本：`TRunnerV0.27.8.ahk`（结构化多文件版）  
  或 `TRunnerV0.27_single.ahk`（单文件版，包含所有功能，可能不太稳定）
- 配置：`Settings.json`
- 各子目录（结构化版）：`Core\`、`Tray\`、`CircleMenu\`、`Features\` 等

### 3. 启动

双击运行：

```text
TRunnerV0.27.8.ahk
```

启动成功后，任务栏通知区域会出现 TRunner 托盘图标。

### 4. 第一次使用

1. **按住右键并拖动** → 弹出圆形菜单  
2. 拖到目标扇区后**松开右键** → 执行该扇区动作  
3. 若只是**单击右键**（几乎不移动）→ 显示系统原生右键菜单（设计如此）

---

## 基本操作

### 右键拖动弹出圆形菜单

| 步骤 | 说明 |
|------|------|
| 1 | 在任意位置按住鼠标右键 |
| 2 | 向目标扇区方向拖动（超过约 5 像素阈值） |
| 3 | 屏幕显示圆形菜单 + 方向辅助线 + 扇区高亮 |
| 4 | 松开右键，执行当前高亮扇区 |

- **中心小圆**（取消半径内）松开：不执行任何操作  
- **圆环外**松开：不执行（或视为取消）  
- **ESC**：立即关闭菜单并取消本次手势  

### 热键弹出圆形菜单

按 **Win + Alt + 空格**，在**当前鼠标位置**弹出圆形菜单：

- 无需按住右键，移动鼠标即可高亮扇区  
- **左键**点击扇区执行  
- 点击中心/圈外、**右键** 或 **ESC** 关闭  

### 程序快速搜索

按 **Win + T** 或 **Win + 空格** 打开程序列表：

- 默认仅显示搜索框（Listary 风格）  
- 输入关键字后出现结果列表  
- 支持：中文名称、拼音首字母（如 `wx` → 微信）、英文路径  
- **↑ ↓** 选择，**Enter** 启动，**ESC** 关闭  

---

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| 右键拖动 | 弹出圆形启动菜单 |
| Win + Alt + 空格 | 在鼠标位置弹出圆形菜单（左键执行） |
| Win + T | 打开已安装程序搜索 |
| Win + 空格 | 同上（若被输入法占用请改用 Win+T） |
| Win + Alt + T | 弹出设置菜单（扇区列表式） |
| Win + Alt + F5 | 刷新视觉层并修复点击状态（异常时使用） |
| ESC | 关闭圆形菜单 / 程序列表 |

---

## 扇区类型与编号

### 编号规则

扇区用数字键 `"1"`、`"2"`、… 定义，数量不限。

| 扇区数量 | 布局 |
|----------|------|
| 1–8 | 单圈 |
| 9–16 | 双圈（内圈 → 外圈） |
| 17+ | 三圈（内 → 中 → 外） |

- **1 号**扇区中心在正上方（时钟 12 点）  
- 其余按**顺时针**排列  
- 多环：先内圈编号，再中圈、外圈  

### `run` 类型

直接运行可执行文件、文档、文件夹或 URL。

```json
"5": {
  "name": "记事本",
  "type": "run",
  "target": "notepad.exe",
  "icon": "shell32.dll,1"
}
```

支持环境变量，例如 `%USERPROFILE%`、带参数命令等。

### `menu` 类型

弹出子菜单。菜单项 `cmd` 约定：

| cmd 写法 | 含义 |
|----------|------|
| 普通路径/命令 | 运行该命令 |
| `>子菜单名` | 进入子菜单（在 `sub` 中定义） |
| `function:函数名` | 调用内置函数 |
| `---` | 分隔线 |

图标格式：`path:index` 或 `path,index`，例如 `shell32.dll:5`、`C:\app.exe:0`。

### `function` 类型

直接绑定脚本内置函数，例如：

```json
"3": {
  "name": "程序列表",
  "type": "function",
  "function": "ShowInstalledApps",
  "icon": "imageres.dll:249"
}
```

完整函数列表见下文[内置功能函数](#内置功能函数)。

---

## 配置文件 Settings.json

路径：与脚本同目录的 `Settings.json`。**必须使用 UTF-8 编码**。

### 顶层字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `showMenuIcon` | 0/1 | 子菜单项是否显示图标 |
| `showSectorIcon` | 0/1 | 圆形扇区是否显示图标 |
| `appearance` | 对象 | 外观参数 |
| `profiles` | 数组 | 窗口匹配 Profile（可选） |
| `"1"`, `"2"`, … | 对象 | 各扇区定义 |

### `appearance` 外观

| 键 | 默认 | 说明 |
|----|------|------|
| `windowSize` | 500 | 窗口边长 |
| `outerRadius` | 250 | 外圈半径 |
| `escapeRadius` | 40 | 中心取消半径 |
| `penColor` | FFFFFF | 分割线颜色 |
| `penWidth` | 2 | 分割线宽度 |
| `bgColor` | F0F0F0 | 背景色 |
| `textColor` | 000000 | 文字色 |
| `fontSize` | 14 | 字号 |
| `fontWeight` | 700 | 字重 |
| `background` | comfortable | `default` / `transparent` / `comfortable` |
| `backgroundAlpha` | 230 | 背景透明度 0–255 |
| `highlightColor` | 3399FF | 扇区高亮色 |
| `highlightAlpha` | 80 | 高亮透明度 |

### 最小示例

```json
{
  "showMenuIcon": 1,
  "showSectorIcon": 1,
  "appearance": {
    "windowSize": 500,
    "outerRadius": 250,
    "background": "comfortable",
    "backgroundAlpha": 200
  },
  "1": {
    "name": "系统工具",
    "type": "menu",
    "icon": "shell32.dll,317",
    "items": [
      { "text": "任务管理器", "cmd": "taskmgr.exe", "icon": "taskmgr.exe:0" },
      { "text": "记事本", "cmd": "notepad.exe", "icon": "notepad.exe:0" }
    ],
    "sub": {}
  },
  "5": {
    "name": "此电脑",
    "type": "run",
    "target": "explorer.exe ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
    "icon": "shell32.dll,16"
  },
  "9": {
    "name": "程序列表",
    "type": "function",
    "function": "ShowInstalledApps"
  }
}
```

修改保存后脚本会**自动热重载**；也可托盘「重载脚本」或 **Win+Alt+F5** 刷新视觉层。

---

## Profile 自动切换

Profile 用于**按当前前台窗口**自动换一套圆形菜单扇区。

每个 Profile 包含：

- `ahkHandles`：匹配规则（`ahk_exe` / `ahk_class` / `ahk_title`）
- `sectors`：该场景下的扇区配置

未匹配任何 Profile 时使用默认数字键扇区。托盘 **Profile** 子菜单可手动切换（单选勾选）。

```json
"profiles": [
  {
    "name": "Photoshop",
    "ahkHandles": "ahk_exe Photoshop.exe",
    "sectors": {
      "1": {
        "name": "工具",
        "type": "menu",
        "items": [
          { "text": "示例", "cmd": "notepad.exe", "icon": "" }
        ]
      }
    }
  }
]
```

未配置 `profiles` 时，托盘 Profile 仅显示「默认」，属正常现象。

---

## 内置配置编辑器

托盘菜单 → **配置设置**（或 Win+Alt+T 相关入口）。

主要能力：

- 新增 / 编辑 / 删除扇区，上移下移排序  
- 编辑 menu 类型的菜单项与子菜单  
- 全局外观设置（尺寸、颜色、字体、背景模式）  
- 保存时写入 `Settings.json` 并生成 `.bak` 备份，立即生效  

---

## 托盘菜单

右键任务栏 TRunner 图标：

| 菜单项 | 说明 |
|--------|------|
| 暂停脚本 | 暂停/恢复所有热键 |
| 暂停鼠标监控 | 仅停用右键拖动圆形菜单 |
| Profile | 手动切换扇区方案 |
| 打开配置文件/程序目录 | 资源管理器打开脚本目录 |
| 配置设置 | 打开内置配置编辑器 |
| 编辑脚本 | 记事本打开当前源文件 |
| 重载脚本 | 完整重载 |
| 刷新(异常时使用)　Win+Alt+F5 | 重建视觉层、修复点击状态 |
| 开机启动 | 写入/删除 HKCU Run |
| 锁屏 | LockWorkStation |
| 关机 ▸ | 注销 / 重启 / 关机 / 阻止熄屏 / 定时任务 / 取消定时 |
| 帮助 / 关于 | 说明文档与版本信息 |
| 退出脚本 | 完全退出 |

---

## 内置功能函数

可在扇区或菜单项中通过 `type: "function"` 或 `cmd: "function:名称"` 调用。

| 函数名 | 功能 |
|--------|------|
| `ShowInstalledApps` | 程序快速搜索启动 |
| `CaptureScreen` / `CaptureScreenRegion` / `CaptureActiveWindow` | 截图 |
| `OpenScreenshotsFolder` | 打开截图目录 |
| `ToggleDesktop` | 显示/隐藏桌面 |
| `ToggleWindowAlwaysOnTop` | 窗口置顶切换 |
| `HideWindowUnderMouse` / `ShowHiddenWindowManager` / `RestoreAllHiddenWindows` | 窗口隐藏管理 |
| `WindowCenter` / `WindowHalfLeft` / `WindowHalfRight` | 窗口布局 |
| `WindowMaximize` / `WindowRestore` / `WindowMoveNextMonitor` | 窗口状态 / 跨屏 |
| `ShowClipboardHistory` | 剪贴板历史 |
| `ShowHardwareInfo` | 硬件信息 |
| `ShowReminderManager` | 定时提醒 |
| `OpenTaskManager` / `EmptyRecycleBin` | 系统工具 |
| `CopySelectedText` / `CutSelectedText` / `PasteText` | 剪贴板操作 |
| `VolumeUp` / `VolumeDown` / `VolumeMute` | 音量 |
| `MediaPlayPause` / `MediaNext` / `MediaPrev` | 媒体 |
| `ShowTrayMenu` | 弹出托盘菜单 |
| `OpenCircleMenuFromHotkey` | 弹出圆形菜单 |
| `ShowHelp` / `ShowAbout` | 帮助 / 关于 |
| `ToggleSuspend` / `ReloadScript` | 脚本控制 |

完整列表以程序内「帮助 → 内置功能函数列表」为准。

---

## 源码结构

### 结构化版（推荐开发/维护）

```text
TRunnerV0.27.8.ahk          ; 入口（#Include 各模块）
Settings.json               ; 用户配置
Core/
  Version.ahk               ; 名称、版本、源码地址
  Json.ahk                  ; JSON 解析
  GdiPlus.ahk               ; GDI+ 生命周期
  TimerManager.ahk          ; 定时器集中管理
  PowerManager.ahk          ; 电源相关
  IconManager.ahk           ; 图标提取与缓存
  FeatureManager.ahk        ; 功能生命周期（注册/关闭）
  Globals.ahk               ; 全局状态与 GDI+ 绘制辅助
  Config.ahk                ; 配置加载 / Profile / 扇区
  HelpAbout.ahk             ; 帮助与关于
  MenuBuild.ahk             ; 菜单构建与扇区执行
Tray/TrayMenu.ahk           ; 托盘菜单
CircleMenu/
  Render.ahk                ; 四层分层窗口与位图
  RightClick.ahk            ; 右键状态机、刷新、运行时监控
  Input.ahk                 ; 右键热键、拖动采样、热键菜单
Features/
  InstalledApps/            ; 程序列表
  HiddenWindows/            ; 窗口隐藏
  Clipboard/                ; 剪贴板历史
  Hardware/                 ; 硬件信息
  Reminder/                 ; 定时提醒
  WinMgrMedia/              ; 窗口管理 / 截图 / 媒体
  PowerTasks/               ; 定时关机等
  TopMost/                  ; 置顶标记
ConfigEditor/               ; 图形化配置编辑器
Main/Main.ahk               ; StartTRunner 启动入口
```

### 单文件版

`TRunnerV0.27_single.ahk` 将上述模块合并为一个脚本，便于分发；功能与结构化版对齐。

### 设计原则

1. **Core 常驻**：配置、渲染、右键状态机、托盘  
2. **Feature 按需初始化**：首次使用才创建 GUI/Timer/缓存  
3. **关闭即释放**：Destroy GUI、停 Timer、清 ImageList/缓存  
4. 重任务用 Timer 分段，避免阻塞主事件循环  

---

## 视觉与交互架构

```text
                    ┌─────────────────────┐
  右键拖动 / 热键 ──►│  CircleMenu/Input   │
                    │  状态机 + CheckMove  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ CircleMenu/RightClick│  RefreshMenuVisuals
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  CircleMenu/Render   │  四层 Layered Window
                    │  GDI+ Bitmap 更新    │
                    └─────────────────────┘

四层窗口（均为 WS_EX_LAYERED + 点击穿透 + 不激活）：
  1. 静态层   — 背景、圆环、分割线
  2. 内容层   — 扇区文字、图标
  3. 高亮层   — 当前扇区半透明覆盖
  4. 辅助线层 — 圆心到鼠标的引导线
```

- 仅内容/外观变化时重建对应 Bitmap  
- 系统菜单（含托盘菜单）打开时**不拦截右键**，避免破坏菜单捕获  
- 右键 Down/Up **成对**处理，避免系统按键卡住  

---

## 常见问题 FAQ

**Q1：右键拖动不弹圆形菜单？**  
A：确认脚本已启动且未「暂停鼠标监控」。可试 **Win+Alt+空格**；或托盘「刷新」/「重载脚本」。启动后 1–2 秒内可能忽略右键。游戏/视频播放器占用鼠标钩子时，换位置重试。

**Q2：单击右键弹出的是系统菜单？**  
A：设计如此。只有拖动超过阈值才弹圆形菜单；几乎不移动的单击交还 Windows。

**Q3：Win+空格无效？**  
A：可能被输入法占用，请改用 **Win+T**。

**Q4：修改 Settings.json 未生效？**  
A：保存为 UTF-8；脚本会热重载。仍无效时用托盘「重载脚本」。

**Q5：圆形菜单与游戏冲突？**  
A：托盘「暂停鼠标监控」临时关闭右键拖动，热键仍可用。

**Q6：鼠标点击异常 / 右键像卡住？**  
A：托盘「刷新(异常时使用)」或 **Win+Alt+F5**；必要时重载脚本。

**Q7：如何定时关机？**  
A：托盘 → 关机 → 定时关机/重启/锁屏…，输入小时与分钟；用「取消定时管理」中止。

---

## 版本说明

### V0.27.8（当前）

- 版本号与关于/帮助展示对齐 TRunner V0.27.8  
- 帮助、关于中增加源代码地址：https://github.com/delphixt/TRunner  
- 托盘「刷新(异常时使用)」显示快捷键 **Win+Alt+F5**  
- 修复右键状态机相关问题（系统菜单期间放行右键、Down/Up 成对、防 SendInput 重入等）  
- 修复 GdiPlus 静态属性、Gui 构造选项、图标分批加载越界、FeatureManager 动态调用等问题  

### V0.27.0 结构化重构要点

- Core 常驻 + Feature 按需加载与完整释放  
- 硬件信息、剪贴板历史改为内置 function，不占用托盘一级菜单  
- 定时提醒；剪贴板首次使用才监控  
- 托盘「刷新」与 Win+Alt+F5  
- 空闲时不永久 TOPMOST  
- OnExit 统一 `FeatureManager.ShutdownAll()`  

更早变更见程序内「关于」或历史提交。

---

## 许可与致谢

- Copyright © 2026 寻月，保留所有权利。  
- 源代码：https://github.com/delphixt/TRunner  
- 依赖：[AutoHotkey v2](https://www.autohotkey.com/)、Windows GDI+ / User32 API  

欢迎在 GitHub 提交 Issue 与 Pull Request。

---

**TRunner V0.27.8** — 右键一拖，圆形直达。

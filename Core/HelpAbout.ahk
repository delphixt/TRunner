; ============================================================
;  3.9 帮助和关于
; ============================================================
; 单例窗口句柄：避免重复点击菜单时弹出多个窗口
HelpGui := ""
AboutGui := ""


; ======== Core/HelpAbout.ahk ========
; Core — Help/About
ShowHelp(*) {
    global HelpGui
    if IsObject(HelpGui) {
        try {
            if WinExist("ahk_id " HelpGui.Hwnd) {
                HelpGui.Show()
                WinActivate("ahk_id " HelpGui.Hwnd)
                return
            }
        }
        catch {
            HelpGui := ""
        }
    }
    helpGui := Gui("", AppName " - 使用帮助")
    HelpGui := helpGui
    helpGui.SetFont("s10", "微软雅黑")
    editCtrl := helpGui.Add("Edit", "xm ym w780 h680 ReadOnly VScroll", GetHelpText())
    editCtrl.SetFont("s10", "微软雅黑")
    helpGui.OnEvent("Close", CloseHelpGui)
    helpGui.OnEvent("Escape", CloseHelpGui)
    helpGui.Show("w810 h740")
}

CloseHelpGui(*) {
    global HelpGui
    if IsObject(HelpGui) {
        try HelpGui.Destroy()
    }
    HelpGui := ""
}

GetHelpText() {
    text := ""
    text .= AppName " " AppVersion " — 基于AutoHotkey的快速启动工具`n"
    text .= "作者：" AppAuthor " | 更新日期：" AppUpdateDate " | 基于 AutoHotkey v" A_AhkVersion "`n"
    text .= "源代码：" AppSourceUrl "`n"
    text .= "═══════════════════════════════════════════════════`n"

    text .= "注意！注意！！注意！！！`n说明：`n"
    text .= "1. 程序启动/重载期间如果鼠标右键按下，会把右键 Down/Up 成对交还给 Windows，避免留下悬空输入状态。`n"
    text .= "2. 程序在某些情况下，如游戏、视频播放器、优化工具等占用鼠标、键盘钩子的程序界面上层时，`n"
    text .= "   可能导致圆形启动器弹出失败。如果出现此问题，换一个位置重试即可解决。`n`n"

    text .= "【一、快速上手】`n"
    text .= "────────────────────────────────────────`n"
    text .= "1. 按住鼠标右键（不要松开）并拖动，在右键按下的位置弹出圆形启动器。`n"
    text .= "2. 圆心固定为右键按下时的屏幕坐标。`n"
    text .= "3. 拖动时显示从圆心指向鼠标的辅助线，便于确认方向。`n"
    text .= "4. 鼠标移动方向决定当前高亮的扇区。`n"
    text .= "5. 拖动到目标扇区后松开右键，即可运行该扇区绑定的动作。`n"
    text .= "   - 若为【程序/命令】，则直接启动。`n"
    text .= "   - 若为【菜单】，则弹出下级菜单供选择。`n"
    text .= "6. 如果不拖动鼠标，仅单击右键，则显示系统原有右键菜单，不影响正常使用。`n"
    text .= "7. 点击菜单项执行对应功能；若菜单项有图标，图标显示为系统 DLL 图标或自定义图标。`n"
    text .= "8. 按 Win+Alt+空格，可在鼠标位置直接弹出圆形窗口菜单：`n"
    text .= "   - 移动鼠标即可高亮扇区（无需按住按键）。`n"
    text .= "   - 左键点击扇区执行动作；点击中心/圈外、按右键或 ESC 关闭菜单。`n"
    text .= "9. 按 Win+T 或 Win+空格：默认只有一个搜索框；输入关键字后下方才出现结果，↑↓ 选择，Enter 启动，ESC 关闭。`n"
    text .= "10. 按 ESC 关闭圆形菜单。`n`n"

    text .= "【二、扇区编号规则】`n"
    text .= "────────────────────────────────────────`n"
    text .= "1. 每个扇区用数字键定义（如 `"1`", `" 2`", ...），数量不限。`n"
    text .= "   布局规则：`n"
    text .= "   - 1~8 个扇区：单圈布局。`n"
    text .= "   - 9~16 个扇区：双圈布局。`n"
    text .= "   - 17+ 个扇区：三圈布局。`n"
    text .= "2. 1 号扇区中心位于正上方（时钟 12 点 / 0 度方向）。`n"
    text .= "3. 2 号扇区按顺时针方向排到下一个位置。`n"
    text .= "4. 3 号及后续扇区继续按顺时针排列。`n"
    text .= "5. 多环模式编号：内圈 → 中圈 → 外圈。`n"
    text .= "6. 绘制、文字、图标、鼠标命中、功能执行使用同一套角度算法。`n`n"

    text .= "【三、扇区类型详解】`n"
    text .= "────────────────────────────────────────`n"
    text .= "扇区支持三种类型，在配置编辑器中设置：`n`n"
    text .= "▶ run（运行程序）`n"
    text .= "  • 直接运行一个可执行文件、文档、文件夹或 URL。`n"
    text .= "  • 目标可以是：taskmgr.exe、explorer、notepad.exe、https://xxx.com。`n"
    text .= "  • 支持带参数的命令，如：`"notepad.exe C:\test.txt`"。`n"
    text .= "  • 自动识别 EXE 图标，也可手动指定图标文件和索引。`n`n"
    text .= "▶ menu（多级子菜单）`n"
    text .= "  • 包含多个菜单项，类似 Windows 右键菜单。`n"
    text .= "  • 菜单项可以是普通命令、子菜单（>名称）或内部函数（function:名称）。`n"
    text .= "  • 使用 `">子菜单名称`" 创建子菜单，子菜单可无限嵌套。`n"
    text .= "  • 菜单项支持独立的图标（EXE/DLL/ICO + 索引）。`n"
    text .= "  • 使用 `"---`" 作为命令可创建分隔线。`n`n"
    text .= "▶ function（内部函数）`n"
    text .= "  • 直接调用脚本内置的功能函数，无需配置命令。`n"
    text .= "  • 可用函数见下方「内置功能函数列表」。`n"
    text .= "  • 函数名可在配置编辑器中通过下拉列表选择。`n`n"

    text .= "【四、菜单项命令格式】`n"
    text .= "────────────────────────────────────────`n"
    text .= "1. 普通命令：直接填写可执行文件路径或命令。`n"
    text .= "   例：taskmgr.exe、notepad.exe、C:\Tools\app.exe、https://cn.bing.com`n"
    text .= "2. 子菜单：命令以 `">`" 开头。`n"
    text .= "   例：>系统工具、>网络工具、>开发工具`n"
    text .= "3. 内部函数：命令以 `"function:`" 开头。`n"
    text .= "   例：function:CaptureScreen、function:ToggleDesktop`n"
    text .= "4. 分隔线：命令填写 `"---`"。`n"
    text .= "   在菜单中显示为一条灰色分隔线。`n"
    text .= "5. 图标格式：path:index 或 path,index。`n"
    text .= "   例：shell32.dll:5、imageres.dll,204、C:\app.exe:0`n"
    text .= "   索引 0 通常表示第一个图标。`n`n"

    text .= "【五、配置文件 Settings.json】`n"
    text .= "────────────────────────────────────────`n"
    text .= "配置文件 `"Settings.json`" 位于脚本同目录下，必须使用 UTF-8 编码。`n"
    text .= "顶层结构：`n"
    text .= "  • showMenuIcon (0/1)  — 菜单项是否显示图标（菜单项图标开关，1为显示，0为不显示）`n"
    text .= "  • showSectorIcon (0/1) — 扇区是否显示图标（扇区图标开关，需要图标文件存在，1为显示，0为不显示）`n"
    text .= "  • appearance (对象)    — 全局外观设置（见下方）`n"
    text .= "  • profiles (数组)      — 窗口匹配规则（自动切换扇区，见下方）`n"
    text .= "  • 数字键 (1,2,3...)    — 扇区定义（编号必须为数字字符串）`n`n"
    text .= "appearance 外观配置项：`n"
    text .= "  • windowSize      — 窗口尺寸（默认 500，范围 100-2000）`n"
    text .= "  • outerRadius     — 外圈半径（默认 250，范围 50-1000）`n"
    text .= "  • penColor        — 分割线颜色（十六进制，默认 FFFFFF）`n"
    text .= "  • penWidth        — 分割线宽度（默认 2，范围 1-20）`n"
    text .= "  • bgColor         — 背景颜色（十六进制，默认 F0F0F0）`n"
    text .= "  • textColor       — 文字颜色（十六进制，默认 000000）`n"
    text .= "  • fontSize        — 字体大小（默认 14，范围 6-72）`n"
    text .= "  • fontWeight      — 字体粗细（默认 700，范围 100-900）`n"
    text .= "  • highlightAlpha  — 高亮透明度（默认 255，范围 0-255）`n"
    text .= "  • highlightColor  — 高亮颜色（十六进制，默认 FFFFFF）`n"
    text .= "  • escapeRadius    — 取消半径（默认 40，范围 0-500）`n"
    text .= "  • background      — 背景模式（default / transparent / comfortable）`n"
    text .= "  • backgroundAlpha — 背景透明度（默认 230，范围 0-255）`n`n"
    text .= "Profile 自动切换规则：`n"
    text .= "  • 每个 Profile 包含 ahkHandles（匹配规则）和 sectors（扇区配置）。`n"
    text .= "  • 匹配规则支持 ahk_exe（进程名）、ahk_class（窗口类名）、ahk_title（标题）。`n"
    text .= "  • 当前窗口匹配到某个 Profile 时，自动使用该 Profile 的扇区配置。`n"
    text .= "  • 未匹配到任何 Profile 时，使用默认的数字键扇区。`n"
    text .= "  • 托盘「Profile」子菜单用于手动切换；勾选为单选，始终只有一项被勾中。`n"
    text .= "  • 未在 Settings.json 配置 profiles 时，子菜单只有「默认」，属正常现象。`n"
    text .= "  • 配置修改后自动热重载，无需手动重启脚本。`n`n"
    text .= '  "profiles": [`n'
    text .= '    {`n'
    text .= '      "name": "Photoshop",`n'
    text .= '      "ahkHandles": "ahk_exe Photoshop.exe",`n'
    text .= '      "sectors": {`n'
    text .= '        "1": { "name": "画笔", "type": "function", "function": "CycleBrush" }`n'
    text .= '      }`n'
    text .= '    }`n'
    text .= "  ]`n`n"

    text .= "每个扇区的配置包含：`n"
    text .= "   - `"name`" : 显示文字`n"
    text .= "   - `"type`" : 动作类型，可选 `"run`"（运行程序）、`"menu`"（弹出菜单）、`"function`"（调用脚本内函数）`n"
    text .= "   - `"target`" : type=run 时使用，程序路径（支持环境变量如 `"%USERPROFILE%`"）`n"
    text .= "   - `"items`" : type=menu 时使用，菜单项数组，每项含 `"text`"、`"cmd`"、可选 `"icon`"`n"
    text .= "   - `"function`" : type=function 时使用，脚本中定义的函数名（如 `"ShowSysMenu`"）`n"
    text .= "   - `"icon`" : 扇区图标路径（可选，支持系统 DLL 图标和自定义 .ico 文件）`n"
    text .= "   - `"sub`" : type=menu 时可选的子菜单定义，用于实现多级菜单`n`n"
    text .= "配置文件示例：`n"
    text .= '{`n'
    text .= '  "showMenuIcon": 1,`n'
    text .= '  "showSectorIcon": 1,`n'
    text .= '  "1": {`n'
    text .= '    "name": "系统工具",`n'
    text .= '    "type": "menu",`n'
    text .= '    "icon": "shell32.dll,100",`n'
    text .= '    "items": [`n'
    text .= '      {"text": "记事本", "cmd": "notepad.exe", "icon": "shell32.dll,1"},`n'
    text .= '      {"text": "计算器", "cmd": "calc.exe", "icon": "shell32.dll,2"}`n'
    text .= '    ]`n'
    text .= '  },`n'
    text .= '  "9": {`n'
    text .= '    "name": "我的电脑",`n'
    text .= '    "type": "run",`n'
    text .= '    "target": "explorer.exe",`n'
    text .= '    "icon": "shell32.dll,3"`n'
    text .= '  },`n'
    text .= '  "16": {`n'
    text .= '    "name": "系统菜单",`n'
    text .= '    "type": "function",`n'
    text .= '    "function": "ShowSysMenu"`n'
    text .= '  }`n'
    text .= '}`n`n'

    text .= "【六、内置配置编辑器】`n"
    text .= "────────────────────────────────────────`n"
    text .= "通过托盘菜单「配置设置」打开，是 TRunner 的内部管理窗口。`n`n"
    text .= "扇区管理：`n"
    text .= "  • 新增 — 创建新扇区，自动分配下一个编号。`n"
    text .= "  • 编辑 — 修改扇区编号、名称、类型、目标、函数、图标。`n"
    text .= "  • 编辑菜单项 — 对 menu 类型扇区，管理菜单项和子菜单。`n"
    text .= "  • 删除 — 删除选中扇区。`n"
    text .= "  • 上移/下移 — 调整扇区在列表中的顺序。`n"
    text .= "  • 保存配置 — 保存到 Settings.json 并立即应用，同时生成 .bak 备份。`n"
    text .= "  • 全局设置 — 修改外观、颜色、字体等全局参数。`n`n"
    text .= "菜单项编辑：`n"
    text .= "  • 添加/编辑/删除菜单项，支持上移/下移排序。`n"
    text .= "  • 编辑子菜单 — 对 `">名称`" 类型的菜单项，编辑其子菜单内容。`n"
    text .= "  • 菜单项类型：运行命令 / 内部函数 / 子菜单。`n"
    text .= "  • 图标自动识别：输入 EXE 路径后自动填充图标。`n`n"
    text .= "全局设置：`n"
    text .= "  • 菜单项显示图标 / 扇区显示图标（开关）。`n"
    text .= "  • 窗口尺寸、外圈半径、取消半径。`n"
    text .= "  • 分割线颜色/宽度、背景颜色、文字颜色。`n"
    text .= "  • 字体大小/粗细、背景模式、背景透明度。`n`n"

    text .= "【七、托盘菜单功能】`n"
    text .= "────────────────────────────────────────`n"
    text .= "右键点击任务栏 TRunner 图标可访问以下功能：`n`n"
    text .= "  • 暂停脚本 — 暂停/恢复所有脚本热键（不影响托盘菜单）。`n"
    text .= "  • 暂停鼠标监控 — 仅停止右键拖动圆形菜单，其他热键不受影响。`n"
    text .= "  • 打开配置文件/程序目录 — 在资源管理器中打开脚本所在文件夹。`n"
    text .= "  • 配置设置 — 打开内置配置编辑器。`n"
    text .= "  • 编辑脚本 — 用记事本打开当前 AHK 源文件。`n"
    text .= "  • 重载脚本 — 重新加载脚本（应用所有更改）。`n"
    text .= "  • 刷新 — 不重启脚本，重建视觉层并修复透明窗口/鼠标点击状态。快捷键：Win+Alt+F5。`n"
    text .= "  • 开机启动 — 切换是否开机自动启动 TRunner。`n"
    text .= "  • 锁屏 — 锁定 Windows 工作站。`n"
    text .= "  • 关机 > 注销/重启/关机/阻止熄屏/定时关机/定时重启/定时锁屏（自定义输入时间）/取消定时管理。`n"
    text .= "  • Profile 切换 — 切换当前圆形菜单配置。`n"
    text .= "  • 帮助 — 打开本帮助窗口。`n"
    text .= "  • 关于 — 显示版本和功能概览。`n"
    text .= "  • 退出脚本 — 完全退出 TRunner。`n`n"

    text .= "【八、内置功能函数列表】`n"
    text .= "────────────────────────────────────────`n"
    text .= "以下函数可在扇区或菜单项中通过 function:函数名 调用：`n`n"
    text .= "  • CaptureScreen         — 截取全屏并保存为 PNG，自动打开文件位置。`n"
    text .= "  • OpenScreenshotsFolder  — 打开截图文件夹。`n"
    text .= "  • ToggleDesktop          — 显示/隐藏桌面（等效 Win+D）。`n"
    text .= "  • ShowHelp               — 打开本帮助窗口。`n"
    text .= "  • ShowAbout              — 显示关于对话框。`n"
    text .= "  • ToggleSuspend          — 暂停/恢复脚本。`n"
    text .= "  • ShowTrayMenu           — 显示托盘菜单。`n"
    text .= "  • OpenTaskManager        — 打开任务管理器。`n"
    text .= "  • EmptyRecycleBin        — 清空回收站（不显示确认对话框）。`n"
    text .= "  • CopySelectedText       — 复制当前选中的文本（Ctrl+C）。`n"
    text .= "  • CutSelectedText        — 剪切当前选中的文本（Ctrl+X）。`n"
    text .= "  • PasteText              — 粘贴剪贴板内容（Ctrl+V）。`n"
    text .= "  • ToggleWindowAlwaysOnTop — 切换当前窗口的置顶状态。`n"
    text .= "  • HideWindowUnderMouse    — 隐藏鼠标下的窗口。`n"
    text .= "  • ShowHiddenWindowManager — 打开窗口隐藏管理器。`n"
    text .= "  • RestoreAllHiddenWindows — 恢复所有已隐藏的窗口。`n"
    text .= "  • ShowInstalledApps       — 程序快速搜索启动（Listary 风格）。`n"
    text .= "  • ShowHardwareInfo        — 显示系统硬件信息。`n"
    text .= "  • ShowClipboardHistory    — 打开剪贴板历史；首次使用才启动监控，关闭功能会停止监控并释放资源。`n"
    text .= "  • ShowReminderManager     — 定时提醒（间隔/每日/倒计时）；无任务时不运行提醒 Timer。`n"
    text .= "  • CaptureScreenRegion     — 框选区域截图。`n"
    text .= "  • CaptureActiveWindow     — 截取活动窗口。`n"
    text .= "  • WindowCenter / WindowHalfLeft / WindowHalfRight — 窗口居中/左右半屏。`n"
    text .= "  • WindowMaximize / WindowRestore / WindowMoveNextMonitor — 窗口状态与跨屏。`n"
    text .= "  • VolumeUp / VolumeDown / VolumeMute — 音量控制。`n"
    text .= "  • MediaPlayPause / MediaNext / MediaPrev — 媒体控制。`n"
    text .= "  • OpenCircleMenuFromHotkey — 在当前鼠标位置弹出圆形窗口菜单。`n"
    text .= "  • ReloadScript            — 重载脚本。`n`n"

    text .= "【九、视觉与交互优化】`n"
    text .= "────────────────────────────────────────`n"
    text .= "渲染架构说明：`n"
    text .= "  • 静态层 — 背景圆环、分割线`n"
    text .= "  • 内容层 — 扇区文字、图标`n"
    text .= "  • 高亮层 — 当前指向扇区的半透明覆盖（新增）`n"
    text .= "  • 辅助线层 — 鼠标方向引导线`n"
    text .= "视觉与交互说明：`n"
    text .= "• GDI+ 只初始化一次，全局复用，避免重复开销。`n"
    text .= "• 四层分层窗口：静态层（背景/圆环/分割线）、动态内容层（文字/图标）、`n"
    text .= "  高亮层（扇区高亮覆盖）、辅助线层（鼠标方向线）。`n"
    text .= "• 只有内容变化时才重建对应层级的 Bitmap，减少 GPU 操作。`n"
    text .= "• 扇区高亮跟随鼠标方向实时更新，鼠标移动到的扇区以半透明颜色高亮。`n"
    text .= "• 高亮颜色和透明度可在 Settings.json 的 appearance 中配置。`n"
    text .= "• HICON 使用 LRU 缓存，减少重复提取图标。`n"
    text .= "• 图标优先使用大尺寸 HICON（256x256），GDI+ 高质量缩放。`n"
    text .= "• 鼠标拖动时显示方向辅助线，低饱和灰青色，半透明。`n"
    text .= "• 圆心固定在右键按下位置，鼠标命中与视觉绘制使用统一坐标系。`n"
    text .= "• 分层窗口（WS_EX_LAYERED）实现平滑渲染和透明效果。`n"
    text .= "• 右键状态机集中管理，避免状态不一致。`n`n"

    text .= "【十、单文件代码结构】`n"
    text .= "────────────────────────────────────────`n"
    text .= "整个 TRunner 由单一 AHK 文件组成，按功能分为 6 个 Region：`n`n"
    text .= "Region 1 — 文件头与元信息`n"
    text .= "  #Requires / #SingleInstance / Persistent / CoordMode 等指令。`n`n"
    text .= "Region 2 — 公共基础类库`n"
    text .= "  2.1 class Json           — JSON 解析与序列化（Parse / Stringify）`n"
    text .= "  2.2 class GdiPlusManager — GDI+ 初始化与关闭，全局单例`n"
    text .= "  2.3 class TimerManager   — SetTimer 集中管理（注册/注销/暂停）`n"
    text .= "  2.4 class PowerManager   — 系统电源控制（关机/重启/阻止熄屏）`n"
    text .= "  2.5 class IconManager    — 图标提取、缓存与路径规范化`n`n"
    text .= "Region 3 — 主程序核心`n"
    text .= "  3.1  全局变量声明与 GDI+ 初始化`n"
    text .= "  3.2  GDI+ Alpha 混合渲染辅助函数`n"
    text .= "  3.3  数学工具 ATan2`n"
    text .= "  3.4  配置文件加载与解析（LoadConfig / LoadSectorsFromObj）`n"
    text .= "  3.5  配置文件热重载与 Profile 自动切换`n"
    text .= "  3.6  托盘菜单初始化（InitTrayMenu）`n"
    text .= "  3.7  鼠标监控开关（ToggleMouseMonitor）`n"
    text .= "  3.8  开机启动管理（ToggleStartup）`n"
    text .= "  3.9  帮助和关于（ShowHelp / ShowAbout）`n"
    text .= "  3.10 图标解析与菜单构建（ParseIcon / BuildMenuForSector / ExecuteSectorAction）`n"
    text .= "  3.11 窗口绘制与视觉缓存（GDI+ 分层窗口渲染、四层 Bitmap 缓存）`n"
    text .= "  3.12 右键交互状态机（CheckMouseMove / 右键拖动方向检测 / 扇区高亮）`n"
    text .= "  3.13 热键与圆形菜单（Win+T / Win+空格 → 程序列表 ； Win+Alt+空格 → 圆形菜单 ； ESC 关闭）`n`n"
    text .= "Region 4 — 内置功能函数库`n"
    text .= "  4.1  全局变量`n"
    text .= "  4.2  程序快速搜索（ShowInstalledApps / 拼音过滤）`n"
    text .= "  4.3  窗口隐藏管理（HiddenWindowManager / 隐藏/恢复窗口）`n"
    text .= "  4.4  截图功能（CaptureScreen / CaptureScreenToFile / PNG 编码）`n"
    text .= "  4.5  窗口置顶功能（ToggleWindowAlwaysOnTop / 置顶标记）`n"
    text .= "  4.6  定时电源任务（ScheduleShutdownInput / ScheduleRestartInput / ScheduleLockInput / SchedulePowerAction / CancelScheduledPowerTasks）`n"
    text .= "  4.7  阻止熄屏（SetPowerProtection / TogglePreventSleep）`n"
    text .= "  4.8  其他工具函数（任务管理器 / 回收站 / 桌面 / 剪贴板等）`n`n"
    text .= "Region 5 — 内置配置设置`n"
    text .= "  5.1  图标解析与编辑（IconEditor / IconAutoFillDebouncer）`n"
    text .= "  5.2  配置编辑器核心（EditorState / LoadConfigFile / SaveConfigFile）`n"
    text .= "  5.3  配置编辑器 GUI（BuildMainGui / EditSectorDialog / MenuEditorWindow）`n"
    text .= "  5.4  全局设置对话框（OpenGlobalSettings）`n`n"
    text .= "Region 6 — 启动入口`n"
    text .= "  ShowConfigEditor() — 打开配置编辑器。`n"
    text .= "  StartTRunner()     — 主程序启动：加载配置、初始化 GUI、注册热键和定时器。`n"
    text .= "  最后一行 StartTRunner() 自动执行启动。`n`n"

    text .= "【十一、鼠标命中与方向计算】`n"
    text .= "────────────────────────────────────────`n"
    text .= "1. 圆心固定为右键按下时的屏幕坐标。`n"
    text .= "2. 鼠标当前位置与圆心的 X/Y 偏移用于计算角度。`n"
    text .= "3. 屏幕坐标：X 向右增大，Y 向下增大。`n"
    text .= "4. 使用 ATan2 计算角度，与圆形菜单的顺时针绘制方向一致。`n"
    text .= "5. 辅助线方向与实际执行方向完全一致。`n"
    text .= "6. 点击圆心区域（取消半径内）不执行任何操作。`n"
    text .= "7. 鼠标在圆环外时，根据角度选中最近的扇区。`n`n"

    text .= "【十二、使用技巧】`n"
    text .= "• 扇区文字位置可通过修改 TextOut 的 X/Y 坐标偏移来微调。`n"
    text .= "• 图标与文字的相对位置可独立调整，互不影响。`n"
    text .= "• 配置文件修改后，可点击托盘菜单中的 `"重载脚本`" 使更改生效。`n"
    text .= "• 如需临时禁用所有热键，可使用托盘菜单中的 `"暂停脚本`" 功能。`n"
    text .= "• 如需临时禁用鼠标监控，可使用托盘菜单中的 `"暂停鼠标监控`" 功能。`n`n"

    text .= "【十三、技术实现】`n"
    text .= "• 基于 AutoHotkey v2.0 开发。`n"
    text .= "• 使用 GDI 绘制圆形背景、分割线和文字。`n"
    text .= "• 图标通过 ExtractIconEx 提取并使用 TransparentBlt 合成，保证透明。`n"
    text .= "• 菜单系统使用原生 Menu 对象，支持图标。`n"
    text .= "• 配置解析采用内嵌 JsonParser 类。`n"

    text .= "【十四、常见问题解答（FAQ）】`n"
    text .= "────────────────────────────────────────`n"
    text .= "Q1：右键拖动偶尔弹不出圆形菜单怎么办？`n"
    text .= "A1：按 ESC 后再试，或通过托盘菜单重载脚本。启动初始化期间会忽略右键；与占用鼠标钩子的程序（游戏/视频播放器）冲突时，可换位置重试或使用 Win+Alt+空格 热键弹出圆形菜单。`n`n"
    text .= "Q2：为什么单击右键弹出的是系统右键菜单而不是圆形菜单？`n"
    text .= "A2：这是设计行为。只有按住右键拖动超过阈值距离才会弹出圆形菜单；几乎不移动的单击会交还 Windows，弹出系统右键菜单。`n`n"
    text .= "Q3：如何设置任意时长的定时关机 / 定时重启 / 定时锁屏？`n"
    text .= "A3：点击托盘菜单 关机 → 定时关机... / 定时重启... / 定时锁屏...，在弹出窗口中输入小时和分钟即可，支持任意时长组合。三类任务共用同一套倒计时输入，同一时刻仅保留一个待执行任务；需要取消时选择 关机 → 取消定时管理。`n`n"
    text .= "Q4：圆形菜单与游戏、视频播放器或其他占用鼠标钩子的程序冲突怎么办？`n"
    text .= "A4：点击托盘菜单 暂停鼠标监控 可临时停用右键拖动圆形菜单（不影响热键）；需要时再次点击恢复。`n`n"
    text .= "Q5：修改 Settings.json 后配置没有生效？`n"
    text .= "A5：确认文件保存为 UTF-8 编码。脚本会每秒检测配置文件改动并自动热重载；也可通过托盘菜单 重载脚本 强制生效。`n`n"
    text .= "Q6：刚启动脚本时右键按下没反应？`n"
    text .= "A6：启动初始化期间会忽略右键操作，等待 1~2 秒完成启动后即可正常使用；若长时间无响应，请通过托盘菜单 重载脚本。`n`n"
    text .= "Q7：Win+空格被 Windows 输入法占用怎么办？`n"
    text .= "A7：程序列表窗口也可用 Win+T 打开；圆形菜单可用 Win+Alt+空格 打开；右键拖动不受影响。`n`n"

    text .= "═══════════════════════════════════════════════════`n"
    text .= AppName " v " AppVersion " — AutoHotkey v" A_AhkVersion " 兼容版`n"

    return text
}

; ============================================================
;  关于页面：显示程序名称、语义化版本号、版权声明、开发者信息、
;  运行环境与版本更新记录。所有信息来自文件头部的版本信息常量，
;  保证"关于"与"帮助"中显示的内容准确、统一、易于维护。
; ============================================================
ShowAbout(*) {
    global AboutGui
    if IsObject(AboutGui) {
        try {
            if WinExist("ahk_id " AboutGui.Hwnd) {
                AboutGui.Show()
                WinActivate("ahk_id " AboutGui.Hwnd)
                return
            }
        }
        catch {
            AboutGui := ""
        }
    }
    aboutGui := Gui("+AlwaysOnTop -MinimizeBox", "关于 " AppName)
    AboutGui := aboutGui
    aboutGui.SetFont("s9", "微软雅黑")

    ; 程序名（大字）— 显式指定高度，避免 s16 字体被默认控件高度裁切
    aboutGui.SetFont("s16 bold", "微软雅黑")
    aboutGui.Add("Text", "x16 y16 w430 h32 Center", AppName)
    aboutGui.SetFont("s9", "微软雅黑")
    ; 版本号与更新日期
    aboutGui.Add("Text", "x16 y54 w430 Center", "版本 " AppVersion "（语义化版本）　　更新日期：" AppUpdateDate).SetFont("s10", "微软雅黑")
    ; 信息区（开发者 / 版权 / 环境 / 版本记录）
    aboutGui.Add("Edit", "x16 y86 w430 h240 ReadOnly VScroll", GetAboutInfoText())
    ; 按钮行
    helpBtn := aboutGui.Add("Button", "x96 y344 w100 Default", "使用帮助")
    okBtn := aboutGui.Add("Button", "x266 y344 w100", "确定")

    ; 使用帮助：关闭关于页并打开帮助窗口
    helpBtn.OnEvent("Click", ShowHelpFromAbout)
    okBtn.OnEvent("Click", CloseAboutGui)
    aboutGui.OnEvent("Close", CloseAboutGui)
    aboutGui.OnEvent("Escape", CloseAboutGui)

    aboutGui.Show()
}

CloseAboutGui(*) {
    global AboutGui
    if IsObject(AboutGui) {
        try AboutGui.Destroy()
    }
    AboutGui := ""
}

ShowHelpFromAbout(*) {
    CloseAboutGui()
    ShowHelp()
}

; 组装关于页面的信息正文（开发者、版权、运行环境、版本更新记录）。
GetAboutInfoText() {
    text := ""
    text .= AppName " V " AppVersion " — 基于AutoHotkey的快速启动工具`n"
    text .= "开发者：" AppAuthor "`n"
    text .= "版权：" AppCopyright "`n"
    text .= "源代码：" AppSourceUrl "`n"
    text .= "运行环境：AutoHotkey V" A_AhkVersion " ｜ " A_OSVersion "（" (A_PtrSize * 8) " 位）`n"
    text .= "功能简介：右键拖动弹出圆形快速启动菜单；支持 run / menu / function 三种扇区类型与 Profile 自动切换。`n`n"

    return text
}

; ============================================================

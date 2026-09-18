; ========== 全局配置 ==========

; ================== 菜单 ==================


; ======== Core/TrayMenu.ahk ========
; Core — Tray
InitTrayMenu() {
    tray := A_TrayMenu
    tray.Delete()   ; 清除所有默认菜单项

    ; --- 系统功能 ---
    tray.Add("暂停脚本", ToggleSuspend)
    try tray.SetIcon("暂停脚本", "autohotkey.exe", 5)
    ; --- 鼠标监控开关 ---
    tray.Add("暂停鼠标监控", ToggleMouseMonitor)
    try tray.SetIcon("暂停鼠标监控", "ddores.dll", 30)
    ; Profile 子菜单
    global ProfileMenu
    ProfileMenu := BuildProfileMenu()
    tray.Add("Profile", ProfileMenu)
    try tray.SetIcon("Profile", "shell32.dll", 69)
    tray.Add("打开配置文件/程序目录", (*) => Run(A_ScriptDir))
    try tray.SetIcon("打开配置文件/程序目录", "shell32.dll", 5)
    tray.Add("配置设置", ShowConfigEditor)
    try tray.SetIcon("配置设置", "shell32.dll", 317)
    tray.Add("编辑脚本", (*) => Run("notepad.exe " A_ScriptFullPath))
    try tray.SetIcon("编辑脚本", "imageres.dll", 243)
    tray.Add("重载脚本", ReloadScript)
    try tray.SetIcon("重载脚本", "shell32.dll", 239)

    tray.Add("刷新UI`tWin+Alt+F5", ForceRefreshTRunner)
    try tray.SetIcon("刷新UI`tWin+Alt+F5", "shell32.dll", 239)

    tray.Add("开机启动", ToggleStartup)
    try tray.SetIcon("开机启动", "shell32.dll", 138)
    try UpdateStartupMenuCheck()
    ; 分隔线
    tray.Add()
    ; 锁屏
    tray.Add("锁屏", (*) => DllCall("LockWorkStation"))
    try tray.SetIcon("锁屏", "shell32.dll", 48)
    ; 关机子菜单
    global PowerMenu
    PowerMenu := Menu()
    mShutDown := PowerMenu
    mShutDown.Add("注销", (*) => Shutdown(0))
    mShutDown.Add("重启", (*) => Shutdown(2))
    mShutDown.Add("关机", (*) => Shutdown(1))
    try mShutDown.SetIcon("注销", "shell32.dll", 112)
    try mShutDown.SetIcon("重启", "shell32.dll", 298)
    try mShutDown.SetIcon("关机", "shell32.dll", 216)
    mShutDown.Add()
    ; 阻止熄屏 / 睡眠
    mShutDown.Add("阻止熄屏/睡眠", TogglePreventSleep)
    try mShutDown.SetIcon("阻止熄屏/睡眠", "shell32.dll", 43)
    mShutDown.Add()
    ; 定时任务：关机 / 重启 / 锁屏，统一倒计时输入 (V0.24.0)
    mShutDown.Add("定时关机...", ScheduleShutdownInput)
    try mShutDown.SetIcon("定时关机...", "shell32.dll", 240)
    mShutDown.Add("定时重启...", ScheduleRestartInput)
    try mShutDown.SetIcon("定时重启...", "shell32.dll", 240)
    mShutDown.Add("定时锁屏...", ScheduleLockInput)
    try mShutDown.SetIcon("定时锁屏...", "shell32.dll", 48)
    mShutDown.Add("取消定时管理", CancelScheduledPowerTasks)
    try mShutDown.SetIcon("取消定时管理", "shell32.dll", 132)
    tray.Add("关机", mShutDown)
    try tray.SetIcon("关机", "shell32.dll", 113)
    tray.Add()
    ; 帮助和关于
    tray.Add("帮助", ShowHelp)
    try tray.SetIcon("帮助", "shell32.dll", 155)
    tray.Add("关于", ShowAbout)
    try tray.SetIcon("关于", "shell32.dll", 278)

    ; 退出脚本（放在最后）
    tray.Add()
    tray.Add("退出脚本", (*) => ExitApp())
    try tray.SetIcon("退出脚本", "shell32.dll", 27)
}

ToggleSuspend(*) {
    Suspend(!A_IsSuspended)
    UpdateTrayStatus()
    ShowAppNotify("TRunner", A_IsSuspended ? "脚本已暂停，热键暂时无效" : "脚本已恢复", "info")
}

; ============================================================
; 应用内通知：不依赖系统 Toast
; 原因：本机 ToastEnabled=0（系统通知关闭）时 TrayTip 完全不可见。
; 策略：自绘置顶小窗 + ToolTip 兜底 + 托盘勾选/悬停说明。
; ============================================================
ShowAppNotify(title, text, kind := "info", ms := 2800) {
    ; 1) 仍尝试系统托盘气泡（若用户稍后打开通知则可见）
    try TrayTip(text, title, "Iconi")
    ; 2) ToolTip：几乎总是可见，放在鼠标旁
    try ToolTip(title "`n`n" text)
    ; 3) 自绘通知条：任务栏右下角附近，自动消失
    try ShowAppToastGui(title, text, kind, ms)
    SetTimer(() => ToolTip(), -ms)
}

AppToastGui := ""

ShowAppToastGui(title, text, kind, ms) {
    global AppToastGui
    try {
        if IsObject(AppToastGui)
            AppToastGui.Destroy()
    }
    AppToastGui := ""

    ; 不要用 +E0x20 等非常规 Gui 构造选项（AHK v2 可能判 Invalid option）
    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "TRunnerNotify")
    g.SetFont("s10", "微软雅黑")
    g.BackColor := (kind = "error") ? "8B1E1E" : (kind = "ok" ? "1F6F4A" : "2B2B2B")
    g.AddText("x14 y10 w320 cWhite", title)
    g.SetFont("s9", "微软雅黑")
    g.AddText("x14 y36 w320 r4 cWhite", text)

    ; 定位到任务栏上方（主屏右下）
    w := 348, h := 120
    sx := A_ScreenWidth - w - 16
    sy := A_ScreenHeight - h - 56
    g.Show("x" sx " y" sy " w" w " h" h " NoActivate")
    AppToastGui := g
    hwnd := g.Hwnd
    ; 点击穿透，避免挡住桌面操作
    try {
        longFunc := A_PtrSize = 8 ? "user32\GetWindowLongPtr" : "user32\GetWindowLong"
        setFunc := A_PtrSize = 8 ? "user32\SetWindowLongPtr" : "user32\SetWindowLong"
        ex := DllCall(longFunc, "Ptr", hwnd, "Int", -20, "Ptr")
        ex |= 0x20 | 0x08000000 | 0x80000
        DllCall(setFunc, "Ptr", hwnd, "Int", -20, "Ptr", ex)
    }
    SetTimer(() => HideAppToastGui(), -ms)
}

HideAppToastGui(*) {
    global AppToastGui
    try {
        if IsObject(AppToastGui)
            AppToastGui.Destroy()
    }
    AppToastGui := ""
    try ToolTip()
}

; ================== 鼠标监控功能 ==================
; ============================================================
; 鼠标监控开关 只负责“暂停/恢复”，不自行维护右键状态机。
; ============================================================
ToggleMouseMonitor(*) {
    global MouseMonitorPaused
    MouseMonitorPaused := !MouseMonitorPaused
    try ResetMouseInteractionState(true)
    if MouseMonitorPaused
        ShowAppNotify(AppName, "鼠标监控已暂停", "info")
    else
        ShowAppNotify(AppName, "鼠标监控已启用", "ok")
    UpdateTrayStatus()
}

; 1. 托盘菜单勾选状态  2. 托盘图标 Tooltip  3. 当前运行状态说明
UpdateTrayStatus() {
    global MouseMonitorPaused
    global PreventSleep
    global PowerMenu
    global CurrentProfile

    ; 托盘菜单勾选状态
    scriptPaused := A_IsSuspended
    try {
        if scriptPaused
            A_TrayMenu.Check("暂停脚本")
        else
            A_TrayMenu.Uncheck("暂停脚本")
    }
    try {
        if MouseMonitorPaused
            A_TrayMenu.Check("暂停鼠标监控")
        else
            A_TrayMenu.Uncheck("暂停鼠标监控")
    }
    try UpdateStartupMenuCheck()
    ; 只刷新 Profile 子菜单内容，不 Delete/Add 托盘项（否则会跑到菜单末尾）
    try RefreshProfileMenu()
    ; 同步阻止熄屏托盘勾选状态
    try {
        if IsObject(PowerMenu) {
            if PreventSleep
                PowerMenu.Check("阻止熄屏/睡眠")
            else
                PowerMenu.Uncheck("阻止熄屏/睡眠")
        }
    }

    ; 托盘图标 Tooltip
    statusText := AppName " V " AppVersion " `n"
        . "基于AutoHotkey的快速启动工具"

    if scriptPaused && MouseMonitorPaused {
        statusText .= "`n状态：脚本已暂停"
        statusText .= "`n鼠标监控：已暂停"
    }
    else if scriptPaused {
        statusText .= "`n状态：脚本已暂停"
        statusText .= "`n鼠标监控：已启用"
    }
    else if MouseMonitorPaused {
        statusText .= "`n状态：脚本运行中"
        statusText .= "`n鼠标监控：已暂停"
    }
    else {
        statusText .= "`n状态：脚本运行中"
        statusText .= "`n鼠标监控：已启用"
    }
    if PreventSleep
        statusText .= "`n阻止熄屏：已启用"
    else
        statusText .= "`n阻止熄屏：未启用"
    statusText .= "`n开机启动：" (IsStartupEnabled() ? "已启用" : "未启用")
    if (CurrentProfile != "")
        statusText .= "`nProfile：" CurrentProfile
    else
        statusText .= "`nProfile：默认"
    A_IconTip := statusText
    ; 强制刷新托盘图标 Tooltip 不改变图标本身，只更新状态提示。
    try {
        TraySetIcon("comres.dll", 1, true)  ; 冻结图标，防止图标被改变
    }
}

; ============================================================
;  3.8 开机启动管理 (ToggleStartup)
; ============================================================
; 注册表 Run 项；用托盘菜单勾选 + 详细提示反馈结果（Windows 可能吞掉托盘气泡）。
StartupRegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
StartupRegName := "TRunner"

IsStartupEnabled() {
    global StartupRegKey, StartupRegName
    try {
        val := RegRead(StartupRegKey, StartupRegName)
        return (val != "")
    } catch {
        return false
    }
}

UpdateStartupMenuCheck() {
    try {
        if IsStartupEnabled()
            A_TrayMenu.Check("开机启动")
        else
            A_TrayMenu.Uncheck("开机启动")
    }
}

; 同时输出应用内通知 + 托盘勾选，并刷新悬停说明。
ReportStartupStatus(title, detail, kind := "info") {
    ShowAppNotify(title, detail, kind, 3500)
    try UpdateTrayStatus()
    UpdateStartupMenuCheck()
}

ToggleStartup(*) {
    global StartupRegKey, StartupRegName
    scriptPath := A_ScriptFullPath
    enabled := IsStartupEnabled()

    if enabled {
        try {
            RegDelete(StartupRegKey, StartupRegName)
        } catch as e {
            ReportStartupStatus("开机启动", "取消失败：" e.Message, "error")
            return
        }
        if IsStartupEnabled() {
            ReportStartupStatus("开机启动", "取消失败：注册表项仍存在", "error")
            return
        }
        ReportStartupStatus("开机启动", "已取消开机启动。`n托盘菜单「开机启动」勾选应已去掉。", "ok")
    } else {
        try {
            RegWrite(scriptPath, "REG_SZ", StartupRegKey, StartupRegName)
        } catch as e {
            ReportStartupStatus("开机启动", "设置失败：" e.Message, "error")
            return
        }
        verify := ""
        try verify := RegRead(StartupRegKey, StartupRegName)
        if (verify != scriptPath) {
            ReportStartupStatus("开机启动", "设置可能失败。`n读回值：" verify, "error")
            return
        }
        ReportStartupStatus("开机启动", "已启用开机启动。`n路径：" scriptPath "`n托盘菜单「开机启动」应有勾选。", "ok")
    }

    try UpdateTrayStatus()
}

; ============================================================

; ---------- 窗口单例辅助 ----------
; AHK v2：用 & 传引用；若窗口仍存在则激活并返回该 Gui，否则返回 ""。
EnsureSingletonGui(&guiRef) {
    if IsObject(guiRef) {
        try {
            if WinExist("ahk_id " guiRef.Hwnd) {
                guiRef.Show()
                WinActivate("ahk_id " guiRef.Hwnd)
                return guiRef
            }
        } catch {
            guiRef := ""
        }
    }
    return ""
}

; ---------- 窗口管理 ----------
GetTargetHwnd() {
    try {
        MouseGetPos(, , &hwnd)
        if hwnd
            return hwnd
    }
    try return WinGetID("A")
    return 0
}


; ======== Features/WinMgrMedia.ahk ========
; Features — WinMgr/Shot/HW/Clip/Media/Profile
WindowCenter(*) {
    hwnd := GetTargetHwnd()
    if !hwnd
        return
    try {
        WinGetPos(, , &w, &h, "ahk_id " hwnd)
        WinRestore("ahk_id " hwnd)
        WinMove((A_ScreenWidth - w) // 2, (A_ScreenHeight - h) // 2, , , "ahk_id " hwnd)
    }
}

WindowHalfLeft(*) {
    hwnd := GetTargetHwnd()
    if !hwnd
        return
    try {
        WinRestore("ahk_id " hwnd)
        WinMove(0, 0, A_ScreenWidth // 2, A_ScreenHeight, "ahk_id " hwnd)
    }
}

WindowHalfRight(*) {
    hwnd := GetTargetHwnd()
    if !hwnd
        return
    try {
        WinRestore("ahk_id " hwnd)
        WinMove(A_ScreenWidth // 2, 0, A_ScreenWidth // 2, A_ScreenHeight, "ahk_id " hwnd)
    }
}

WindowMaximize(*) {
    hwnd := GetTargetHwnd()
    if hwnd
        try WinMaximize("ahk_id " hwnd)
}

WindowRestore(*) {
    hwnd := GetTargetHwnd()
    if hwnd
        try WinRestore("ahk_id " hwnd)
}

WindowMoveNextMonitor(*) {
    hwnd := GetTargetHwnd()
    if !hwnd
        return
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        monCount := MonitorGetCount()
        current := 1
        loop monCount {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b) {
                current := A_Index
                break
            }
        }
        next := (current = monCount) ? 1 : current + 1
        MonitorGet(next, &l, &t, &r, &b)
        nx := l + ((r - l) - w) // 2
        ny := t + ((b - t) - h) // 2
        if (nx < l)
            nx := l
        if (ny < t)
            ny := t
        WinMove(nx, ny, , , "ahk_id " hwnd)
    }
}

; ---------- 区域截图（框选） ----------
CaptureRegionGui := ""
CaptureStartX := 0, CaptureStartY := 0
CaptureDragging := false

CaptureScreenRegion(*) {
    global CaptureRegionGui
    if EnsureSingletonGui(&CaptureRegionGui)
        return
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    g.BackColor := "000000"
    WinSetTransparent(50, g)
    g.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
    CaptureRegionGui := g
    Hotkey("$*LButton", CaptureRegionDown, "On")
    Hotkey("$*LButton Up", CaptureRegionUp, "On")
    Hotkey("$*Escape", CaptureRegionCancel, "On")
    TrayTip("区域截图", "按住左键拖拽选择区域，ESC 取消", "Iconi")
}

CaptureRegionDown(*) {
    global CaptureStartX, CaptureStartY, CaptureDragging
    MouseGetPos(&x, &y)
    CaptureStartX := x
    CaptureStartY := y
    CaptureDragging := true
}

CaptureRegionUp(*) {
    global CaptureStartX, CaptureStartY, CaptureDragging
    if !CaptureDragging
        return
    CaptureDragging := false
    MouseGetPos(&x, &y)
    EndCaptureRegion(x, y)
}

EndCaptureRegion(x, y) {
    global CaptureStartX, CaptureStartY, CaptureRegionGui
    Hotkey("$*LButton", "Off")
    Hotkey("$*LButton Up", "Off")
    Hotkey("$*Escape", "Off")
    if IsObject(CaptureRegionGui) {
        try CaptureRegionGui.Destroy()
        CaptureRegionGui := ""
    }
    x1 := Min(CaptureStartX, x)
    y1 := Min(CaptureStartY, y)
    w := Abs(x - CaptureStartX)
    h := Abs(y - CaptureStartY)
    if (w < 5 || h < 5)
        return
    SaveRegionToFile(x1, y1, w, h)
}

CaptureRegionCancel(*) {
    global CaptureRegionGui, CaptureDragging
    CaptureDragging := false
    Hotkey("$*LButton", "Off")
    Hotkey("$*LButton Up", "Off")
    Hotkey("$*Escape", "Off")
    if IsObject(CaptureRegionGui) {
        try CaptureRegionGui.Destroy()
        CaptureRegionGui := ""
    }
}

CaptureActiveWindow(*) {
    hwnd := WinGetID("A")
    if !hwnd
        return
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w > 0 && h > 0)
            SaveRegionToFile(x, y, w, h)
    }
}

SaveRegionToFile(x, y, w, h) {
    try {
        folder := A_ScriptDir "\TRunner\Screens"
        if !DirExist(folder)
            DirCreate(folder)
        file := folder "\Shot_" FormatTime(A_Now, "yyyyMMdd_HHmmss") ".bmp"
        ; 使用 GDI 截取屏幕区域
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        mdc := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
        hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
        old := DllCall("SelectObject", "Ptr", mdc, "Ptr", hbm, "Ptr")
        DllCall("BitBlt", "Ptr", mdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdc, "Int", x, "Int", y, "UInt", 0x00CC0020)
        DllCall("SelectObject", "Ptr", mdc, "Ptr", old)
        DllCall("DeleteDC", "Ptr", mdc)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        ; 通过 PowerShell 或 GDI+ 保存为 PNG 太重，这里用 BMP + 系统转换
        SaveHBitmapAsPng(hbm, file)
        DllCall("DeleteObject", "Ptr", hbm)
        if FileExist(file) {
            TrayTip("截图已保存", file, "Iconi")
            try Run('explorer /select,"' file '"')
        } else {
            TrayTip("截图失败", "无法写入文件", "Icon!")
        }
    } catch as e {
        TrayTip("截图失败", e.Message, "Icon!")
    }
}

; 用 GDI+ 将 HBITMAP 保存为 PNG
SaveHBitmapAsPng(hbm, file) {
    gpBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &gpBitmap)
    if !gpBitmap
        return false
    ; 查找 PNG 编码器 CLSID
    DllCall("gdiplus\GdipGetImageEncodersSize", "UInt*", &num, "UInt*", &size)
    encBuf := Buffer(size)
    DllCall("gdiplus\GdipGetImageEncoders", "UInt", num, "UInt", size, "Ptr", encBuf)
    ; ImageCodecInfo: Clsid 在偏移 0 (16 bytes)，MimeType 在偏移 48 on x64
    clsidBuf := Buffer(16)
    found := false
    loop num {
        offset := (A_Index - 1) * 76  ; 76 is typical ImageCodecInfo size on x64 with padding; try common sizes
        ; 也尝试 104 结构体（历史代码偏移）
        mimePtr := NumGet(encBuf, offset + 48, "Ptr")
        if mimePtr {
            mime := StrGet(mimePtr, "UTF-16")
            if (mime = "image/png") {
                DllCall("RtlMoveMemory", "Ptr", clsidBuf, "Ptr", encBuf.Ptr + offset, "UPtr", 16)
                found := true
                break
            }
        }
    }
    ; 回退：硬编码 PNG CLSID {557CF406-1A04-11D3-9A73-0000F81EF32E}
    if !found {
        NumPut("UInt", 0x557CF406, "UShort", 0x1A04, "UShort", 0x11D3, clsidBuf, 0)
        NumPut("UChar", 0x9A, "UChar", 0x73, "UChar", 0x00, "UChar", 0x00, "UChar", 0xF8, "UChar", 0x1E, "UChar", 0xF3, "UChar", 0x2E, clsidBuf, 8)
    }
    status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", gpBitmap, "WStr", file, "Ptr", clsidBuf, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpBitmap)
    return status = 0
}


; 亮度（尽力而为，失败则提示）
BrightnessUp(*) {
    try {
        DllCall("dxva2\GetMonitorBrightness", "Ptr", DllCall("MonitorFromPoint", "Int64", 0, "UInt", 2, "Ptr"), "UInt*", &minB, "UInt*", &curB, "UInt*", &maxB)
    }
    TrayTip("亮度", "请使用系统快捷键或显示器按钮调节亮度", "Iconi")
}

; ---------- Profile 托盘指示与手动切换 ----------
; 原地刷新 Profile 子菜单项与勾选，保持托盘菜单顺序不变。
; 勾选为互斥单选语义：始终只勾中当前项，不能“去掉勾选”（去掉即回到默认）。
RefreshProfileMenu() {
    global ProfileMenu, Profiles, CurrentProfile
    if !IsObject(ProfileMenu)
        return
    try ProfileMenu.Delete()

    ProfileMenu.Add("默认", (*) => SwitchProfileByName("默认"))
    for name, _ in Profiles {
        ProfileMenu.Add(name, SwitchProfileByName.Bind(name))
    }

    try ProfileMenu.Uncheck("默认")
    for name, _ in Profiles {
        try ProfileMenu.Uncheck(name)
    }
    if (CurrentProfile = "") {
        try ProfileMenu.Check("默认")
    } else {
        try ProfileMenu.Check(CurrentProfile)
    }

    if MapCount(Profiles) = 0 {
        ProfileMenu.Add()
        ProfileMenu.Add("（未配置 profiles，仅默认扇区）", (*) => 0)
        try ProfileMenu.Disable("（未配置 profiles，仅默认扇区）")
    }
}

BuildProfileMenu() {
    global ProfileMenu
    if !IsObject(ProfileMenu)
        ProfileMenu := Menu()
    RefreshProfileMenu()
    return ProfileMenu
}

; ============================================================
; 阻止熄屏核心函数
; enable = true     防止系统睡眠 + 防止显示器关闭
; enable = false    恢复 Windows 正常电源策略
SetPowerProtection(enable := true) {
    global PreventSleep
    global ES_CONTINUOUS
    global ES_SYSTEM_REQUIRED
    global ES_DISPLAY_REQUIRED

    try {
        if enable {
            ; 持续保持：
            ; 1. 系统处于工作状态
            ; 2. 显示器保持开启
            flags := ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
            result := DllCall("Kernel32\SetThreadExecutionState", "UInt", flags, "UInt")
            if !result {
                PreventSleep := false
                return false
            }
            PreventSleep := true
            return true
        }

        ; 取消阻止熄屏
        result := DllCall("Kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS, "UInt")
        if !result
            return false
        PreventSleep := false
        return true
    }
    catch {
        return false
    }
}

; 托盘菜单：切换阻止熄屏
TogglePreventSleep(*) {
    newState := !PreventSleep
    if !PowerManager.SetEnabled(newState) {
        MsgBox("设置阻止熄屏失败。", "TRunner", "Icon!")
        UpdateTrayStatus()
        return
    }
    UpdateTrayStatus()
    MsgBox(
        newState
            ? "阻止熄屏已启用。`n`n系统不会自动进入睡眠，显示器也不会因空闲而关闭。"
        : "阻止熄屏已关闭。`n`n已恢复 Windows 正常电源管理。",
        "TRunner",
        "Iconi"
    )
}

; ============================================================



; ============================================================
; V0.27 功能生命周期辅助
; ============================================================
ShutdownScreenshotFeature(*) {
    global CaptureRegionGui, CaptureDragging

    try Hotkey("$*LButton", "Off")
    try Hotkey("$*LButton Up", "Off")
    try Hotkey("$*Escape", "Off")

    CaptureDragging := false

    if IsObject(CaptureRegionGui)
        try CaptureRegionGui.Destroy()

    CaptureRegionGui := ""
    FeatureManager.SetState("Screenshot", "unloaded")
}

ShutdownWindowManagerFeature(*) {
    ; 普通窗口移动/置顶操作没有常驻 Timer 或后台线程。
    ; 隐藏窗口管理器属于独立 Feature，由其模块负责完整回收。
    FeatureManager.SetState("WindowManager", "unloaded")
}

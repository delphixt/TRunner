;  4.5  窗口置顶功能 (ToggleWindowAlwaysOnTop)
; ---------- 切换鼠标下窗口的置顶状态（带提示和置顶标记） ----------
ToggleWindowAlwaysOnTop(*) {
    global startMouseX, startMouseY, TopMostMarkGui, TopMostMarkTimer

    if (startMouseX = "" || startMouseY = "")
        return

    pt := Buffer(8, 0)
    NumPut("Int", startMouseX, pt, 0)
    NumPut("Int", startMouseY, pt, 4)
    ptVal := NumGet(pt, 0, "Int64")
    hwnd := DllCall("WindowFromPoint", "Int64", ptVal, "Ptr")
    hwnd := Integer(hwnd)

    if (!hwnd || hwnd = DllCall("GetDesktopWindow", "Ptr"))
        return

    hRoot := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!hRoot)
        hRoot := hwnd
    hRoot := Integer(hRoot)

    ; --- 使用 DllCall 获取类名（避免 WinGetClass 的 VarRef 问题） ---
    clsBuf := Buffer(256)
    ret := DllCall("GetClassName", "Ptr", hRoot, "Ptr", clsBuf, "Int", 256)
    if (ret = 0) {
        ToolTip("获取类名失败")
        SetTimer(() => ToolTip(), -1500)
        return
    }
    targetClass := StrGet(clsBuf)

    ; 排除系统窗口
    if (targetClass = "Progman" || targetClass = "WorkerW"
        || targetClass = "Shell_TrayWnd" || targetClass = "Button"
        || targetClass = "DV2ControlHost" || targetClass = "Shell_SecondaryTrayWnd") {
        ToolTip("无法对桌面/任务栏执行置顶操作")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    winId := "ahk_id " hRoot
    exStyle := WinGetExStyle(winId)
    isTopmost := (exStyle & 0x8) != 0

    newState := !isTopmost
    WinSetAlwaysOnTop(newState, winId)

    if (newState)
        ToolTip("^ 窗口已置顶")
    else
        ToolTip("_ 窗口已取消置顶")
    SetTimer(() => ToolTip(), -2000)

    if (newState) {
        if (IsObject(TopMostMarkGui)) {
            TopMostMarkGui.Destroy()
            TopMostMarkGui := ""
        }
        if (TopMostMarkTimer) {
            SetTimer(TopMostMarkTimer, 0)
            TopMostMarkTimer := ""
        }
        CreateTopMostMark(hRoot)   ; 注意这里直接传整数句柄，函数内部会处理
    } else {
        if (IsObject(TopMostMarkGui)) {
            TopMostMarkGui.Destroy()
            TopMostMarkGui := ""
        }
        if (TopMostMarkTimer) {
            SetTimer(TopMostMarkTimer, 0)
            TopMostMarkTimer := ""
        }
    }
}

; ---------- 创建置顶标记 GUI ----------
CreateTopMostMark(hwnd) {
    global TopMostMarkGui, TopMostMarkTimer
    hwnd := Integer(hwnd)   ; 确保整数

    TopMostMarkGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Disabled")
    TopMostMarkGui.BackColor := "FFFF00"
    TopMostMarkGui.SetFont("s8 bold", "微软雅黑")
    TopMostMarkGui.Add("Text", "x0 y0 w30 h16 Center", "置顶")

    TopMostMarkGui.Show("NoActivate")

    DllCall("SetWindowPos", "Ptr", TopMostMarkGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0002 | 0x0001)

    TopMostMarkTimer := () => UpdateTopMostMarkPos(hwnd)
    SetTimer(TopMostMarkTimer, 200)
    UpdateTopMostMarkPos(hwnd)
}

; ---------- 更新置顶标记位置 ----------
UpdateTopMostMarkPos(hwnd) {
    global TopMostMarkGui, TopMostMarkTimer
    hwnd := Integer(hwnd)   ; 确保整数

    if (!IsObject(TopMostMarkGui))
        return

    winId := "ahk_id " hwnd
    ; 检查目标窗口是否存在
    if !WinExist(winId) {
        ; 窗口已关闭，销毁标记
        TopMostMarkGui.Destroy()
        TopMostMarkGui := ""
        if (TopMostMarkTimer) {
            SetTimer(TopMostMarkTimer, 0)
            TopMostMarkTimer := ""
        }
        return
    }

    ; 获取目标窗口位置和大小
    WinGetPos(&x, &y, &w, &h, winId)

    ; 获取标记 GUI 的尺寸
    markW := 30
    markH := 16

    ; 标记放在标题栏中央（避免遮挡右上角关闭按钮）
    markX := x + (w - markW) // 2
    markY := y + 3   ; 标题栏上部略微偏移

    ; 移动标记 GUI
    TopMostMarkGui.Show("x" markX " y" markY " NoActivate")

    ; 强制置顶，防止被目标窗口覆盖
    DllCall("SetWindowPos", "Ptr", TopMostMarkGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0002 | 0x0001)
}

; ---------- 显示托盘菜单 ----------
ShowTrayMenu(*) {
    global popupMenuOpen
    MouseGetPos(&mx, &my)
    popupMenuOpen := true
    try A_TrayMenu.Show(mx, my)
    finally popupMenuOpen := false
}

; ---------- 关闭右键按下时坐标处的窗口 ----------
CloseWindowUnderMouse(*) {
    global startMouseX, startMouseY

    if (startMouseX = "" || startMouseY = "")
        return

    pt := Buffer(8, 0)
    NumPut("Int", startMouseX, pt, 0)
    NumPut("Int", startMouseY, pt, 4)
    ptVal := NumGet(pt, 0, "Int64")
    hwnd := DllCall("WindowFromPoint", "Int64", ptVal, "Ptr")
    hwnd := Integer(hwnd)

    if (!hwnd || hwnd = DllCall("GetDesktopWindow", "Ptr"))
        return

    hRoot := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!hRoot)
        hRoot := hwnd
    hRoot := Integer(hRoot)

    WinClose("ahk_id " hRoot)
}

; ---------- 复制选中内容 ----------
CopySelectedText(*) {
    Send("^c")
}

; ---------- 剪切选中内容 ----------
CutSelectedText(*) {
    Send("^x")
}

; ---------- 粘贴 ----------
PasteText(*) {
    Send("^v")
}

; ---------- 截取全屏并保存到 Screenshots 文件夹 ----------
CaptureScreen(*) {
    ; 确保目录存在
    screenshotDir := A_ScriptDir "\Screenshots"
    if !DirExist(screenshotDir)
        DirCreate(screenshotDir)

    ; 生成带时间戳的文件名
    fileName := FormatTime(, "yyyy-MM-dd_HH-mm-ss") . ".png"
    filePath := screenshotDir "\" . fileName

    ; 捕获屏幕并保存（使用 GDI+）
    if CaptureScreenToFile(filePath) {
        ; 打开截图文件夹
        Run("explorer.exe /select,`"" filePath "`"")
    } else {
        MsgBox("屏幕截图失败！", "错误", "IconX")
    }
}

; ---------- 打开截图文件夹 ----------
OpenScreenshotsFolder(*) {
    screenshotDir := A_ScriptDir "\Screenshots"
    if !DirExist(screenshotDir)
        DirCreate(screenshotDir)
    Run("explorer.exe " screenshotDir)
}

; ---------- 显示/隐藏桌面 ----------
ToggleDesktop(*) {
    Send("#d")
}

; ---------- 打开任务管理器 ----------
OpenTaskManager(*) {
    Run("taskmgr.exe")
}

; ---------- 清空回收站 ----------
EmptyRecycleBin(*) {
    DllCall("Shell32\SHEmptyRecycleBin", "Ptr", 0, "Ptr", 0, "UInt", 1)  ; 1 = 不显示确认对话框
}
; ============================================================

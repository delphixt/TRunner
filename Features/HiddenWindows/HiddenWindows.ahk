;  4.3 窗口隐藏管理
; ============================================================
; ========== 窗口隐藏管理：消息处理 ==========
OnMessage(0x0201, OnAnyLButtonDown)
OnMessage(0x0203, OnAnyDblClick)

OnAnyLButtonDown(wParam, lParam, msg, hwnd) {
    global HiddenMgrIconHwnd
    if (HiddenMgrIconHwnd != 0 && hwnd = HiddenMgrIconHwnd) {
        PostMessage(0xA1, 2, 0, , "ahk_id " hwnd)  ; 模拟拖动
        return 0
    }
}

OnAnyDblClick(wParam, lParam, msg, hwnd) {
    global HiddenMgrIconHwnd
    if (HiddenMgrIconHwnd != 0 && hwnd = HiddenMgrIconHwnd) {
        ToggleHiddenMgrExpand()
        return 0
    }
}

; ========== 窗口隐藏管理：核心函数 ==========

; 隐藏鼠标下窗口（供扇形菜单调用）


; ======== Features/HiddenWindows.ahk ========
; Features — Hidden/Top/Tools
HideWindowUnderMouse(*) {
    global startMouseX, startMouseY, MW_Windows, MW_MaxWindows, HiddenMgrGui, HiddenMgrIconHwnd
    if (startMouseX = "" || startMouseY = "") {
        ToolTip("坐标为空")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 1. 获取鼠标下的窗口句柄
    pt := Buffer(8, 0)
    NumPut("Int", startMouseX, pt, 0)
    NumPut("Int", startMouseY, pt, 4)
    ptVal := NumGet(pt, 0, "Int64")
    hwnd := DllCall("WindowFromPoint", "Int64", ptVal, "Ptr")
    hwnd := Integer(hwnd)
    if (!hwnd || hwnd = DllCall("GetDesktopWindow", "Ptr")) {
        ToolTip("无效句柄或桌面窗口")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 2. 获取顶层根窗口
    hRoot := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!hRoot)
        hRoot := hwnd
    hRoot := Integer(hRoot)

    ; ===== 禁止隐藏管理窗口自身 =====
    if (IsObject(HiddenMgrGui) && hRoot = HiddenMgrGui.Hwnd) {
        ToolTip("不能隐藏管理窗口自身")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    if (HiddenMgrIconHwnd && hRoot = HiddenMgrIconHwnd) {
        ToolTip("不能隐藏管理窗口图标")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 构建字符串形式的窗口标识
    winId := "ahk_id " hRoot

    ; 3. 使用 DllCall 获取类名（避免 WinGetClass 类型问题）
    clsBuf := Buffer(256)
    ret := DllCall("GetClassName", "Ptr", hRoot, "Ptr", clsBuf, "Int", 256)
    if (ret = 0) {
        ToolTip("获取类名失败")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    targetClass := StrGet(clsBuf)

    ; 4. 排除系统窗口
    if (targetClass = "Progman" || targetClass = "WorkerW"
        || targetClass = "Shell_TrayWnd" || targetClass = "Shell_SecondaryTrayWnd") {
        ToolTip("无法隐藏桌面或任务栏")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 5. 检查隐藏数量上限
    if MW_Windows.Count >= MW_MaxWindows {
        ToolTip("最多只能同时隐藏 " MW_MaxWindows " 个窗口")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 6. 获取窗口标题（使用字符串标识）
    title := WinGetTitle(winId)
    if (title = "")
        title := "窗口 " . hRoot

    ; 7. 隐藏窗口
    try {
        WinHide(winId)
    } catch {
        ToolTip("隐藏窗口时出错")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 8. 验证是否隐藏成功
    if WinExist(winId) {
        ToolTip("窗口可能无法隐藏")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; 9. 记录到管理列表
    MW_Windows[title] := hRoot

    ; 10. 更新管理窗口
    if IsObject(HiddenMgrGui)
        RefreshHiddenManagerList()
    else
        ShowHiddenWindowManager()

    ToolTip("已隐藏: " title)
    SetTimer(() => ToolTip(), -3000)
}

; 显示管理窗口（或切换折叠/展开）
ShowHiddenWindowManager(*) {
    global MW_Windows, HiddenMgrGui, HiddenMgrLV, HiddenMgrIconHwnd, HiddenMgrCollapsed

    if (MW_Windows.Count = 0) {
        SetTimer(() => ToolTip(), -1500)
        ; 不返回，仍显示管理窗口
    }

    if HiddenMgrCollapsed {
        ; 图标模式
        if (HiddenMgrIconHwnd = 0)
            CreateHiddenMgrIconGui()
        WinShow("ahk_id " HiddenMgrIconHwnd)   ; 显示图标窗口
        if IsObject(HiddenMgrGui)
            HiddenMgrGui.Hide()
    } else {
        ; 完整模式
        if !IsObject(HiddenMgrGui)
            CreateHiddenMgrGui()
        RefreshHiddenManagerList()
        HiddenMgrGui.Show("AutoSize NoActivate")
        WinHide("ahk_id " HiddenMgrIconHwnd)   ; 隐藏图标窗口
    }
}

; 恢复最后隐藏的窗口
RestoreLastHiddenWindow(*) {
    global MW_Windows, HiddenMgrGui
    if MW_Windows.Count = 0 {
        SetTimer(() => ToolTip(), -1500)
        return
    }

    lastKey := ""
    for key in MW_Windows
        lastKey := key

    if (lastKey != "") {
        id := MW_Windows[lastKey]
        try {
            WinShow("ahk_id " id)
            WinActivate("ahk_id " id)
        } catch {
        }
        MW_Windows.Delete(lastKey)
        if IsObject(HiddenMgrGui)
            RefreshHiddenManagerList()
    }
}

; 恢复所有隐藏的窗口
RestoreAllHiddenWindows(*) {
    global MW_Windows, HiddenMgrGui
    for menuName, id in MW_Windows {
        try {
            WinShow("ahk_id " id)
            WinActivate("ahk_id " id)
        } catch {
        }
    }
    MW_Windows.Clear()
    if IsObject(HiddenMgrGui)
        RefreshHiddenManagerList()
}

; 恢复 GUI 中选中的窗口
RestoreSelectedHiddenWindow() {
    global MW_Windows, HiddenMgrLV, MW_HiddenOrder
    if MW_Windows.Count = 0
        return
    row := HiddenMgrLV.GetNext()
    if row = 0
        return
    if row > MW_HiddenOrder.Length
        return
    menuName := MW_HiddenOrder[row]
    if MW_Windows.Has(menuName) {
        id := MW_Windows[menuName]
        try {
            WinShow("ahk_id " id)
            WinActivate("ahk_id " id)
        } catch {
        }
        MW_Windows.Delete(menuName)
        RefreshHiddenManagerList()
    }
}

; 刷新管理窗口列表
RefreshHiddenManagerList() {
    global MW_Windows, HiddenMgrLV, MW_HiddenOrder, HiddenMgrTitlesHidden
    if !IsObject(HiddenMgrLV)
        return
    MW_HiddenOrder := []
    for menuName in MW_Windows
        MW_HiddenOrder.Push(menuName)
    HiddenMgrLV.Delete()
    idx := 1
    for menuName in MW_HiddenOrder {
        displayText := HiddenMgrTitlesHidden ? "******" : menuName
        HiddenMgrLV.Add(, idx, displayText)
        idx++
    }
    ; 序号列固定宽度 30，标题列自动调整
    HiddenMgrLV.ModifyCol(1, 40)
    HiddenMgrLV.ModifyCol(2, "AutoHdr")
}

; 创建完整模式 GUI
CreateHiddenMgrGui() {
    global HiddenMgrGui, HiddenMgrLV, HiddenMgrTitlesHidden

    HiddenMgrGui := Gui("+AlwaysOnTop +ToolWindow")
    HiddenMgrGui.Title := "窗口管理"
    HiddenMgrGui.SetFont("s10", "微软雅黑")
    HiddenMgrGui.MarginX := 10, HiddenMgrGui.MarginY := 10
    HiddenMgrLV := HiddenMgrGui.Add("ListView", "w460 h200 -Multi", ["序号", "窗口列表"])
    HiddenMgrLV.OnEvent("DoubleClick", (*) => RestoreSelectedHiddenWindow())
    chkHideTitles := HiddenMgrGui.Add("Checkbox", "w90", "隐藏标题")
    chkHideTitles.Value := HiddenMgrTitlesHidden
    chkHideTitles.OnEvent("Click", ToggleHiddenTitlesFromCheckbox)
    btnRestore := HiddenMgrGui.Add("Button", "x+10 w80", "恢复选中")
    btnRestore.OnEvent("Click", (*) => RestoreSelectedHiddenWindow())
    btnAll := HiddenMgrGui.Add("Button", "x+10 w80", "全部恢复")
    btnAll.OnEvent("Click", (*) => RestoreAllHiddenWindows())
    btnHide := HiddenMgrGui.Add("Button", "x+10 w80", "隐藏本窗口")
    btnHide.OnEvent("Click", (*) => CollapseHiddenMgr())

    ; -------- 退出管理按钮 --------
    btnExit := HiddenMgrGui.Add("Button", "x+10 w80", "退出管理")
    btnExit.OnEvent("Click", (*) => ExitHiddenManager())
    HiddenMgrGui.OnEvent("Close", (*) => CollapseHiddenMgr())
    HiddenMgrGui.OnEvent("Escape", (*) => CollapseHiddenMgr())
}

; ---------- 创建图标模式 GUI（改用 OnMessage 处理右键） ----------
CreateHiddenMgrIconGui() {
    global HiddenMgrIconHwnd
    hGui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border")
    hGui.MarginX := 0, hGui.MarginY := 0
    hGui.BackColor := "0xEEEEEE"
    hGui.Add("Text", "w30 h30 Center", "▣").SetFont("s14 bold", "Segoe UI Symbol")
    hGui.Show("w30 h30 NoActivate")
    HiddenMgrIconHwnd := hGui.Hwnd
}

; ---------- 退出隐藏窗口管理功能（恢复所有窗口、释放 GUI） ----------
ExitHiddenManager() {
    global MW_Windows, HiddenMgrGui, HiddenMgrIconHwnd, HiddenMgrCollapsed

    ; 1. 恢复所有隐藏窗口并清空列表
    RestoreAllHiddenWindows()

    ; 2. 销毁图标窗口（仅当窗口仍存在时）
    if (HiddenMgrIconHwnd) {
        if WinExist("ahk_id " HiddenMgrIconHwnd) {
            try WinClose("ahk_id " HiddenMgrIconHwnd)
        }
        HiddenMgrIconHwnd := 0   ; 无论如何清空句柄
    }

    ; 3. 销毁完整管理窗口（若存在）
    if IsObject(HiddenMgrGui) {
        try HiddenMgrGui.Destroy()
        HiddenMgrGui := ""
    }

    ; 4. 重置折叠状态为图标模式（以便下次重新创建）
    HiddenMgrCollapsed := true
}

; 折叠为图标模式
CollapseHiddenMgr() {
    global HiddenMgrCollapsed
    HiddenMgrCollapsed := true
    ShowHiddenWindowManager()
}

; 展开为完整模式
ToggleHiddenMgrExpand() {
    global HiddenMgrCollapsed
    HiddenMgrCollapsed := false
    ShowHiddenWindowManager()
}

; 复选框切换标题隐藏
ToggleHiddenTitlesFromCheckbox(ctrl, *) {
    global HiddenMgrTitlesHidden
    HiddenMgrTitlesHidden := ctrl.Value
    RefreshHiddenManagerList()
}

; 退出时恢复所有隐藏窗口
OnExit(RestoreAllHiddenWindowsOnExit)
RestoreAllHiddenWindowsOnExit(*) {
    global MW_Windows
    for menuName, id in MW_Windows {
        try WinShow("ahk_id " id)
    }
    MW_Windows.Clear()
}

; 4.4  截图功能 (CaptureScreen / CaptureScreenToFile)
; ============================================================
;  内部辅助函数：屏幕截图保存为 PNG
; ============================================================
CaptureScreenToFile(filePath) {
    ; 获取屏幕尺寸
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight

    ; 与主程序共用同一 GDI+ 生命周期。
    if !InitGDIPlus()
        return false

    ; 创建位图
    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", screenWidth, "Int", screenHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)

    ; 获取位图 Graphics
    pGraphics := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)

    ; 获取屏幕 DC
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", screenWidth, "Int", screenHeight, "Ptr")
    hOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap)

    ; 复制屏幕到位图
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", screenWidth, "Int", screenHeight, "Ptr", hdcScreen, "Int", 0, "Int", 0, "UInt", 0x00CC0020) ; SRCCOPY

    ; 将 HBITMAP 转换为 GDI+ 位图
    pScreenBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pScreenBitmap)

    ; 绘制到目标位图
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pGraphics, "Ptr", pScreenBitmap, "Int", 0, "Int", 0, "Int", screenWidth, "Int", screenHeight)

    ; 获取 PNG 编码器 CLSID
    pngClsid := GetPngEncoderClsid()

    ; 保存为 PNG
    saveResult := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filePath, "Ptr", pngClsid, "Ptr", 0)

    ; 清理
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pScreenBitmap)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOld)
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)

    return (saveResult = 0)
}

; ---------- 获取 PNG 编码器 CLSID ----------
GetPngEncoderClsid() {
    static pngClsid := 0
    if (pngClsid)
        return pngClsid

    ; 获取编码器数量
    numEncoders := 0
    size := 0
    DllCall("gdiplus\GdipGetImageEncodersSize", "UInt*", &numEncoders, "UInt*", &size)
    if (numEncoders = 0)
        return 0

    ; 分配内存
    encoderBuffer := Buffer(size, 0)

    ; 获取编码器信息
    DllCall("gdiplus\GdipGetImageEncoders", "UInt", numEncoders, "UInt", size, "Ptr", encoderBuffer)

    ; 遍历查找 PNG
    Loop numEncoders {
        ; ImageCodecInfo 结构体偏移：
        ; 0  : CLSID (16 bytes)
        ; 16 : FormatID (16 bytes)
        ; 32 : CodecName (WCHAR*)
        ; 40 : DllName (WCHAR*)
        ; 48 : FormatDescription (WCHAR*)
        ; 56 : FilenameExtension (WCHAR*)
        ; 64 : MimeType (WCHAR*)
        ; 72 : Flags (UInt)
        ; 76 : Version (UInt)
        ; 80 : SigCount (UInt)
        ; 84 : SigPatternCount (UInt)
        ; 88 : SigPattern (Ptr)
        ; 96 : SigMask (Ptr)

        offset := (A_Index - 1) * 104  ; 每个结构体大小（实际是 104 字节，但可能因对齐不同）
        mimeTypePtr := NumGet(encoderBuffer, offset + 64, "Ptr")
        mimeType := StrGet(mimeTypePtr, "UTF-16")
        if (mimeType = "image/png") {
            pngClsid := Buffer(16)
            DllCall("RtlMoveMemory", "Ptr", pngClsid, "Ptr", encoderBuffer.Ptr + offset, "UInt", 16)
            return pngClsid
        }
    }
    return 0
}

;  4.5  窗口置顶功能 (ToggleWindowAlwaysOnTop)


; ============================================================
; V0.27 功能生命周期
; ============================================================
ShutdownHiddenWindowManagerFeature(*) {
    global HiddenMgrGui, HiddenMgrLV, HiddenMgrIconHwnd

    if IsObject(HiddenMgrGui)
        try HiddenMgrGui.Destroy()

    if HiddenMgrIconHwnd
        try WinHide("ahk_id " HiddenMgrIconHwnd)

    HiddenMgrGui := ""
    HiddenMgrLV := ""
    HiddenMgrIconHwnd := 0

    FeatureManager.SetState(
        "HiddenWindowManager",
        "unloaded"
    )
}

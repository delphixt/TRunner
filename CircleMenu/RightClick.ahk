; ======== Core/RightClick.ahk ========
; Core — Right-click state machine

; ---- 右键成对转发（带重入保护，避免 SendInput 再次触发 $RButton） ----
isForwardingRightButton := false

ForwardRightButtonClick() {
    global isForwardingRightButton
    if isForwardingRightButton
        return
    isForwardingRightButton := true
    try {
        SendInput("{RButton down}")
        SendInput("{RButton up}")
    }
    finally
        isForwardingRightButton := false
}

ForwardRightButtonDown() {
    global rightButtonForwarded, isForwardingRightButton
    if rightButtonForwarded || isForwardingRightButton
        return
    rightButtonForwarded := true
    isForwardingRightButton := true
    try SendInput("{RButton down}")
    catch
        rightButtonForwarded := false
    finally
        isForwardingRightButton := false
}

ForwardRightButtonUp() {
    global rightButtonForwarded, isForwardingRightButton
    if !rightButtonForwarded || isForwardingRightButton
        return
    rightButtonForwarded := false
    isForwardingRightButton := true
    try SendInput("{RButton up}")
    finally
        isForwardingRightButton := false
}

ReleaseCapturedRightButton() {
    global rbuttonDown, rightButtonForwarded
    ; 只有确实向 Windows 转发过 Down，才补 Up。
    ; rbuttonDown=true 且未转发时：物理 Down 已被热键吞掉，系统从未收到 Down，
    ; 再发 Up 会变成“无主 Up”，导致系统右键/菜单状态紊乱。
    if rightButtonForwarded
        ForwardRightButtonUp()
    rightButtonForwarded := false
    rbuttonDown := false
}

HideAllLayeredMenus() {
    global MyGui, ContentGui, GuideGui, HighlightGui
    global hBmpHighlight, HighlightedSector
    if IsObject(MyGui)
        try MyGui.Hide()
    if IsObject(ContentGui)
        try ContentGui.Hide()
    if IsObject(GuideGui)
        try GuideGui.Hide()
    if IsObject(HighlightGui)
        try HighlightGui.Hide()
    if (hBmpHighlight) {
        try DllCall("DeleteObject", "Ptr", hBmpHighlight)
        hBmpHighlight := 0
    }
    HighlightedSector := ""
    try HideGuideLine()
}

ResetMouseInteractionState(hideMenu := true) {
    global isMenuVisible
    global hasDragged
    global timerActive
    global menuWasOpen
    global rbuttonDown
    global isInteracting
    global RuntimeBusy
    global MyGui, ContentGui, GuideGui, HighlightGui
    global HighlightedSector
    global hBmpHighlight
    global circleMenuOpen
    global ourRButtonDown
    global ateRightButtonDown

    try ReleaseCapturedRightButton()
    ; 注意：不要在这里清 ourRButtonDown / ateRightButtonDown。
    ; 它们表示“本次物理 Down 是否被我们吞掉”，必须保留到 Up 成对处理完。

    ; 先停止右键拖动 Timer
    try SetTimer(CheckMouseMove, 0)
    timerActive := false
    rbuttonDown := false
    hasDragged := false
    menuWasOpen := false
    isInteracting := false
    circleMenuOpen := false

    ; 清除高亮
    ResetHighlightState()

    ; 隐藏圆形菜单
    if hideMenu {
        if IsObject(MyGui)
            try MyGui.Hide()
        if IsObject(ContentGui)
            try ContentGui.Hide()
        if IsObject(GuideGui)
            try GuideGui.Hide()
        if IsObject(HighlightGui)
            try HighlightGui.Hide()
        try HideGuideLine()
        isMenuVisible := false
    } else {
        isMenuVisible := false
    }
    ; 防止 RuntimeMonitor 因残留状态被锁死
    RuntimeBusy := false
}

; 停止所有运行时 Timer + 完整复位鼠标状态
StopRuntimeTimers() {
    global MouseMonitorPaused

    ; 停止所有 Timer
    try SetTimer(CheckMouseMove, 0)
    try SetTimer(RuntimeMonitor, 0)
    try SetTimer(CheckProfileSwitch, 0)
    try SetTimer(CheckConfigChange, 0)

    ; ResetMouseInteractionState 会再次关闭 CheckMouseMove，
    ; 这样可以保证所有退出路径都使用同一套状态清理逻辑。
    ResetMouseInteractionState(true)

    ; 保持原来的“停止运行时 Timer 时同时关闭鼠标监控状态”
    MouseMonitorPaused := false

    ; 再保险一次
    try HideGuideLine()
}

CleanupMainResources(*) {
    global CleanupRunning, IsReloading

    if CleanupRunning
        return

    CleanupRunning := true

    ; 退出/重载统一遵循：释放右键输入 → 停止 Timer → 清理交互状态 → 清理视觉层。
    ; 重载前显式销毁旧的 AlwaysOnTop 分层窗口，避免旧实例窗口残留与新实例竞争。
    try ReleaseCapturedRightButton()
    try TimerManager.StopAll()
    try ResetMouseInteractionState(true)
    try FeatureManager.ShutdownAll()
    try PowerManager.Cleanup()

    if IsReloading {
        try ReleaseMainVisualResources()
        return
    }

    try HideMainVisualsForExit()
    try ClearIconCache()
    try GpClearTextResourceCache()
}

HideMainVisualsForExit() {
    global MyGui, ContentGui, GuideGui, HighlightGui
    if IsObject(GuideGui)
        try GuideGui.Hide()
    if IsObject(HighlightGui)
        try HighlightGui.Hide()
    if IsObject(ContentGui)
        try ContentGui.Hide()
    if IsObject(MyGui)
        try MyGui.Hide()
}

; ============================================================
; V0.27 强制刷新视觉层
; Win+Alt+F5 / 托盘“刷新”使用。
; 不重新启动 AHK 进程，只销毁并重建 TRunner 视觉窗口。
; ============================================================
ForceRefreshTRunner(*) {
    global IsReloading, RuntimeBusy, StartupComplete

    if IsReloading
        return

    IsReloading := true

    try {
        try ReleaseCapturedRightButton()
        try TimerManager.StopAll()
        try ResetMouseInteractionState(true)
        RuntimeBusy := false

        ; Feature GUI/Timer 不属于圆形菜单视觉层，刷新主视觉层时不销毁。
        ; 只重建四层菜单窗口。
        try ReleaseMainVisualResources()
        try GpClearTextResourceCache()
        try ClearIconCache()

        if !LoadConfig(true)
            return

        try GetCurrentProfileSectors()

        if !BuildMenuGUI(true, true) {
            TrayTip(AppName, "视觉层重建失败，请检查 GDI+/配置后重试。", "Icon!")
            return
        }

        try ResetMouseInteractionState(true)

        TrayTip(
            AppName,
            "视觉层已刷新，鼠标点击状态已重新初始化。",
            "Iconi"
        )
    }
    catch as e {
        TrayTip(
            AppName,
            "刷新失败：`n" e.Message,
            "Icon!"
        )
    }
    finally {
        RuntimeBusy := false
        try TimerManager.Register("Runtime", RuntimeMonitor, 1000)
        IsReloading := false
    }
}

ReloadScript(*) {
    global IsReloading

    if IsReloading
        return

    IsReloading := true

    ; 重载前先释放已被脚本截获的右键，避免新实例只收到 Up。
    try ReleaseCapturedRightButton()
    try TimerManager.StopAll()
    try ResetMouseInteractionState(true)
    try FeatureManager.ShutdownAll()
    try PowerManager.Cleanup()

    ; 销毁旧的四层视觉窗口，避免重载期间出现旧/新实例重叠。
    try ReleaseMainVisualResources()

    Reload()
}

ApplyConfigChangesInPlace(showError := true) {
    global jsonFile, LastConfigModTime

    try {
        ResetMouseInteractionState(true)
        LoadConfig(true)
        GetCurrentProfileSectors()
        RefreshMenuVisuals(true, true)
        LastConfigModTime := FileGetTime(jsonFile, "M")
        UpdateTrayStatus()
        return true
    } catch as e {
        if showError
            MsgBox("配置已经保存，但主程序刷新失败：`n`n" e.Message, AppName " " AppVersion, "Icon!")
        return false
    }
}

; 计算几何布局。只有总扇区数量/窗口尺寸/半径变化时才需要重算。
RecalculateMenuLayout() {
    global W, H, CX, CY, R, R3
    global TotalSectors, RingCount, SectorsPerRing, RingRadiusArray, SectorOffset
    global App_WindowSize, App_OuterRadius

    W := App_WindowSize
    H := App_WindowSize
    CX := W // 2
    CY := H // 2
    R := App_OuterRadius
    R3 := R // 8

    if (TotalSectors <= 0)
        return false

    RingCount := 1
    if (TotalSectors > 8)
        RingCount := 2
    if (TotalSectors > 16)
        RingCount := 3

    SectorsPerRing := []

    if (RingCount = 1) {
        ; 单环
        SectorsPerRing.Push(TotalSectors)
    }
    else if (RingCount = 2) {
        ; 先内圈，再外圈
        outerCount := Ceil(TotalSectors / 2)
        innerCount := TotalSectors - outerCount
        SectorsPerRing.Push(innerCount)
        SectorsPerRing.Push(outerCount)
    }
    else {
        ; 3 圈：内圈 → 中圈 → 外圈 ; 外圈最多 8 个
        outerCount := 8
        midCount := Ceil((TotalSectors - outerCount) / 2)
        innerCount := TotalSectors - outerCount - midCount
        SectorsPerRing.Push(innerCount)
        SectorsPerRing.Push(midCount)
        SectorsPerRing.Push(outerCount)
    }
    RingRadiusArray := []
    if (RingCount = 1) {
        ; 单环
        RingRadiusArray.Push({ inner: R3, outer: R })
    }
    else if (RingCount = 2) {
        ; 内圈 → 外圈
        R2 := R * 0.60
        RingRadiusArray.Push({ inner: R3, outer: R2 })
        RingRadiusArray.Push({ inner: R2, outer: R })
    }
    else {
        ; 内圈 → 中圈 → 外圈
        R_mid_inner := R * 0.45
        R_outer_inner := R * 0.75
        RingRadiusArray.Push({ inner: R3, outer: R_mid_inner })
        RingRadiusArray.Push({ inner: R_mid_inner, outer: R_outer_inner })

        RingRadiusArray.Push({ inner: R_outer_inner, outer: R })
    }
    SectorOffset := []
    offset := 1
    for _, count in SectorsPerRing {
        SectorOffset.Push(offset)
        offset += count
    }
    return true
}

GetLayoutSignature() {
    global App_WindowSize, App_OuterRadius, TotalSectors
    return App_WindowSize "|" App_OuterRadius "|" TotalSectors
}

GetStaticVisualSignature() {
    global App_WindowSize, App_OuterRadius
    global App_PenColor, App_PenWidth, App_BgColor
    global App_EscapeRadius, App_Background, App_BackgroundAlpha

    return App_WindowSize . "|"
        . App_OuterRadius . "|"
        . App_PenColor . "|"
        . App_PenWidth . "|"
        . App_BgColor . "|"
        . App_EscapeRadius . "|"
        . App_Background . "|"
        . App_BackgroundAlpha
}

GetContentVisualSignature() {
    global ActionConfig, ShowSectorIcon
    global App_TextColor, App_FontSize, App_FontWeight

    sig := App_TextColor . "|" . App_FontSize . "|" . App_FontWeight . "|" . ShowSectorIcon . "|"

    keys := []
    for key in ActionConfig
        keys.Push(key)

    ; 数量通常很少，插入排序足够；保证同一内容得到稳定签名。
    loop keys.Length - 1 {
        i := A_Index + 1
        j := i - 1
        cur := keys[i]
        while (j >= 1 && Integer(keys[j]) > Integer(cur)) {
            keys[j + 1] := keys[j]
            j--
        }
        keys[j + 1] := cur
    }

    for _, key in keys {
        cfg := ActionConfig[key]
        name := cfg.Has("Name") ? cfg["Name"] : ""
        icon := cfg.Has("Icon") ? cfg["Icon"] : ""
        sig .= key . "=" . name . "|" . icon . ";"
    }
    return sig
}

; 创建静态位图。 只有外观或几何布局改变时才调用。
RebuildStaticBitmap() {
    global hBmpBase, W, H, CX, CY, R
    global App_Background, App_BackgroundAlpha, App_BgColor
    global App_PenColor

    if (hBmpBase) {
        DllCall("DeleteObject", "Ptr", hBmpBase)
        hBmpBase := 0
    }
    info := CreateGpBitmapAndGraphics(W, H)
    gpBitmap := info[1]
    gpGraphics := info[2]
    bgAlpha := (App_Background = "comfortable") ? App_BackgroundAlpha : (App_Background = "transparent") ? 1 : 255
    GpFillCircle(gpGraphics, RGBToARGB(App_BgColor, bgAlpha), CX, CY, R)
    DrawStaticGraphics(gpGraphics, RGBToARGB(App_PenColor, 255))
    hBmpBase := GpBitmapToHBITMAP(gpBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gpGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpBitmap)
    return (hBmpBase != 0)
}

; 创建动态内容位图。
; Profile 切换只更新这一层。
RebuildContentBitmap() {
    global hBmpContent, hBmpMain
    global W, H, App_TextColor
    if (hBmpContent) {
        DllCall("DeleteObject", "Ptr", hBmpContent)
        hBmpContent := 0
    }
    info := CreateGpBitmapAndGraphics(W, H)
    gpBitmap := info[1]
    gpGraphics := info[2]
    ; 新 Bitmap 默认透明。
    DrawContentGraphics(gpGraphics, RGBToARGB(App_TextColor, 255))
    hBmpContent := GpBitmapToHBITMAP(gpBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gpGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpBitmap)
    ; 兼容外部仍可能引用 hBmpMain 的旧逻辑。
    hBmpMain := hBmpContent
    return (hBmpContent != 0)
}

; 把三个分层窗口放到同一位置并更新位图。
ApplyMenuBitmaps() {
    global MyGui, ContentGui, HighlightGui, hBmpBase, hBmpContent, hBmpHighlight, W, H

    if !IsObject(MyGui)
        return false
    if (hBmpBase)
        UpdateLayeredWindowEx(MyGui.Hwnd, hBmpBase, W, H, 255, true)
    if IsObject(ContentGui) {
        if (hBmpContent)
            UpdateLayeredWindowEx(ContentGui.Hwnd, hBmpContent, W, H, 255, true)
    }
    if IsObject(HighlightGui) {
        if (hBmpHighlight)
            UpdateLayeredWindowEx(HighlightGui.Hwnd, hBmpHighlight, W, H, 255, true)
    }
    return true
}

; 重建高亮层位图 (V0.21)
; 根据 HighlightedSector 绘制高亮扇形
RebuildHighlightBitmap() {
    global hBmpHighlight, HighlightedSector, W, H, CX, CY
    global App_HighlightColor, App_HighlightAlpha
    global RingCount, SectorsPerRing, RingRadiusArray, SectorOffset

    if (hBmpHighlight) {
        DllCall("DeleteObject", "Ptr", hBmpHighlight)
        hBmpHighlight := 0
    }
    if (HighlightedSector = "" || HighlightedSector = "0")
        return false

    sectorNum := Integer(HighlightedSector)
    ; 查找该扇区所在的环
    targetRingIdx := -1
    targetSectorIdx := -1
    for ringIdx, ringRadius in RingRadiusArray {
        offset := SectorOffset[ringIdx]
        count := SectorsPerRing[ringIdx]
        if (sectorNum >= offset && sectorNum < offset + count) {
            targetRingIdx := ringIdx
            targetSectorIdx := sectorNum - offset
            break
        }
    }
    if (targetRingIdx < 0)
        return false

    ringRadius := RingRadiusArray[targetRingIdx]
    rInner := ringRadius.inner
    rOuter := ringRadius.outer
    sectorCount := SectorsPerRing[targetRingIdx]
    angleStep := 6.283185307179586 / sectorCount
    startAngle := GetClockStartAngle(sectorCount) + targetSectorIdx * angleStep

    info := CreateGpBitmapAndGraphics(W, H)
    gpBitmap := info[1]
    gpGraphics := info[2]
    GpFillSector(gpGraphics, RGBToARGB(App_HighlightColor, App_HighlightAlpha), CX, CY, rInner, rOuter, startAngle,
        angleStep)
    hBmpHighlight := GpBitmapToHBITMAP(gpBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gpGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpBitmap)
    return (hBmpHighlight != 0)
}

; 更新高亮层 (V0.21)
; 在 CheckMouseMove 中调用，仅当高亮扇区变化时重建
UpdateHighlightLayer() {
    global HighlightGui, hBmpHighlight, HighlightedSector, W, H

    if !IsObject(HighlightGui)
        return
    if (HighlightedSector = "") {
        if (hBmpHighlight) {
            DllCall("DeleteObject", "Ptr", hBmpHighlight)
            hBmpHighlight := 0
        }
        try HighlightGui.Hide()
        return
    }
    if !RebuildHighlightBitmap()
        return
    UpdateLayeredWindowEx(HighlightGui.Hwnd, hBmpHighlight, W, H, 255, true)
    HighlightGui.Show("NA")
    ; 保持高亮层在内容层之上
    DllCall("SetWindowPos", "Ptr", HighlightGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
}

; 核心刷新机制。
; forceStatic=true  -> 重建静态层和动态层。
; forceContent=true -> 只重建动态层。
; 正常 Profile 切换只进 content 分支。
RefreshMenuVisuals(forceStatic := false, forceContent := false) {
    global MenuVisualReady
    global StaticVisualSignature
    global ContentVisualSignature
    global LayoutSignature
    global MyGui
    global ContentGui
    global GuideGui
    global HighlightGui
    global W
    global H

    if (!InitGDIPlus())
        return false

    layoutSig := GetLayoutSignature()
    staticSig := GetStaticVisualSignature()
    contentSig := GetContentVisualSignature()

    needLayout := (!MenuVisualReady || layoutSig != LayoutSignature)
    needStatic := forceStatic || needLayout || staticSig != StaticVisualSignature
    needContent := forceContent || !MenuVisualReady || needLayout || contentSig != ContentVisualSignature
    if (needLayout) {
        if !RecalculateMenuLayout()
            return false
        layoutSig := GetLayoutSignature()
        needStatic := true
        needContent := true
    }
    if (!IsObject(MyGui)) {
        MyGui := CreateLayeredGui(false)
        needStatic := true
    }
    if (!IsObject(ContentGui)) {
        ContentGui := CreateLayeredGui(true)
        needContent := true
    }
    ; GuideGui：鼠标辅助线层
    if (!IsObject(GuideGui)) {
        GuideGui := CreateLayeredGui(true)
    }
    ; HighlightGui：扇区高亮层 (V0.21)
    if (!IsObject(HighlightGui)) {
        HighlightGui := CreateLayeredGui(true)
    }
    if (needStatic) {
        if !RebuildStaticBitmap()
            return false
    }
    if (needContent) {
        if !RebuildContentBitmap()
            return false
    }

    ; 四层窗口：仅在未显示时 Hide 调尺寸；若菜单正在显示，必须重新 Show，
    ; 否则会只剩辅助线/高亮（它们每帧会 Show，主圆环/内容层却一直隐藏）。
    global isMenuVisible
    if isMenuVisible {
        ApplyMenuBitmaps()
        ; 重新定位并显示主圆环与内容层
        try {
            MyGui.Show("w" W " h" H " NoActivate")
            ContentGui.Show("w" W " h" H " NoActivate")
        }
    } else {
        MyGui.Show("Hide w" W " h" H)
        ContentGui.Show("Hide w" W " h" H)
        GuideGui.Show("Hide w" W " h" H)
        HighlightGui.Show("Hide w" W " h" H)
        ApplyMenuBitmaps()
    }
    LayoutSignature := layoutSig
    StaticVisualSignature := staticSig
    ContentVisualSignature := contentSig
    MenuVisualReady := true
    return true
}

; 保留 BuildMenuGUI 名称，外部代码继续可以调用。 但它现在不再每次 Destroy GUI。
BuildMenuGUI(forceStatic := false, forceContent := false) {
    return RefreshMenuVisuals(forceStatic, forceContent)
}

; RuntimeMonitor：合并 Profile 和 Settings.json 检测。
; 每秒只做轻量检查；只有状态真的变化时才刷新视觉。
RuntimeMonitor() {
    global isMenuVisible, isInteracting, RuntimeBusy
    global LastProfileHWND, CurrentProfile, LastConfigModTime
    global jsonFile

    if (RuntimeBusy || isMenuVisible || isInteracting)
        return
    RuntimeBusy := true
    try {
        configChanged := false
        profileChanged := false
        ; Settings.json 修改检测
        try {
            modTime := FileGetTime(jsonFile, "M")
        } catch {
            modTime := LastConfigModTime
        }

        if (modTime != LastConfigModTime) {
            try {
                LoadConfig(true)
                GetCurrentProfileSectors()
                configChanged := true
                LastConfigModTime := modTime
            } catch {
                ; 配置错误时保持旧界面，不中断运行。
            }
        }

        ; Profile 检测
        try {
            hwnd := WinGetID("A")
        } catch {
            hwnd := 0
        }

        if (hwnd && hwnd != LastProfileHWND && !configChanged) {
            oldProfile := CurrentProfile
            GetCurrentProfileSectors()
            if (CurrentProfile != oldProfile)
                profileChanged := true
            LastProfileHWND := hwnd
        } else if (hwnd) {
            LastProfileHWND := hwnd
        }
        ; 只在真正发生变化时刷新
        if (configChanged) {
            ; Settings 可能同时改变布局、外观、文字、图标。
            RefreshMenuVisuals()
            return
        }

        if (profileChanged) {
            ; Profile 切换：尽量只刷新动态内容层，不重建 GUI / 静态层。
            RefreshMenuVisuals(false, true)
        }
    } finally {
        RuntimeBusy := false
    }
}
; 兼容旧函数名称。旧调用即使存在，也不再分别注册两个 Timer。
CheckConfigChange() {
    RuntimeMonitor()
}

CheckProfileSwitch() {
    RuntimeMonitor()
}

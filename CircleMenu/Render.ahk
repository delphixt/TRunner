; ============================================================
;  3.11 窗口绘制与视觉缓存 (GDI+ 分层窗口渲染 / 四层: 静态/内容/高亮/辅助线)
; ============================================================
; ========== 窗口绘制 / 视觉缓存 ==========
; ------------------------------------------------------------------
; 静态绘制：只负责外观和几何结构。 Profile 切换不会触碰这一层。


; ======== Core/Render.ahk ========
; Core — Render
DrawStaticGraphics(gpGraphics, penArgb) {
    global CX, CY, R, R3, RingCount, SectorsPerRing, RingRadiusArray
    global App_PenWidth, App_EscapeRadius

    ; 中心圆
    GpDrawEllipse(gpGraphics, penArgb, App_PenWidth,
        CX - R3, CY - R3, CX + R3, CY + R3)

    ; 圆环和分割线
    for ringIdx, ringRadius in RingRadiusArray {
        rInner := ringRadius.inner
        rOuter := ringRadius.outer
        sectorCount := SectorsPerRing[ringIdx]
        GpDrawEllipse(gpGraphics, penArgb, App_PenWidth, CX - rOuter, CY - rOuter, CX + rOuter, CY + rOuter)
        if (ringIdx < RingCount) {
            GpDrawEllipse(gpGraphics, penArgb, App_PenWidth, CX - rInner, CY - rInner, CX + rInner, CY + rInner)
        }
        if (sectorCount <= 0)
            continue
        angleStep := 6.283185307179586 / sectorCount
        startAngle := GetClockStartAngle(sectorCount)
        loop sectorCount {
            angle := startAngle + (A_Index - 1) * angleStep
            GpDrawLine(gpGraphics, penArgb, App_PenWidth, Round(CX + rInner * Cos(angle)), Round(CY + rInner * Sin(
                angle)), Round(CX + rOuter * Cos(angle)), Round(CY + rOuter * Sin(angle)))
        }
    }
    ; 取消半径环
    if (App_EscapeRadius > 0) {
        escapeArgb := RGBToARGB(0x808080, 255)
        GpDrawEllipse(gpGraphics, escapeArgb, 1, CX - R - App_EscapeRadius, CY - R - App_EscapeRadius, CX + R +
            App_EscapeRadius, CY + R + App_EscapeRadius)
    }
}

; 创建可复用的文字资源。
; 原版 GpDrawText() 每画一个扇区都重新创建 FontFamily/Font/Brush/Format，
; 扇区越多浪费越明显。现在整个内容位图只创建一次这些对象。
CreateTextRenderResources() {
    global App_FontSize, App_FontWeight, App_TextColor
    family := 0
    font := 0
    brush := 0
    format := 0
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "微软雅黑", "Ptr", 0, "Ptr*", &family)
    if (!family) {
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Arial", "Ptr", 0, "Ptr*", &family)
    }
    if (!family)
        return [0, 0, 0, 0]
    fontStyle := (App_FontWeight >= 700) ? 1 : 0
    DllCall("gdiplus\GdipCreateFont", "Ptr", family, "Float", App_FontSize, "Int", fontStyle, "Int", 2, "Ptr*", &font)

    if (!font) {
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", family)
        return [0, 0, 0, 0]
    }
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", RGBToARGB(App_TextColor, 255), "Ptr*", &brush)
    if (!brush) {
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", family)
        return [0, 0, 0, 0]
    }
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &format)

    if (!format) {
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", family)
        return [0, 0, 0, 0]
    }
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", format, "Int", 1)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", format, "Int", 1)
    return [family, font, brush, format]
}

DeleteTextRenderResources(resources) {
    if !IsObject(resources)
        return
    family := resources[1]
    font := resources[2]
    brush := resources[3]
    format := resources[4]
    if (font)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
    if (family)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", family)
    if (brush)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    if (format)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", format)
}

DrawCachedText(gpGraphics, text, x, y, resources) {
    global App_FontSize
    if !IsObject(resources)
        return
    font := resources[2]
    brush := resources[3]
    format := resources[4]
    if (!font || !brush || !format)
        return
    rectF := Buffer(16, 0)
    NumPut("Float", x - 60, "Float", y - App_FontSize * 1.5, "Float", 120, "Float", App_FontSize * 3, rectF)
    DllCall("gdiplus\GdipDrawString", "Ptr", gpGraphics, "WStr", text, "Int", -1, "Ptr", font, "Ptr", rectF, "Ptr",
        format, "Ptr", brush)
}

; 扇区图标统一走 IconManager，避免第三套缓存并存。
GetCachedSectorIcon(iconStr) {
    return IconManager.Get(iconStr)
}

; 绘制动态层：文字 + 图标。这一层会在 Profile 切换时重新生成，但不会重建 GUI / 静态 HBITMAP。
DrawContentGraphics(gpGraphics, textArgb) {
    global CX, CY, RingCount, SectorsPerRing, RingRadiusArray, SectorOffset
    global ActionConfig, ShowSectorIcon, App_FontSize
    resources := CreateTextRenderResources()
    ; 文字
    for ringIdx, ringRadius in RingRadiusArray {
        rInner := ringRadius.inner
        rOuter := ringRadius.outer
        sectorCount := SectorsPerRing[ringIdx]
        if (sectorCount <= 0)
            continue
        ringOffset := SectorOffset[ringIdx]
        angleStep := 6.283185307 / sectorCount
        rText := (rInner + rOuter) / 2
        loop sectorCount {
            idx := ringOffset + A_Index - 1
            sec := String(idx)
            startAngle := GetClockStartAngle(sectorCount)
            angleStep := 6.283185307179586 / sectorCount
            midAngle := startAngle + (A_Index - 0.5) * angleStep
            textX := Round(CX + rText * Cos(midAngle))
            textY := Round(CY + rText * Sin(midAngle))
            name := ActionConfig.Has(sec) ? ActionConfig[sec]["Name"] : sec
            DrawCachedText(gpGraphics, name, textX, textY + 6, resources)
        }
    }
    ; 图标
    if ShowSectorIcon {
        iconSize := 24
        for ringIdx, ringRadius in RingRadiusArray {
            rInner := ringRadius.inner
            rOuter := ringRadius.outer
            sectorCount := SectorsPerRing[ringIdx]
            if (sectorCount <= 0)
                continue
            ringOffset := SectorOffset[ringIdx]
            angleStep := 6.283185307 / sectorCount
            rText := (rInner + rOuter) / 2
            loop sectorCount {
                idx := ringOffset + A_Index - 1
                sec := String(idx)
                startAngle := GetClockStartAngle(sectorCount)
                angleStep := 6.283185307179586 / sectorCount
                midAngle := startAngle + (A_Index - 0.5) * angleStep
                textX := Round(CX + rText * Cos(midAngle))
                textY := Round(CY + rText * Sin(midAngle))
                cfg := ActionConfig.Has(sec) ? ActionConfig[sec] : ""
                if (!cfg || !cfg.Has("Icon") || cfg["Icon"] = "")
                    continue
                hIcon := GetCachedSectorIcon(cfg["Icon"])
                if (!hIcon)
                    continue
                gpIconBmp := 0
                DllCall("gdiplus\GdipCreateBitmapFromHICON", "Ptr", hIcon, "Ptr*", &gpIconBmp)
                if gpIconBmp {
                    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", gpGraphics, "Ptr", gpIconBmp, "Int", textX - iconSize //
                        2, "Int", textY - iconSize - 4, "Int", iconSize, "Int", iconSize)
                    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpIconBmp)
                }
            }
        }
    }
    DeleteTextRenderResources(resources)
}

; 重建鼠标辅助线位图  圆心固定在 CX/CY。  dx/dy 是鼠标相对于右键按下点的屏幕坐标偏移。
RebuildGuideBitmap(dx, dy) {
    global hBmpGuide
    global GuideGui
    global W, H, CX, CY
    global App_GuideColor
    global App_GuideAlpha
    global App_GuideWidth
    global startMouseX
    global startMouseY
    if !IsObject(GuideGui)
        return false
    ; 删除旧位图
    if (hBmpGuide) {
        DllCall("DeleteObject", "Ptr", hBmpGuide)
        hBmpGuide := 0
    }
    ; 新建透明 GDI+ Bitmap
    info := CreateGpBitmapAndGraphics(W, H)
    gpBitmap := info[1]
    gpGraphics := info[2]
    ; 鼠标相对于圆心的位置
    endX := CX + dx
    endY := CY + dy
    ; 辅助线
    GpDrawLine(gpGraphics, RGBToARGB(App_GuideColor, App_GuideAlpha), App_GuideWidth, CX, CY, endX, endY)
    ; 圆心小圆点
    GpFillCircle(gpGraphics, RGBToARGB(App_GuideColor, 210), CX, CY, App_GuideCenterRadius)
    ; 转换 HBITMAP
    hBmpGuide := GpBitmapToHBITMAP(gpBitmap)
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gpGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", gpBitmap)
    if !hBmpGuide
        return false
    ; 更新 GuideGui
    UpdateLayeredWindowEx(GuideGui.Hwnd, hBmpGuide, W, H, 255, true, startMouseX - CX, startMouseY - CY)
    GuideGui.Show("NA")
    return true
}

HideGuideLine() {
    global GuideGui
    global hBmpGuide
    if IsObject(GuideGui) {
        try GuideGui.Hide()
    }
    if (hBmpGuide) {
        try DllCall("DeleteObject", "Ptr", hBmpGuide)
        hBmpGuide := 0
    }
}

; 删除图标缓存（统一使用 IconManager）。
ClearIconCache() {
    IconManager.Clear()
}

; 创建分层窗口。所有层均点击穿透：
; 扇区命中由全局鼠标坐标计算，左键执行用热键处理，
; 避免 AlwaysOnTop 层窗口挡住任务栏/其它程序。
CreateLayeredGui(isContent := false) {
    ; 所有视觉层都是“点击穿透窗口”。
    ; V0.27 不让这些窗口在空闲时永久处于 TOPMOST，只有菜单显示期间临时置顶。
    ; 这样可以降低透明窗口长期残留造成的系统点击异常概率。
    ; 注意：NoActivate 只能用于 Show()，不能作为 Gui() 构造选项。
    ; 不激活效果由下面的 WS_EX_NOACTIVATE 扩展样式实现。
    g := Gui("-Caption +ToolWindow")
    g.Show("Hide w1 h1")
    ApplyLayeredClickThroughStyles(g.Hwnd)
    return g
}

; 给分层窗口打上：LAYERED + NOACTIVATE + TRANSPARENT（点击穿透，不抢焦点）
ApplyLayeredClickThroughStyles(hwnd) {
    if !hwnd
        return
    longFunc := A_PtrSize = 8 ? "user32\GetWindowLongPtr" : "user32\GetWindowLong"
    setFunc := A_PtrSize = 8 ? "user32\SetWindowLongPtr" : "user32\SetWindowLong"
    exStyle := DllCall(longFunc, "Ptr", hwnd, "Int", -20, "Ptr")
    exStyle |= 0x80000       ; WS_EX_LAYERED
    exStyle |= 0x08000000    ; WS_EX_NOACTIVATE
    exStyle |= 0x20          ; WS_EX_TRANSPARENT
    DllCall(setFunc, "Ptr", hwnd, "Int", -20, "Ptr", exStyle)
}

HandleLayeredHitTest(wParam, lParam, msg, hwnd) {
    ; V0.26.0 的问题：只有 Content/Highlight 层返回 HTTRANSPARENT，
    ; MyGui / GuideGui 仍可能返回 HTCLIENT。
    ; 四层窗口都是 AlwaysOnTop，因此它们可能遮挡任务栏或其它窗口的点击。
    global MyGui, ContentGui, GuideGui, HighlightGui

    try {
        if (IsObject(MyGui) && hwnd = MyGui.Hwnd)
            return -1   ; HTTRANSPARENT
    }
    try {
        if (IsObject(ContentGui) && hwnd = ContentGui.Hwnd)
            return -1   ; HTTRANSPARENT
    }
    try {
        if (IsObject(GuideGui) && hwnd = GuideGui.Hwnd)
            return -1   ; HTTRANSPARENT
    }
    try {
        if (IsObject(HighlightGui) && hwnd = HighlightGui.Hwnd)
            return -1   ; HTTRANSPARENT
    }
}

SetLayeredWindowPosition(x, y, show := false) {
    global MyGui
    global ContentGui
    global GuideGui
    global HighlightGui
    global W, H
    if !IsObject(MyGui)
        return
    if show {
        MyGui.Show("x" x " y" y " w" W " h" H " NoActivate")
        if IsObject(ContentGui) {
            ContentGui.Show("x" x " y" y " w" W " h" H " NoActivate")
        }
        if IsObject(GuideGui) {
            GuideGui.Show("x" x " y" y " w" W " h" H " NoActivate")
        }
        if IsObject(HighlightGui) {
            ; 关键：高亮层是 WS_EX_LAYERED 窗口，其像素完全由最后一次 UpdateLayeredWindow 决定。
            ; 这里只负责“定位+保持隐藏”，绝不能直接 Show，否则上次残留的扇区高亮画面会被重新显示出来。
            ; 高亮层的可见性交由 UpdateHighlightLayer 全权管理（Always 先绘制新位图再 Show）。
            HighlightGui.Show("x" x " y" y " w" W " h" H " NoActivate Hide")
        }
    } else {
        MyGui.Show("x" x " y" y " NoActivate")
        if IsObject(ContentGui)
            ContentGui.Show("x" x " y" y " NoActivate")
        if IsObject(GuideGui)
            GuideGui.Show("x" x " y" y " NoActivate")
        if IsObject(HighlightGui)
            HighlightGui.Show("x" x " y" y " NoActivate Hide")
    }
    ; 菜单显示期间临时置顶；菜单隐藏时取消 TOPMOST。
    SetLayeredWindowsTopmost(show)
    ; Show() 后重新确保点击穿透，避免样式丢失导致透明层挡住系统点击。
    if IsObject(MyGui)
        ApplyLayeredClickThroughStyles(MyGui.Hwnd)
    if IsObject(ContentGui)
        ApplyLayeredClickThroughStyles(ContentGui.Hwnd)
    if IsObject(GuideGui)
        ApplyLayeredClickThroughStyles(GuideGui.Hwnd)
    if IsObject(HighlightGui)
        ApplyLayeredClickThroughStyles(HighlightGui.Hwnd)

}

; ------------------------------------------------------------
; 统一控制四个视觉层的 TOPMOST 状态。
; 空闲时使用 HWND_NOTOPMOST，避免透明层长期挡住 Windows 点击。
; ------------------------------------------------------------
SetLayeredWindowsTopmost(enable := true) {
    global MyGui, ContentGui, GuideGui, HighlightGui

    insertAfter := enable ? -1 : -2

    if IsObject(MyGui)
        try DllCall("SetWindowPos", "Ptr", MyGui.Hwnd, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)

    if IsObject(ContentGui)
        try DllCall("SetWindowPos", "Ptr", ContentGui.Hwnd, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)

    if IsObject(GuideGui)
        try DllCall("SetWindowPos", "Ptr", GuideGui.Hwnd, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)

    if IsObject(HighlightGui)
        try DllCall("SetWindowPos", "Ptr", HighlightGui.Hwnd, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
}

; 释放视觉资源，不关闭 GDI+。
ReleaseMainVisualResources() {
    global MyGui
    global ContentGui
    global GuideGui
    global HighlightGui
    global hBmpMain
    global hBmpBase
    global hBmpContent
    global hBmpGuide
    global hBmpHighlight
    global MenuVisualReady

    ; 释放前先取消 TOPMOST，避免窗口在销毁瞬间继续参与 Z-Order。
    try SetLayeredWindowsTopmost(false)

    ; Guide
    if IsObject(GuideGui) {
        try GuideGui.Hide()
        try GuideGui.Destroy()
        GuideGui := ""
    }
    if (hBmpGuide) {
        try DllCall("DeleteObject", "Ptr", hBmpGuide)
        hBmpGuide := 0
    }

    ; Content
    if IsObject(ContentGui) {
        try ContentGui.Hide()
        try ContentGui.Destroy()
        ContentGui := ""
    }

    ; Highlight
    if IsObject(HighlightGui) {
        try HighlightGui.Hide()
        try HighlightGui.Destroy()
        HighlightGui := ""
    }
    if (hBmpHighlight) {
        try DllCall("DeleteObject", "Ptr", hBmpHighlight)
        hBmpHighlight := 0
    }

    ; Base
    if IsObject(MyGui) {
        try MyGui.Hide()
        try MyGui.Destroy()
        MyGui := ""
    }
    if (hBmpContent) {
        try DllCall("DeleteObject", "Ptr", hBmpContent)
        hBmpContent := 0
    }
    if (hBmpBase) {
        try DllCall("DeleteObject", "Ptr", hBmpBase)
        hBmpBase := 0
    }
    hBmpMain := 0
    MenuVisualReady := false
}

; 复位扇区高亮状态，确保每次交互/弹出都以无高亮初始状态开始 (V0.21)
; 只清理高亮相关状态，不隐藏基础/内容/辅助线层。
ResetHighlightState() {
    global HighlightedSector
    global hBmpHighlight
    global HighlightGui

    HighlightedSector := ""
    if (hBmpHighlight) {
        DllCall("DeleteObject", "Ptr", hBmpHighlight)
        hBmpHighlight := 0
    }
    if IsObject(HighlightGui)
        try HighlightGui.Hide()
}

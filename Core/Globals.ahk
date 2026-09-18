; ========== 右键交互全局变量 (提前声明，防止 auto-execute 中途崩溃导致未赋值) ==========
isMenuVisible := false
hasDragged := false
startMouseX := 0, startMouseY := 0
threshold := 5
timerActive := false
menuWasOpen := false
rbuttonDown := false   ; 记录右键是否按下（逻辑标志），适应模拟右键点击
rightButtonForwarded := false   ; 已向 Windows 转发 RightButton Down，Up 必须成对返回
isForwardingRightButton := false   ; 正在 SendInput 右键，防止重入触发 $RButton
ateRightButtonDown := false   ; 热键吞掉了右键 Down（如关闭圆形菜单），Up 必须一并吞掉
ourRButtonDown := false   ; 本次物理右键 Down 是否被我们拦截；Up 只在为 true 时拦截
popupMenuOpen := false   ; 脚本自己 Show() 了弹出菜单（阻塞期间必须放行右键）
MouseMonitorPaused := false   ; 仅暂停鼠标监控，不影响热键
StartupComplete := false   ; 是否已启动完成（在 StartTRunner 末尾置真）
circleMenuOpen := false   ; 热键（Win+Alt+空格）弹出的圆形窗口菜单是否打开
lastPollX := 0, lastPollY := 0   ; CheckMouseMove 上一次采样的鼠标屏幕坐标

InitGDIPlus() {
    return GdiPlusManager.Ensure()
}

; 用 GDI+ 画抗锯齿椭圆 (参数: graphics, penColor, penWidth, left, top, right, bottom)
GpDrawEllipse(gpGraphics, penColor, penWidth, x1, y1, x2, y2) {
    gpPen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", penColor, "Float", penWidth, "Int", 0, "Ptr*", &gpPen)
    DllCall("gdiplus\GdipDrawEllipse", "Ptr", gpGraphics, "Ptr", gpPen,
        "Float", x1, "Float", y1, "Float", x2 - x1, "Float", y2 - y1)
    DllCall("gdiplus\GdipDeletePen", "Ptr", gpPen)
}

; 用 GDI+ 画抗锯齿直线
GpDrawLine(gpGraphics, penColor, penWidth, x1, y1, x2, y2) {
    gpPen := 0
    DllCall("gdiplus\GdipCreatePen1", "UInt", penColor, "Float", penWidth, "Int", 0, "Ptr*", &gpPen)
    DllCall("gdiplus\GdipDrawLine", "Ptr", gpGraphics, "Ptr", gpPen,
        "Float", x1, "Float", y1, "Float", x2, "Float", y2)
    DllCall("gdiplus\GdipDeletePen", "Ptr", gpPen)
}

; 用 GDI+ 画抗锯齿文字
; GDI+ 文本资源缓存：避免每次画字都创建/销毁 FontFamily / Format / Brush
_GpFontFamily := 0
_GpStringFormat := 0
_GpBrushCache := Map()

GpEnsureFontFamily() {
    global _GpFontFamily
    if (_GpFontFamily)
        return _GpFontFamily
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "微软雅黑", "Ptr", 0, "Ptr*", &_GpFontFamily)
    if (!_GpFontFamily)
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Arial", "Ptr", 0, "Ptr*", &_GpFontFamily)
    return _GpFontFamily
}

GpEnsureStringFormat() {
    global _GpStringFormat
    if (_GpStringFormat)
        return _GpStringFormat
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &_GpStringFormat)
    if (_GpStringFormat) {
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", _GpStringFormat, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", _GpStringFormat, "Int", 1)
    }
    return _GpStringFormat
}

GpGetSolidBrush(argb) {
    global _GpBrushCache
    if _GpBrushCache.Has(argb)
        return _GpBrushCache[argb]
    brush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &brush)
    if brush
        _GpBrushCache[argb] := brush
    return brush
}

GpClearTextResourceCache() {
    global _GpFontFamily, _GpStringFormat, _GpBrushCache
    if (_GpFontFamily)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", _GpFontFamily)
    _GpFontFamily := 0
    if (_GpStringFormat)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", _GpStringFormat)
    _GpStringFormat := 0
    for _, brush in _GpBrushCache {
        if brush
            try DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }
    _GpBrushCache := Map()
}

GpDrawText(gpGraphics, text, fontSize, fontWeight, textColor, x, y) {
    gpFontFamily := GpEnsureFontFamily()
    gpFormat := GpEnsureStringFormat()
    if (!gpFontFamily || !gpFormat)
        return
    gpBrush := GpGetSolidBrush(textColor)
    if (!gpBrush)
        return
    gpFont := 0
    fontStyle := (fontWeight >= 700) ? 1 : 0
    DllCall("gdiplus\GdipCreateFont", "Ptr", gpFontFamily, "Float", fontSize,
        "Int", fontStyle, "Int", 2, "Ptr*", &gpFont)
    if (gpFont = 0)
        return
    rectF := Buffer(16)
    NumPut("Float", x - 60, "Float", y - fontSize * 1.5, "Float", 120, "Float", fontSize * 3, rectF)
    DllCall("gdiplus\GdipDrawString", "Ptr", gpGraphics, "WStr", text, "Int", -1,
        "Ptr", gpFont, "Ptr", rectF, "Ptr", gpFormat, "Ptr", gpBrush)
    DllCall("gdiplus\GdipDeleteFont", "Ptr", gpFont)
}

; 用 GDI+ 绘制圆形 (ARGB 颜色: AARRGGBB)
GpFillCircle(gpGraphics, argbColor, cx, cy, radius) {
    gpBrush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argbColor, "Ptr*", &gpBrush)
    DllCall("gdiplus\GdipFillEllipse", "Ptr", gpGraphics, "Ptr", gpBrush,
        "Float", cx - radius, "Float", cy - radius,
        "Float", radius * 2, "Float", radius * 2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", gpBrush)
}

; 用 GDI+ 绘制扇形区域 (ARGB 颜色, 角度均为弧度, 0=右, 顺时针) (V0.21)
GpFillSector(gpGraphics, argbColor, cx, cy, rInner, rOuter, startAngle, sweepAngle) {
    path := 0
    DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)  ; FillModeAlternate
    degStart := startAngle * 180 / 3.141592653589793
    degSweep := sweepAngle * 180 / 3.141592653589793
    ; 外弧 (顺时针)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
        "Float", cx - rOuter, "Float", cy - rOuter,
        "Float", rOuter * 2, "Float", rOuter * 2,
        "Float", degStart, "Float", degSweep)
    ; 外弧终点 -> 内弧终点
    endAngle := startAngle + sweepAngle
    DllCall("gdiplus\GdipAddPathLine", "Ptr", path,
        "Float", cx + rOuter * Cos(endAngle), "Float", cy + rOuter * Sin(endAngle),
        "Float", cx + rInner * Cos(endAngle), "Float", cy + rInner * Sin(endAngle))
    ; 内弧 (逆时针)
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
        "Float", cx - rInner, "Float", cy - rInner,
        "Float", rInner * 2, "Float", rInner * 2,
        "Float", degStart + degSweep, "Float", -degSweep)
    DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
    ; 填充
    gpBrush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", argbColor, "Ptr*", &gpBrush)
    DllCall("gdiplus\GdipFillPath", "Ptr", gpGraphics, "Ptr", gpBrush, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", gpBrush)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

; ============================================================
;  3.2 GDI+ Alpha 混合渲染辅助函数

; 创建 GDI+ 32位 ARGB Bitmap 和 Graphics 上下文 (纯 GDI+，无需 DIB)
; 返回 [gpBitmap, gpGraphics] - 绘制完成后调用 GpBitmapToHBITMAP 转换为 HBITMAP
CreateGpBitmapAndGraphics(width, height) {
    gpBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", width, "Int", height, "Int", 0, "Int", 0x26200A, "Ptr", 0,
        "Ptr*", &gpBitmap)
    gpGraphics := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", gpBitmap, "Ptr*", &gpGraphics)
    ; 抗锯齿
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gpGraphics, "Int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", gpGraphics, "Int", 4)
    ; 高清图标缩放
    ; 7 = HighQualityBicubic
    ; 比默认的图像插值质量高很多。
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", gpGraphics, "Int", 7)
    DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", gpGraphics, "Int", 2)
    DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", gpGraphics, "Int", 2)
    return [gpBitmap, gpGraphics]
}

; 将 GDI+ Bitmap 转换为 HBITMAP (32位 ARGB，可用于 UpdateLayeredWindow)
GpBitmapToHBITMAP(gpBitmap) {
    hBitmap := 0
    ; background = 0x00000000 (完全透明的黑色背景)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", gpBitmap, "Ptr*", &hBitmap, "UInt", 0)
    return hBitmap
}

; RGB 转 ARGB (添加 Alpha 通道)
RGBToARGB(rgb, alpha := 255) {
    ; ARGB 格式: AARRGGBB
    return (alpha << 24) | rgb
}

; 使用 UpdateLayeredWindow API 更新分层窗口
; usePerPixelAlpha: true = 使用位图中的每像素 alpha，false = 使用统一 alpha
; destX, destY: 目标位置 (屏幕坐标)，-1 表示使用当前窗口位置
UpdateLayeredWindowEx(hwnd, hBmp, width, height, alpha := 255, usePerPixelAlpha := true, destX := -1, destY := -1) {
    ; 获取屏幕 DC
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hOldBmp := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmp)

    ; BLENDFUNCTION 结构
    bf := Buffer(4)
    NumPut("UChar", 0, bf, 0)           ; BlendOp: AC_SRC_OVER = 0
    NumPut("UChar", 0, bf, 1)           ; BlendFlags
    NumPut("UChar", alpha, bf, 2)       ; SourceConstantAlpha
    NumPut("UChar", usePerPixelAlpha ? 1 : 0, bf, 3)  ; AlphaFormat: AC_SRC_ALPHA = 1

    ; SIZE 结构
    size := Buffer(8)
    NumPut("Int", width, size, 0)
    NumPut("Int", height, size, 4)

    ; POINT 结构 (源位置 = 0, 0)
    ptSrc := Buffer(8)
    NumPut("Int", 0, ptSrc, 0)
    NumPut("Int", 0, ptSrc, 4)

    ; POINT 结构 (目标位置)
    ; 如果未指定位置 (-1)，获取当前窗口位置，避免移动窗口
    ptDst := Buffer(8)
    if (destX = -1 || destY = -1) {
        ; 获取当前窗口矩形
        rect := Buffer(16)
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
        currentX := NumGet(rect, 0, "Int")
        currentY := NumGet(rect, 4, "Int")
        NumPut("Int", currentX, ptDst, 0)
        NumPut("Int", currentY, ptDst, 4)
    } else {
        NumPut("Int", destX, ptDst, 0)
        NumPut("Int", destY, ptDst, 4)
    }

    ; 调用 UpdateLayeredWindow (ULW_ALPHA = 2)
    DllCall("UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScreen,
        "Ptr", ptDst, "Ptr", size, "Ptr", hdcMem, "Ptr", ptSrc,
        "UInt", 0, "Ptr", bf, "UInt", 2)

    ; 清理
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBmp)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
}

; ============================================================
;  3.3 数学工具 — ATan2
ATan2(y, x) {
    if (x > 0)
        return ATan(y / x)
    if (x < 0) {
        if (y >= 0)
            return ATan(y / x) + 3.141592653589793
        else
            return ATan(y / x) - 3.141592653589793
    }
    if (y > 0)
        return 1.5707963267948966
    if (y < 0)
        return -1.5707963267948966
    return 0
}

; ========== 全局变量：配置相关 ==========
ActionConfig := Map()       ; 当前活跃的扇区配置
DefaultConfig := Map()     ; 默认扇区配置 (无匹配 profile 时使用)
Profiles := Map()          ; 所有 profile: Map<profileName, Map<"ahkHandles", "sectors">>
jsonFile := ""   ; 将在 LoadConfig 中被赋值
ShowMenuIcon := 1
ShowSectorIcon := 1
TotalSectors := 0  ; 存储扇区总数
LastConfigModTime := 0

; --- 外观配置 (可在 Settings.json 的 appearance 节点中修改) ---
App_WindowSize := 500
App_OuterRadius := 250
App_PenColor := 0xFFFFFF
App_PenWidth := 2
App_BgColor := 0xF0F0F0
App_TextColor := 0x000000
App_FontSize := 14
App_FontWeight := 700
App_EscapeRadius := 40
App_Background := "default"  ; default | transparent | comfortable
App_BackgroundAlpha := 230   ; comfortable 模式下的整体透明度 (0-255)

; --- Profile 切换状态 ---
CurrentProfile := ""  ; 当前活跃的 profile 名称，空字符串 = 默认
LastProfileHWND := 0  ; 上一次检测到的活跃窗口句柄

; --- 绘制状态 (供 BuildMenuGUI 和交互代码共享) ---
W := 500, H := 500
CX := 250, CY := 250
R := 250, R3 := 31
RingCount := 1
SectorsPerRing := []
RingRadiusArray := []
SectorOffset := []
hBmpMain := 0              ; 兼容旧变量，指向当前内容位图
hBmpBase := 0               ; 静态层：背景/圆环/分割线
hBmpContent := 0            ; 动态层：文字/图标
MyGui := ""                 ; 静态分层窗口
ContentGui := ""            ; 动态内容分层窗口（鼠标穿透）
GuideGui := ""              ; 鼠标辅助线层
hBmpGuide := 0              ; 辅助线位图
App_GuideColor := 0x8AA6A3   ; 辅助线颜色
App_GuideAlpha := 175        ; 辅助线透明度 (0-255)
App_GuideWidth := 3          ; 辅助线宽度 (1-3)
App_GuideCenterRadius := 3   ; 辅助线中心半径 (1-3)
App_HighlightColor := 0x3399FF  ; 扇区高亮颜色 (V0.21)
App_HighlightAlpha := 80        ; 扇区高亮透明度 0-255 (V0.21)
HighlightedSector := ""         ; 当前高亮的扇区编号 (V0.21)
hBmpHighlight := 0              ; 高亮层位图 (V0.21)
HighlightGui := ""              ; 高亮层窗口 (V0.21)
; 扇区图标缓存已统一到 IconManager.Cache
StaticVisualSignature := ""  ; 外观+布局签名
ContentVisualSignature := "" ; 内容签名
LayoutSignature := ""
MenuVisualReady := false
RuntimeBusy := false
IsReloading := false
CleanupRunning := false

isInteracting := false

; ------------------- 电源状态------------------
PreventSleep := false
; SetThreadExecutionState
ES_CONTINUOUS := 0x80000000
ES_SYSTEM_REQUIRED := 0x00000001
ES_DISPLAY_REQUIRED := 0x00000002
PowerMenu := ""
ProfileMenu := ""

; isReload=true 时配置失败只提示并保留旧配置，不退出进程

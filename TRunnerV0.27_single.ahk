; ===== BEGIN INCLUDE Core/Version.ahk =====

; ======== Core/Version.ahk ========
; Core — 版本信息（语义化版本 SemVer 2.0.0）
; MAJOR 不兼容变更 | MINOR 新功能 | PATCH 缺陷修复

AppName := "TRunner"
AppEnglishName := "TRunner"
AppSourceUrl := "https://github.com/delphixt/TRunner"
AppVersionMajor := 0
AppVersionMinor := 27
AppVersionPatch := 8
AppVersion := AppVersionMajor "." AppVersionMinor "." AppVersionPatch
AppUpdateDate := "2026-09-17"
AppAuthor := "寻月"
AppCopyright := "Copyright © 2026 " AppAuthor "，保留所有权利。"

; ===== END INCLUDE Core/Version.ahk =====

; ===== BEGIN INCLUDE Core/Json.ahk =====

; ======== Core/Json.ahk ========
; Core — JSON
class Json {
    static Parse(str) {
        pos := 1
        value := Json._ParseValue(&pos, str)
        Json._SkipWhitespace(&pos, str)
        if (pos <= StrLen(str))
            throw Error("JSON 后存在无效内容，位置：" pos)
        return value
    }
    static _ParseValue(&pos, str) {
        Json._SkipWhitespace(&pos, str)
        if (pos > StrLen(str))
            throw Error("JSON 意外结束")
        ch := SubStr(str, pos, 1)
        if (ch = "{")
            return Json._ParseObject(&pos, str)
        if (ch = "[")
            return Json._ParseArray(&pos, str)
        if (ch = '"')
            return Json._ParseString(&pos, str)
        if (ch = "-" || (ch >= "0" && ch <= "9"))
            return Json._ParseNumber(&pos, str)
        if (SubStr(str, pos, 4) = "true") {
            pos += 4
            return true
        }
        if (SubStr(str, pos, 5) = "false") {
            pos += 5
            return false
        }
        if (SubStr(str, pos, 4) = "null") {
            pos += 4
            return ""
        }
        throw Error("JSON 无效字符：" ch "，位置：" pos)
    }
    static _SkipWhitespace(&pos, str) {
        while (pos <= StrLen(str) && InStr(" `t`n`r", SubStr(str, pos, 1)))
            pos++
    }
    static _ParseString(&pos, str) {
        pos++
        result := ""
        while (pos <= StrLen(str)) {
            ch := SubStr(str, pos, 1)
            if (ch = '"') {
                pos++
                return result
            }
            if (ch = "\") {
                pos++
                if (pos > StrLen(str))
                    throw Error("JSON 转义字符未完成")
                next := SubStr(str, pos, 1)
                switch next {
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    case "b": result .= Chr(8)
                    case "f": result .= Chr(12)
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "t": result .= "`t"
                    case "u":
                        if (pos + 4 > StrLen(str))
                            throw Error("JSON Unicode 转义无效")
                        hex := SubStr(str, pos + 1, 4)
                        if !RegExMatch(hex, "i)^[0-9a-f]{4}$")
                            throw Error("JSON Unicode 转义无效：" hex)
                        result .= Chr(Integer("0x" hex))
                        pos += 4
                    default: result .= next
                }
            } else {
                result .= ch
            }
            pos++
        }
        throw Error("JSON 字符串未闭合")
    }
    static _ParseNumber(&pos, str) {
        start := pos
        if (SubStr(str, pos, 1) = "-")
            pos++
        while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
            pos++
        if (SubStr(str, pos, 1) = ".") {
            pos++
            while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
                pos++
        }
        ch := SubStr(str, pos, 1)
        if (ch = "e" || ch = "E") {
            pos++
            ch := SubStr(str, pos, 1)
            if (ch = "+" || ch = "-")
                pos++
            while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
                pos++
        }
        return Number(SubStr(str, start, pos - start))
    }
    static _ParseArray(&pos, str) {
        pos++
        arr := []
        Json._SkipWhitespace(&pos, str)
        if (SubStr(str, pos, 1) = "]") {
            pos++
            return arr
        }
        loop {
            arr.Push(Json._ParseValue(&pos, str))
            Json._SkipWhitespace(&pos, str)
            ch := SubStr(str, pos, 1)
            if (ch = "]") {
                pos++
                return arr
            }
            if (ch != ",")
                throw Error("JSON 数组缺少逗号")
            pos++
        }
    }
    static _ParseObject(&pos, str) {
        pos++
        obj := Map()
        Json._SkipWhitespace(&pos, str)
        if (SubStr(str, pos, 1) = "}") {
            pos++
            return obj
        }
        loop {
            Json._SkipWhitespace(&pos, str)
            if (SubStr(str, pos, 1) != '"')
                throw Error("JSON 对象键必须是字符串")
            key := Json._ParseString(&pos, str)
            Json._SkipWhitespace(&pos, str)
            if (SubStr(str, pos, 1) != ":")
                throw Error("JSON 缺少冒号")
            pos++
            obj[key] := Json._ParseValue(&pos, str)
            Json._SkipWhitespace(&pos, str)
            ch := SubStr(str, pos, 1)
            if (ch = "}") {
                pos++
                return obj
            }
            if (ch != ",")
                throw Error("JSON 对象缺少逗号")
            pos++
        }
    }
    static Stringify(value, pretty := true, indent := 2) {
        return Json._Serialize(value, 0, pretty, indent)
    }
    static _Serialize(value, level, pretty, indent) {
        valueType := Type(value)

        if (valueType = "Map") {
            result := "{"
            first := true
            for key, item in value {
                if first
                    first := false
                else
                    result .= ","
                if pretty
                    result .= "`n" Json._Repeat(" ", (level + 1) * indent)
                result .= Json._Quote(String(key)) ":"
                if pretty
                    result .= " "
                result .= Json._Serialize(item, level + 1, pretty, indent)
            }
            if !first && pretty
                result .= "`n" Json._Repeat(" ", level * indent)
            return result "}"
        }

        if (valueType = "Array") {
            result := "["
            first := true
            for _, item in value {
                if first
                    first := false
                else
                    result .= ","
                if pretty
                    result .= "`n" Json._Repeat(" ", (level + 1) * indent)
                result .= Json._Serialize(item, level + 1, pretty, indent)
            }
            if !first && pretty
                result .= "`n" Json._Repeat(" ", level * indent)
            return result "]"
        }

        if (valueType = "String")
            return Json._Quote(value)

        if (valueType = "Integer" || valueType = "Float") {
            return String(value)
        }

        return "null"
    }
    static _Quote(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`t", "\t")
        return '"' str '"'
    }
    static _Repeat(text, count) {
        result := ""
        loop count
            result .= text
        return result
    }
}

; ============================================================
;  Region 2.2 — GDI+ 图形渲染管理
;  统一管理 GDI+ 初始化与关闭，全局单例
; ============================================================

; ===== END INCLUDE Core/Json.ahk =====

; ===== BEGIN INCLUDE Core/GdiPlus.ahk =====

; ======== Core/GdiPlus.ahk ========
; Core — GDI+
class GdiPlusManager {
    static Token := 0
    static Initialized := false

    static Ensure() {
        if GdiPlusManager.Initialized
            return true
        token := 0
        si := Buffer(16, 0)
        NumPut("UInt", 1, si, 0)
        result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0, "UInt")
        if (result != 0 || token = 0)
            return false
        GdiPlusManager.Token := token
        GdiPlusManager.Initialized := true
        return true
    }

    static Stop() {
        if !GdiPlusManager.Initialized
            return
        token := GdiPlusManager.Token
        if token
            DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
        GdiPlusManager.Token := 0
        GdiPlusManager.Initialized := false
    }
}

; ============================================================
;  Region 2.3 — Timer 定时器管理
;  集中管理所有 SetTimer，支持注册/注销/暂停
; ============================================================

; ===== END INCLUDE Core/GdiPlus.ahk =====

; ===== BEGIN INCLUDE Core/TimerManager.ahk =====

; ======== Core/TimerManager.ahk ========
; Core — Timer
class TimerManager {
    static Items := Map()
    static Register(name, callback, interval) {
        if TimerManager.Items.Has(name)
            TimerManager.Stop(name)
        TimerManager.Items[name] := callback
        SetTimer(callback, interval)
    }

    static Stop(name) {
        if !TimerManager.Items.Has(name)
            return
        callback := TimerManager.Items[name]
        try SetTimer(callback, 0)
        TimerManager.Items.Delete(name)
    }

    static StopAll() {
        for _, callback in TimerManager.Items {
            try SetTimer(callback, 0)
        }
        TimerManager.Items.Clear()
    }
}

; ============================================================
;  Region 2.4 — Power 电源管理
;  使用 Windows API 实现系统电源控制（关机/重启/注销/阻止熄屏）
; ============================================================

; ===== END INCLUDE Core/TimerManager.ahk =====

; ===== BEGIN INCLUDE Core/PowerManager.ahk =====

; ======== Core/PowerManager.ahk ========
; Core — Power
class PowerManager {
    static SetEnabled(enable := true) {
        try {
            if enable {
                flags := ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
                result := DllCall("Kernel32\SetThreadExecutionState", "UInt", flags, "UInt")
                if !result {
                    PreventSleep := false
                    return false
                }
                PreventSleep := true
                return true
            }
            result := DllCall("Kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS, "UInt")
            if !result
                return false
            PreventSleep := false
            return true
        } catch {
            return false
        }
    }
    static Cleanup() {
        global PreventSleep
        if PreventSleep
            PowerManager.SetEnabled(false)
    }
}

; ============================================================
;  Region 2.5 — Icon 图标管理
;  EXE/DLL/ICO 图标提取、缓存与路径规范化
; ============================================================

; ===== END INCLUDE Core/PowerManager.ahk =====

; ===== BEGIN INCLUDE Core/IconManager.ahk =====

; ======== Core/IconManager.ahk ========
; Core — Icon
class IconManager {
    static Cache := Map()
    static Parse(spec) {
        spec := Trim(String(spec))
        if spec = ""
            return { file: "", index: 0 }
        spec := StrReplace(spec, ",", ":")
        if RegExMatch(spec, "^(.+):(\d+)$", &m)
            return { file: IconManager.NormalizePath(m[1]), index: Integer(m[2]) }
        return { file: IconManager.NormalizePath(spec), index: 0 }
    }

    static NormalizePath(file) {
        file := Trim(String(file))
        if file = ""
            return ""
        if SubStr(file, 1, 1) = '"' && SubStr(file, -1) = '"'
            file := SubStr(file, 2, StrLen(file) - 2)
        if FileExist(file)
            return file
        if !InStr(file, "\") && !InStr(file, "/") {
            p := A_WinDir "\System32\" file
            if FileExist(p)
                return p
        }
        if !RegExMatch(file, "i)^[A-Za-z]:\\|^\\\\") {
            p := A_ScriptDir "\" file
            if FileExist(p)
                return p
        }
        return file
    }

    static Compose(file, index := 0) {
        file := Trim(String(file))
        if file = ""
            return ""
        try index := Max(0, Integer(index))
        catch
            index := 0
        return IconManager.NormalizePath(file) ":" index
    }

    static Get(spec) {
        info := IconManager.Parse(spec)
        if info.file = ""
            return 0
        key := StrLower(info.file) "|" info.index
        if IconManager.Cache.Has(key)
            return IconManager.Cache[key]
        ; 系统目录路径直接提取；其它路径先 FileExist，
        ; 但用 try 包住，避免异常驱动器导致拖死。
        try {
            isSystem := InStr(info.file, A_WinDir) = 1
            if (!isSystem && !FileExist(info.file))
                return 0
            hLarge := 0
            hSmall := 0
            count := DllCall("Shell32\ExtractIconExW", "WStr", info.file, "Int", info.index > 0 ? info.index - 1 : 0,
                "Ptr*", &hLarge, "Ptr*", &hSmall, "UInt", 1)
            if count <= 0
                return 0
            hIcon := hLarge ? hLarge : hSmall
            if hLarge && hSmall {
                if hIcon = hLarge
                    DllCall("DestroyIcon", "Ptr", hSmall)
                else
                    DllCall("DestroyIcon", "Ptr", hLarge)
            }
            IconManager.Cache[key] := hIcon
            return hIcon
        } catch {
            return 0
        }
    }

    static Clear() {
        for _, hIcon in IconManager.Cache {
            if hIcon
                try DllCall("DestroyIcon", "Ptr", hIcon)
        }
        IconManager.Cache.Clear()
    }
}

; ============================================================

; ===== END INCLUDE Core/IconManager.ahk =====

; ===== BEGIN INCLUDE Core/FeatureManager.ahk =====

; ============================================================
; Core/FeatureManager.ahk
; V0.27 功能生命周期管理
; ============================================================

class FeatureManager {
    static States := Map()
    static ShutdownCallbacks := Map()

    static Register(name, shutdownFunctionName := "") {
        if !FeatureManager.States.Has(name)
            FeatureManager.States[name] := "unloaded"

        if (shutdownFunctionName != "")
            FeatureManager.ShutdownCallbacks[name] := String(shutdownFunctionName)
    }

    static SetState(name, state) {
        FeatureManager.States[name] := state
    }

    static GetState(name) {
        return FeatureManager.States.Has(name)
            ? FeatureManager.States[name]
            : "unregistered"
    }

    static IsLoaded(name) {
        state := FeatureManager.GetState(name)
        return (state = "loaded" || state = "running")
    }

    static Shutdown(name) {
        if FeatureManager.ShutdownCallbacks.Has(name) {
            fnName := FeatureManager.ShutdownCallbacks[name]
            try {
                ; AHK v2 中 Func() 是类构造器，不能当工厂用（Invalid base）。
                ; 用动态调用 %fnName%()，兼容 Shutdown*(*) 签名。
                if (fnName != "")
                    %fnName%()
            }
        }
        FeatureManager.States[name] := "unloaded"
    }

    static ShutdownAll() {
        names := []
        for name, _ in FeatureManager.ShutdownCallbacks
            names.Push(name)

        for _, name in names
            FeatureManager.Shutdown(name)
    }
}

RegisterAllFeatures() {
    FeatureManager.Register("ClipboardHistory", "ShutdownClipboardHistory")
    FeatureManager.Register("InstalledApps", "ShutdownInstalledApps")
    FeatureManager.Register("HardwareInfo", "ShutdownHardwareInfo")
    FeatureManager.Register("Reminder", "ShutdownReminderFeature")
    FeatureManager.Register("Screenshot", "ShutdownScreenshotFeature")
    FeatureManager.Register("WindowManager", "ShutdownWindowManagerFeature")
    FeatureManager.Register("HiddenWindowManager", "ShutdownHiddenWindowManagerFeature")
}

; ===== END INCLUDE Core/FeatureManager.ahk =====

; ===== BEGIN INCLUDE Core/Globals.ahk =====

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

; ===== END INCLUDE Core/Globals.ahk =====

; ===== BEGIN INCLUDE Core/Config.ahk =====

; ======== Core/Config.ahk ========
; Core — Config+Profile
LoadConfig(isReload := false) {
    global ActionConfig, ShowMenuIcon, ShowSectorIcon, jsonFile, TotalSectors
    global App_WindowSize, App_OuterRadius, App_PenColor, App_PenWidth
    global App_BgColor, App_TextColor, App_FontSize, App_FontWeight, App_EscapeRadius
    global App_Background, App_BackgroundAlpha
    global App_HighlightColor, App_HighlightAlpha
    global DefaultConfig, Profiles, CurrentProfile, LastConfigModTime

    FailLoad(msg) {
        if isReload {
            TrayTip("配置热重载失败", msg, "Icon!")
            return false
        }
        MsgBox(msg, AppName, "IconX")
        ExitApp()
    }

    jsonFile := A_ScriptDir "\Settings.json"
    if !FileExist(jsonFile)
        return FailLoad("配置文件未找到：`n" jsonFile)

    rawText := FileRead(jsonFile, "UTF-8")
    try
        jsonObj := Json.Parse(rawText)
    catch as e
        return FailLoad("JSON 解析失败：`n" e.Message)

    if !(Type(jsonObj) = "Map")
        return FailLoad("JSON 顶层必须是对象")

    ActionConfig := Map()
    DefaultConfig := Map()
    Profiles := Map()
    CurrentProfile := ""

    if jsonObj.Has("showMenuIcon")
        ShowMenuIcon := jsonObj["showMenuIcon"]
    if jsonObj.Has("showSectorIcon")
        ShowSectorIcon := jsonObj["showSectorIcon"]

    ; --- 读取外观配置 ---
    if jsonObj.Has("appearance") {
        app := jsonObj["appearance"]
        if (Type(app) = "Map") {
            if app.Has("windowSize")
                App_WindowSize := Integer(app["windowSize"])
            if app.Has("outerRadius")
                App_OuterRadius := Integer(app["outerRadius"])
            if app.Has("penColor") {
                c := app["penColor"]
                App_PenColor := (Type(c) = "Integer") ? c : HexToColor(c)
            }
            if app.Has("penWidth")
                App_PenWidth := Integer(app["penWidth"])
            if app.Has("bgColor") {
                c := app["bgColor"]
                App_BgColor := (Type(c) = "Integer") ? c : HexToColor(c)
            }
            if app.Has("textColor") {
                c := app["textColor"]
                App_TextColor := (Type(c) = "Integer") ? c : HexToColor(c)
            }
            if app.Has("fontSize")
                App_FontSize := Integer(app["fontSize"])
            if app.Has("fontWeight")
                App_FontWeight := Integer(app["fontWeight"])
            if app.Has("escapeRadius")
                App_EscapeRadius := Integer(app["escapeRadius"])
            if app.Has("background") {
                bg := app["background"]
                if (Type(bg) = "String")
                    App_Background := bg
            }
            if app.Has("backgroundAlpha")
                App_BackgroundAlpha := Integer(app["backgroundAlpha"])
            if app.Has("highlightColor") {
                c := app["highlightColor"]
                App_HighlightColor := (Type(c) = "Integer") ? c : HexToColor(c)
            }
            if app.Has("highlightAlpha")
                App_HighlightAlpha := Integer(app["highlightAlpha"])
        }
    }

    ; 加载默认扇区配置 (扁平格式，向后兼容)
    DefaultConfig := LoadSectorsFromObj(jsonObj)

    ; 加载 Profile 系统
    if jsonObj.Has("profiles") {
        profilesArr := jsonObj["profiles"]
        if (Type(profilesArr) = "Array") {
            for profileObj in profilesArr {
                if (Type(profileObj) != "Map")
                    continue
                if !profileObj.Has("name")
                    continue
                profileName := profileObj["name"]
                profileData := Map()
                profileData["ahkHandles"] := profileObj.Has("ahkHandles") ? profileObj["ahkHandles"] : ""
                if profileObj.Has("sectors") && Type(profileObj["sectors"]) = "Map" {
                    profileData["sectors"] := LoadSectorsFromObj(profileObj["sectors"])
                } else {
                    profileData["sectors"] := Map()
                }
                Profiles[profileName] := profileData
            }
        }
    }

    ; 默认使用 DefaultConfig（只读引用，避免深拷贝）
    ActionConfig := DefaultConfig
    TotalSectors := MapCount(ActionConfig)

    if (TotalSectors = 0 && MapCount(Profiles) = 0)
        return FailLoad("未找到任何扇区定义（请在配置文件中添加数字键或 profiles）")
    ; 初始化配置文件的最后修改时间，避免首次检测时误触发重载
    LastConfigModTime := FileGetTime(jsonFile, "M")
}

; ---------- 配置解析与渲染辅助函数 ----------
; ============================================================
; 扇区起始角 规则：1号扇区中心 = 12点方向,后续扇区顺时针排列
; 屏幕坐标系：
;   0°   = 3点方向（右）
;   90°  = 6点方向（下）
;   180° = 9点方向（左）
;   270° = 12点方向（上）
; 因此：  12点 = -90°  startAngle 是“第一个扇区的边界”， 再减半个 step 后，第一个扇区的中心刚好落在 12 点。
GetClockStartAngle(sectorCount) {
    if (sectorCount <= 0)
        return 0
    step := 6.283185307179586 / sectorCount
    return (-90.0 * 3.141592653589793 / 180.0) - step / 2
}

; 计算 Map 中的键数量 (AHK v2 Map 无 .Count() 方法)
MapCount(m) {
    count := 0
    for key in m
        count++
    return count
}

; 从 Map 对象中加载扇区配置 (支持扁平格式: {"1": {...}, "2": {...}})
LoadSectorsFromObj(obj) {
    sectors := Map()
    if (Type(obj) != "Map")
        return sectors

    maxKeyNum := 0
    for key in obj {
        if RegExMatch(key, "^\d+$") {
            num := Integer(key)
            if (num > maxKeyNum)
                maxKeyNum := num
        }
    }

    num := 1
    while (num <= maxKeyNum) {
        sec := String(num)
        if !obj.Has(sec) {
            num++
            continue
        }
        secData := obj[sec]
        if !(Type(secData) = "Map") {
            num++
            continue
        }

        cfg := Map()
        cfg["Name"] := secData.Has("name") ? secData["name"] : sec
        cfg["Type"] := secData.Has("type") ? secData["type"] : ""
        cfg["Icon"] := secData.Has("icon") ? secData["icon"] : ""

        if (cfg["Type"] = "run") {
            cfg["Target"] := secData.Has("target") ? secData["target"] : ""
        } else if (cfg["Type"] = "menu") {
            items := secData.Has("items") ? secData["items"] : []
            cfg["Items"] := []
            for it in items {
                if it.Has("text") && it.Has("cmd") {
                    entry_item := Map()
                    entry_item["text"] := it["text"]
                    entry_item["cmd"] := it["cmd"]
                    entry_item["icon"] := it.Has("icon") ? it["icon"] : ""
                    cfg["Items"].Push(entry_item)
                }
            }
            if secData.Has("sub")
                cfg["Sub"] := secData["sub"]
        } else if (cfg["Type"] = "function") {
            cfg["Function"] := secData.Has("function") ? secData["function"] : ""
        }
        sectors[sec] := cfg
        num++
    }
    return sectors
}

; 深拷贝扇区配置 Map
CloneConfig(src) {
    dst := Map()
    if (Type(src) != "Map")
        return dst
    for key, val in src {
        if (Type(val) = "Map") {
            dst[key] := CloneConfig(val)
        } else if (Type(val) = "Array") {
            newArr := []
            for item in val {
                if (Type(item) = "Map")
                    newArr.Push(CloneConfig(item))
                else
                    newArr.Push(item)
            }
            dst[key] := newArr
        } else {
            dst[key] := val
        }
    }
    return dst
}

; 检查窗口 hwnd 是否匹配 ahkHandles 字符串
; 支持: ahk_exe xxx.exe, ahk_class ClassName, 多个条件用 | 分隔 (OR)
; 不区分大小写匹配
MatchAhkHandle(hwnd, ahkHandles) {
    if (ahkHandles = "")
        return false

    criteria := StrSplit(ahkHandles, "|")
    for crit in criteria {
        crit := Trim(crit)
        if (crit = "")
            continue
        if RegExMatch(crit, "^ahk_exe\s+(.+)$", &m) {
            targetExe := m[1]
            try {
                pid := WinGetPID("ahk_id " hwnd)
            } catch {
                continue
            }
            if (pid = 0)
                continue
            try {
                ; ProcessGetName 返回完整路径，提取文件名
                procPath := ProcessGetName(pid)
                procName := SubStr(procPath, InStr(procPath, "\", , 0) + 1)
                if (StrCompare(procName, targetExe, 1) = 0)
                    return true
            }
        } else if (RegExMatch(crit, "^ahk_class\s+(.+)$", &m)) {
            targetClass := m[1]
            try {
                cls := WinGetClass("ahk_id " hwnd)
            } catch {
                continue
            }
            if (StrCompare(cls, targetClass, 1) = 0)
                return true
        }
    }
    return false
}

; 根据当前活跃窗口切换 Profile
; ActionConfig 只读使用，因此直接引用配置 Map，避免每次切换深拷贝整棵树。
GetCurrentProfileSectors() {
    global DefaultConfig, Profiles, CurrentProfile, ActionConfig, TotalSectors
    try {
        hwnd := WinGetID("A")
    } catch {
        ActionConfig := DefaultConfig
        TotalSectors := MapCount(ActionConfig)
        CurrentProfile := ""
        return
    }
    if (hwnd = 0) {
        ActionConfig := DefaultConfig
        TotalSectors := MapCount(ActionConfig)
        CurrentProfile := ""
        return
    }
    matched := false
    for profileName, profileData in Profiles {
        ahkHandles := profileData["ahkHandles"]
        if (MatchAhkHandle(hwnd, ahkHandles)) {
            ActionConfig := profileData["sectors"]
            TotalSectors := MapCount(ActionConfig)
            CurrentProfile := profileName
            matched := true
            break
        }
    }
    if !matched {
        ActionConfig := DefaultConfig
        TotalSectors := MapCount(ActionConfig)
        CurrentProfile := ""
    }
}

; 按名称强制切换 Profile（手动切换）
SwitchProfileByName(profileName, *) {
    global DefaultConfig, Profiles, CurrentProfile, ActionConfig, TotalSectors
    if (profileName = "" || profileName = "默认") {
        ActionConfig := DefaultConfig
        TotalSectors := MapCount(ActionConfig)
        CurrentProfile := ""
    } else if Profiles.Has(profileName) {
        ActionConfig := Profiles[profileName]["sectors"]
        TotalSectors := MapCount(ActionConfig)
        CurrentProfile := profileName
    } else {
        return false
    }
    try RefreshMenuVisuals(false, true)
    UpdateTrayStatus()
    return true
}

; 将十六进制颜色字符串 (如 "FFFFFF" 或 "0xFFFFFF") 转换为整数
HexToColor(hexStr) {
    if (Type(hexStr) != "String")
        return hexStr
    s := hexStr
    if (SubStr(s, 1, 2) = "0x" || SubStr(s, 1, 2) = "0X")
        s := SubStr(s, 3)
    ; 返回 RGB 格式 (RRGGBB)，用于 GDI+ 的 RGBToARGB 转换
    ; GDI+ 使用 ARGB 格式，RGBToARGB 将 RGB 转为 ARGB
    r := Integer("0x" SubStr(s, 1, 2))
    g := Integer("0x" SubStr(s, 3, 2))
    b := Integer("0x" SubStr(s, 5, 2))
    return r << 16 | g << 8 | b  ; RGB 格式 (RRGGBB)
}

MenuRun(cmd) {
    ; 返回一个闭包，执行时自动包裹 try-catch，完美处理任何错误
    return RunWithErrorHandling.Bind(cmd)
}

; 带错误处理的运行包装器：执行 RunUserCommand(cmd)，失败时弹出错误提示
RunWithErrorHandling(cmd, *) {
    try {
        RunUserCommand(cmd)
    } catch as e {
        MsgBox("运行失败：`n" . cmd . "`n`n" . e.Message, "错误", "Icon!")
    }
}

; 执行用户自定义命令：自动为含空格的程序/脚本路径加引号，避免 Run 按空格截断。
; 覆盖两类情况：
;   1. 目标本身即文件：  F:\软件\...\脚本.ahk
;   2. 程序 + 脚本参数： AutoHotkey.exe F:\软件\...\脚本.ahk
RunUserCommand(cmd) {
    cmd := Trim(cmd)
    if (cmd = "")
        return

    ; 1. 整个命令本身就是一个已存在的文件/文件夹 → 直接加引号
    if FileExist(cmd) {
        Run('"' . cmd . '"')
        return
    }

    prog := ""
    args := ""

    ; 2. 提取程序路径与参数字符串
    if (SubStr(cmd, 1, 1) = '"') {
        ; 引号包裹的程序路径，如 "C:\My App\app.exe" arg1
        p := InStr(cmd, '"', , 2)
        if (p >= 2) {
            prog := SubStr(cmd, 2, p - 2)
            args := Trim(SubStr(cmd, p + 1))
        }
    } else {
        ; 先尝试：程序本身是含空格的文件 + 参数（从右往左找存在的文件）
        test := cmd
        loop {
            if FileExist(test) {
                prog := test
                args := Trim(SubStr(cmd, StrLen(test) + 1))
                break
            }
            p := InStr(test, " ", , -1)
            if (p <= 0)
                break
            test := RTrim(SubStr(test, 1, p - 1))
        }
        ; 兜底：第一个空格前为程序名，其余为参数
        if (prog = "") {
            p := InStr(cmd, " ")
            if (p > 1) {
                prog := SubStr(cmd, 1, p - 1)
                args := Trim(SubStr(cmd, p + 1))
            } else {
                prog := cmd
                args := ""
            }
        }
    }

    if (prog = "") {
        Run(cmd)
        return
    }

    ; 3. 程序是真实文件/文件夹 → 加引号；裸命令/URL 保持原样
    progPart := FileExist(prog) ? ('"' . prog . '"') : prog

    ; 4. 参数字符串整体是真实文件（含空格的脚本/文档路径）→ 给参数加引号
    ;    例：AutoHotkey.exe F:\软件\...\脚本.ahk
    if (args != "" && FileExist(args)) {
        Run(progPart . ' "' . args . '"')
        return
    }

    if (args != "")
        Run(progPart . ' ' . args)
    else
        Run(progPart)
}

ExpandEnvVars(str) {
    while RegExMatch(str, "%(\w+)%", &m) {
        envValue := EnvGet(m[1])
        unused := 0
        str := StrReplace(str, m[0], envValue, , &unused, 1)
    }
    return str
}

; ===== END INCLUDE Core/Config.ahk =====

; ===== BEGIN INCLUDE Tray/TrayMenu.ahk =====

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

    tray.Add("刷新(异常时使用)`tWin+Alt+F5", ForceRefreshTRunner)
    try tray.SetIcon("刷新(异常时使用)`tWin+Alt+F5", "shell32.dll", 239)

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
    ShowAppNotify(AppName, A_IsSuspended ? "脚本已暂停，热键暂时无效" : "脚本已恢复", "info")
}

; ============================================================
; 应用内通知：不依赖系统 Toast（ToastEnabled=0 时 TrayTip 不可见）
; ============================================================
ShowAppNotify(title, text, kind := "info", ms := 2800) {
    try TrayTip(text, title, "Iconi")
    try ToolTip(title "`n`n" text)
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
    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "TRunnerNotify")
    g.SetFont("s10", "微软雅黑")
    g.BackColor := (kind = "error") ? "8B1E1E" : (kind = "ok" ? "1F6F4A" : "2B2B2B")
    g.AddText("x14 y10 w320 cWhite", title)
    g.SetFont("s9", "微软雅黑")
    g.AddText("x14 y36 w320 r4 cWhite", text)
    w := 348, h := 120
    sx := A_ScreenWidth - w - 16
    sy := A_ScreenHeight - h - 56
    g.Show("x" sx " y" sy " w" w " h" h " NoActivate")
    AppToastGui := g
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
    statusText := AppName " " AppVersion " (" AppEnglishName ")`n"
        . "基于 AutoHotkey v2.0+ 的`n"
        . "圆形快速启动工具"

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
;  当前方案：用户启动文件夹（A_Startup\TRunner.lnk）
;  旧方案：注册表 HKCU\...\Run（已注释保留，暂不删除代码）
; ============================================================

; --- 旧方案：注册表 HKCU Run（已注释，不再使用）---
; StartupRegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
; StartupRegName := "TRunner"
;
; IsStartupEnabled() {
;     global StartupRegKey, StartupRegName
;     try {
;         val := RegRead(StartupRegKey, StartupRegName)
;         return (val != "")
;     } catch {
;         return false
;     }
; }
;
; ToggleStartup(*) {
;     global StartupRegKey, StartupRegName
;     scriptPath := A_ScriptFullPath
;     enabled := IsStartupEnabled()
;     if enabled {
;         try RegDelete(StartupRegKey, StartupRegName)
;         catch as e {
;             ReportStartupStatus("开机启动", "取消失败：" e.Message, "error")
;             return
;         }
;         ReportStartupStatus("开机启动", "已取消开机启动。", "ok")
;     } else {
;         try RegWrite(scriptPath, "REG_SZ", StartupRegKey, StartupRegName)
;         catch as e {
;             ReportStartupStatus("开机启动", "设置失败：" e.Message, "error")
;             return
;         }
;         ReportStartupStatus("开机启动", "已启用开机启动。", "ok")
;     }
;     try UpdateTrayStatus()
; }

; --- 新方案：启动文件夹快捷方式 ---
GetStartupShortcutPath() {
    return A_Startup "\TRunner.lnk"
}

IsStartupEnabled() {
    try {
        return FileExist(GetStartupShortcutPath()) ? true : false
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

ReportStartupStatus(title, detail, kind := "info") {
    ShowAppNotify(title, detail, kind, 3500)
    try UpdateTrayStatus()
    UpdateStartupMenuCheck()
}

ToggleStartup(*) {
    lns := GetStartupShortcutPath()
    scriptPath := A_ScriptFullPath
    workDir := A_ScriptDir
    enabled := IsStartupEnabled()

    if enabled {
        try {
            FileDelete(lns)
        } catch as e {
            ReportStartupStatus("开机启动", "取消失败：" e.Message "`n" lns, "error")
            return
        }
        if FileExist(lns) {
            ReportStartupStatus("开机启动", "取消失败：快捷方式仍存在`n" lns, "error")
            return
        }
        ReportStartupStatus("开机启动", "已取消开机启动。`n已删除启动文件夹快捷方式。", "ok")
    } else {
        try {
            if A_IsCompiled
                FileCreateShortcut(scriptPath, lns, workDir)
            else
                FileCreateShortcut(A_AhkPath, lns, workDir, '"' scriptPath '"')
        } catch as e {
            ReportStartupStatus("开机启动", "设置失败：" e.Message, "error")
            return
        }
        if !FileExist(lns) {
            ReportStartupStatus("开机启动", "设置失败：快捷方式未创建`n" lns, "error")
            return
        }
        detail := "已启用开机启动（启动文件夹）。`n快捷方式：" lns
        if !A_IsCompiled
            detail .= "`n解释器：" A_AhkPath "`n脚本：" scriptPath
        ReportStartupStatus("开机启动", detail, "ok")
    }

    try UpdateTrayStatus()
}

; ===== END INCLUDE Tray/TrayMenu.ahk =====

; ===== BEGIN INCLUDE Core/HelpAbout.ahk =====

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
    text .= AppName " " AppVersion " (" AppEnglishName ") — 圆形快速启动器`n"
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
    text .= AppName " " AppVersion " — AutoHotkey v" A_AhkVersion " 兼容版`n"

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
    text .= "开发者：" AppAuthor "`n"
    text .= "版权：" AppCopyright "`n"
    text .= "源代码：" AppSourceUrl "`n"
    text .= "运行环境：AutoHotkey v" A_AhkVersion " ｜ " A_OSVersion "（" (A_PtrSize * 8) " 位）`n"
    text .= "功能简介：右键拖动弹出圆形快速启动菜单；支持 run / menu / function 三种扇区类型与 Profile 自动切换。`n`n"
    text .= "【版本记录】`n"
    text .= "V0.27.0（" AppUpdateDate "）`n"
    text .= "  · 审查并完善 0.26.1 右键转发 / 四层穿透 / Reload 销毁视觉层方案。`n"
    text .= "  · Reset 补全 GuideGui 全局声明；菜单打开分支改用成对 Click 转发。`n"
    text .= "  · 同步更新模块化 TRunner\\ 源码。`n`n"
    text .= "V0.26.1（" AppUpdateDate "）`n"
    text .= "  · 完善为实际多文件模块化结构：Core / Features / Editor，统一由 Main.ahk 作为入口。`n"
    text .= "  · 保留同版单文件 TRunnerV0.26.1.ahk（tools/build_single.py 生成）。`n"
    text .= "  · 修复启动/重载阶段右键 Down/Up 不成对导致的输入状态异常。`n"
    text .= "  · 四层 AlwaysOnTop 视觉窗口统一 HTTRANSPARENT，修复任务栏/其它窗口偶发鼠标点击无效。`n"
    text .= "  · Reload 前主动释放输入并销毁旧视觉层，降低多次重载后右键才恢复的问题。`n`n"
    text .= "V0.25.9（2026-09-15）`n"
    text .= "  · 精简右键状态机：去掉 #UseHook/Sleep/热键重装等干扰逻辑。`n"
    text .= "  · 启动未完成时右键交还系统，不再吞掉系统右键菜单。`n`n"
    text .= "V0.25.8（2026-09-15）`n"
    text .= "  · 修复启动/重载后右键拖动偶发无效（常需重载 2~3 次）：等待旧钩子释放、视觉层多次重试、强制重装右键热键、#UseHook。`n`n"
    text .= "V0.25.7（2026-09-15）`n"
    text .= "  · 修正弹出菜单位置：改回在松开右键的屏幕坐标处显示（不再用扇区中点）。`n`n"
    text .= "V0.25.6（2026-09-15）`n"
    text .= "  · 修复配置编辑器多层子菜单（如 DouK）显示为空：嵌套子菜单统一存在扇区 sub 扁平 Map。`n"
    text .= "  · 点击扇区弹出的菜单改为显示在扇区中点，减少位置偏差。`n"
    text .= "  · 圆形菜单四层窗口全部点击穿透，避免挡住任务栏等其它程序。`n`n"
    text .= "V0.25.5（2026-09-14）`n"
    text .= "  · 修复只看到辅助线/高亮、看不到圆形主窗：弹出后不再异步 Refresh 导致主层被 Hide；Refresh 时若菜单已显示会重新 Show。`n`n"
    text .= "V0.25.4（2026-09-14）`n"
    text .= "  · 修复右键拖动完全不弹出：恢复启动时先建视觉层再放开右键，并增加拖动时强制重建兜底。`n`n"
    text .= "V0.25.3（2026-09-14）`n"
    text .= "  · 修复启动后右键拖动要等很久才弹出：GUI/图标构建改为启动后异步执行，不再阻塞热键。`n"
    text .= "  · 圆形菜单先显示再刷新 Profile；图标提取失败不再拖死绘制。`n`n"
    text .= "V0.25.2（2026-09-14）`n"
    text .= "  · 程序搜索改为真正 Listary 式：默认仅输入框，有关键字才展开结果列表。`n"
    text .= "  · 修复右键拖动不弹出圆形菜单：去掉全局 #32768 拦截，拖动采样恢复 30ms，启动更早放开右键。`n`n"
    text .= "V0.25.1（2026-09-14）`n"
    text .= "  · 程序列表改为 Listary 风格：仅搜索框+结果列表，居中弹出；↑↓ 选择、Enter 启动、F5 刷新。`n"
    text .= "  · 函数下拉框显示「函数名（中文名）」，便于排序与辨认。`n"
    text .= "  · 托盘 Profile 菜单固定在「暂停鼠标监控」之后，刷新状态不再挪到末尾。`n`n"
    text .= "V0.25.0（2026-09-14）`n"
    text .= "  · 性能：GDI+ 字体/画刷缓存；拖动采样间隔 30→50ms；Profile 切换改为引用不再深拷贝；扇区图标统一 IconManager。`n"
    text .= "  · 架构：LoadConfig 热重载失败保留旧配置；开机启动改 RegWrite/RegDelete，键名改为 TRunner；定时任务状态持久化；窗口单例辅助。`n"
    text .= "  · 移除 deskflow 屏幕切换看门狗及相关跳变检测（保留右键按下自愈复位）。`n"
    text .= "  · 新增：系统硬件信息、区域/活动窗口截图、剪贴板历史、窗口管理（居中/半屏/跨屏）、音量与媒体控制、Profile 托盘指示与手动切换。`n`n"
    text .= "V0.24.0（2026-09-14）`n"
    text .= "  · 关机子菜单新增「定时重启」「定时锁屏」，与定时关机共用自定义倒计时输入窗口。`n"
    text .= "  · 「取消定时关机」更名为「取消定时管理」，可一键取消关机/重启/锁屏任意待执行定时任务。`n`n"
    text .= "V0.23.9（2026-09-14）`n"
    text .= "  · 修复重复点击「关于」「帮助」菜单会弹出多个窗口的问题，现在全局仅保留一个实例。`n"
    text .= "  · 修复「关于」窗口中程序名称 TRunner 因控件高度不足被裁切（只显示上半部分）的问题。`n`n"
    text .= "V0.23.0（2026-09-07）`n"
    text .= "  · 修复 deskflow 双机共享键鼠场景下，鼠标再次进入客户端后右键拖动无法弹出圆形菜单的问题（右键按下自愈 + 屏幕切换看门狗 + 释放事件防误判三重防护）。`n"
    text .= "  · 定时关机改为用户自定义时间输入（小时 + 分钟），支持任意时长。`n"
    text .= "  · 热键调整：Win+T / Win+空格 打开程序列表窗口；Win+Alt+空格 弹出圆形窗口菜单。`n"
    text .= "  · 规范语义化版本号管理，补充完善代码注释，新增关于页面与 FAQ 帮助模块。`n`n"
    text .= "详细使用说明请点击【使用帮助】查看。"
    return text
}

; ============================================================

; ===== END INCLUDE Core/HelpAbout.ahk =====

; ===== BEGIN INCLUDE Core/MenuBuild.ahk =====

;  3.10 图标解析与菜单构建
; ============================================================


; ======== Core/MenuBuild.ahk ========
; Core — Menu build/exec
ParseIcon(iconStr) {
    iconStr := Trim(iconStr)
    if (iconStr = "")
        return ["", ""]
    iconStr := StrReplace(iconStr, ",", ":")
    if RegExMatch(iconStr, "^(.+):(\d+)$", &m) {
        file := m[1]
        idx := m[2]
        if !InStr(file, "\") && !InStr(file, "/")
            file := A_WinDir "\System32\" file
        else if !RegExMatch(file, "^[A-Za-z]:\\|^\\\\")
            file := A_ScriptDir "\" file
        return [file, idx]
    } else {
        if !InStr(iconStr, "\") && !InStr(iconStr, "/")
            iconStr := A_WinDir "\System32\" iconStr
        else if !RegExMatch(iconStr, "^[A-Za-z]:\\|^\\\\")
            iconStr := A_ScriptDir "\" iconStr
        return [iconStr, ""]
    }
}

SetMenuIconSafe(menuObj, itemText, iconStr) {
    iconInfo := ParseIcon(iconStr)
    if (iconInfo[1] = "" || !FileExist(iconInfo[1]))
        return
    try {
        if (iconInfo[2] != "")
            menuObj.SetIcon(itemText, iconInfo[1], Integer(iconInfo[2]))
        else
            menuObj.SetIcon(itemText, iconInfo[1])
    } catch {
        ; 图标加载失败（如 .msc 文件），忽略
    }
}

BuildMenuForSector(sectorName, items, parentMenu, subData := "") {
    global ShowMenuIcon
    for entry in items {
        text := entry.Has("text") ? entry["text"] : ""
        cmd := entry.Has("cmd") ? entry["cmd"] : ""
        icon := entry.Has("icon") ? entry["icon"] : ""
        ; 分隔线
        if (cmd = "---") {
            parentMenu.Add()
            continue
        }
        ; 1. 子菜单    cmd = >子菜单名称
        if (SubStr(cmd, 1, 1) = ">") {
            subMenuName := SubStr(cmd, 2)
            subItems := ""
            if (subData && subData.Has(subMenuName))
                subItems := subData[subMenuName]
            if !IsObject(subItems) {
                parentMenu.Add(text " (子菜单未定义)", (*) => MsgBox("子菜单「" subMenuName "」未配置。", AppName, "Icon!"))
                continue
            }
            converted := []
            for it in subItems {
                if !IsObject(it)
                    continue
                if !(it.Has("text") && it.Has("cmd"))
                    continue
                subEntry := Map()
                subEntry["text"] := it["text"]
                subEntry["cmd"] := it["cmd"]
                subEntry["icon"] := it.Has("icon") ? it["icon"] : ""
                converted.Push(subEntry)
            }
            subObj := Menu()
            ; 继续递归，因此可以支持：
            ; 工具及应用
            ;   └─ 内部函数
            ;       └─ 更多函数
            ;           └─ 函数
            BuildMenuForSector(sectorName, converted, subObj, subData)
            parentMenu.Add(text, subObj)
            if (ShowMenuIcon)
                SetMenuIconSafe(parentMenu, text, icon)
            continue
        }

        ; 2. 内部函数
        ; function:ShowHelp
        ; fn:ShowHelp       ← 同时兼容简写
        if RegExMatch(cmd, "i)^(?:function|fn):(.*)$", &fm) {
            funcName := Trim(fm[1])
            if (funcName = "") {
                parentMenu.Add(text " (函数为空)", (*) => MsgBox("菜单项「" text "」没有指定函数。", AppName, "Icon!"))
            } else {
                parentMenu.Add(text, RunFunction.Bind(funcName))
            }
            if (ShowMenuIcon)
                SetMenuIconSafe(parentMenu, text, icon)
            continue
        }
        ; 3. 普通 Run 命令
        expandedCmd := ExpandEnvVars(cmd)
        parentMenu.Add(text, MenuRun(expandedCmd))
        if (ShowMenuIcon)
            SetMenuIconSafe(parentMenu, text, icon)
    }
}

ExecuteSectorAction(sectorNum, showX := "", showY := "") {
    global ActionConfig
    if !ActionConfig.Has(sectorNum)
        return
    cfg := ActionConfig[sectorNum]
    if (cfg["Type"] = "function") {
        funcName := cfg["Function"]
        if (funcName != "") {
            try {
                ; 强制转为字符串，动态调用
                fn := String(funcName)
                %fn%()
            } catch as e {
                MsgBox("调用失败：" fn "`n" e.Message)
            }
        }
        return
    }
    if (cfg["Type"] = "run") {
        target := ExpandEnvVars(cfg["Target"])
        try
            RunUserCommand(target)
        catch as e
            MsgBox("运行失败：`n" target "`n`n" e.Message)
    } else if (cfg["Type"] = "menu") {
        local mnu := Menu()
        BuildMenuForSector(sectorNum, cfg["Items"], mnu, cfg.Has("Sub") ? cfg["Sub"] : "")
        ; showX/showY 为松开右键时的屏幕坐标；未传入时取当前鼠标位置
        if (showX = "" || showY = "")
            MouseGetPos(&mx, &my)
        else {
            mx := showX
            my := showY
        }
        ; Menu.Show() 阻塞期间标记 popupMenuOpen，
        ; 让右键热键完全放行，避免破坏系统菜单捕获导致“右键卡住”。
        global popupMenuOpen
        popupMenuOpen := true
        try mnu.Show(mx, my)
        finally popupMenuOpen := false
    }
}

; ===== END INCLUDE Core/MenuBuild.ahk =====

; ===== BEGIN INCLUDE CircleMenu/Render.ahk =====

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

; ===== END INCLUDE CircleMenu/Render.ahk =====

; ===== BEGIN INCLUDE CircleMenu/RightClick.ahk =====

; ======== Core/RightClick.ahk ========
; Core — Right-click state machine

; ---- 右键成对转发（启动/暂停阶段；Reload 前强制释放） ----
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

; ===== END INCLUDE CircleMenu/RightClick.ahk =====

; ===== BEGIN INCLUDE CircleMenu/Input.ahk =====

; ============================================================
;  3.12 右键交互状态机 (右键拖动 / 扇区高亮 / 方向检测 / 状态清理)
; ============================================================
; ========== 右键交互 ==========
; (全局变量已在脚本开头声明)

; 检测“可见”的标准菜单窗 (#32768)。
; 不要过度依赖 GetGUIThreadInfo：某些环境会误判导致 #HotIf 永远为假，
; 右键拖动热键被永久关掉。
IsStandardMenuOpen() {
    try {
        hwnd := 0
        loop {
            hwnd := DllCall("FindWindowEx", "Ptr", 0, "Ptr", hwnd, "WStr", "#32768", "Ptr", 0, "Ptr")
            if !hwnd
                break
            if DllCall("IsWindowVisible", "Ptr", hwnd)
                return true
        }
    }
    return false
}

; ============================================================
; 右键热键策略：Down/Up 必须严格成对
; ============================================================
; 规则：Up 只在「我们拦截过本次 Down」时才启用热键。
; 菜单打开时 Down 放行给 Windows；菜单关闭后 Up 也必须继续放行，
; 否则会变成“Windows 收到 Down、Up 被吃掉”→ 右键卡在按下（框选）。

; 1) 热键圆形菜单打开：吞掉 Down，标记 ateRightButtonDown（在 Reset 之后再标记）
#HotIf circleMenuOpen
RButton:: {
    global isForwardingRightButton, ateRightButtonDown
    if isForwardingRightButton
        return
    ResetMouseInteractionState(true)
    ateRightButtonDown := true
}
#HotIf

; 2) 拖动：仅当系统/脚本菜单都未打开时拦截 Down，并记录 ourRButtonDown
#HotIf StartupComplete && !MouseMonitorPaused && !circleMenuOpen && !popupMenuOpen && !IsStandardMenuOpen()
$RButton:: {
    global startMouseX, startMouseY
    global timerActive, hasDragged
    global menuWasOpen, isInteracting
    global rbuttonDown
    global isMenuVisible
    global lastPollX, lastPollY
    global rightButtonForwarded
    global isForwardingRightButton
    global ourRButtonDown

    if isForwardingRightButton
        return

    try SetTimer(CheckMouseMove, 0)
    timerActive := false
    rbuttonDown := false
    hasDragged := false
    isMenuVisible := false
    menuWasOpen := false
    isInteracting := true
    rightButtonForwarded := false
    ResetHighlightState()
    try HideAllLayeredMenus()

    ourRButtonDown := true
    rbuttonDown := true
    MouseGetPos(&startMouseX, &startMouseY)
    lastPollX := startMouseX
    lastPollY := startMouseY
    if !timerActive {
        SetTimer(CheckMouseMove, 30)
        timerActive := true
    }
}
#HotIf

; 3) Up：仅当我们拥有本次 Down（ourRButtonDown / ate / forwarded）时才拦截
#HotIf ourRButtonDown || ateRightButtonDown || rightButtonForwarded
$RButton Up:: {
    global isMenuVisible
    global hasDragged
    global timerActive
    global menuWasOpen
    global rbuttonDown
    global isInteracting
    global R3, R, App_EscapeRadius
    global RingRadiusArray, SectorsPerRing, SectorOffset
    global startMouseX, startMouseY
    global threshold
    global lastPollX, lastPollY
    global rightButtonForwarded
    global RuntimeBusy
    global isForwardingRightButton
    global ateRightButtonDown
    global ourRButtonDown

    if isForwardingRightButton
        return

    ; 转发过 Down：只补 Up
    if rightButtonForwarded {
        ForwardRightButtonUp()
        rightButtonForwarded := false
        ourRButtonDown := false
        ateRightButtonDown := false
        return
    }

    ; 吞过 Down（关闭圆形菜单）：只吞 Up，不做拖动逻辑
    if ateRightButtonDown {
        ateRightButtonDown := false
        ourRButtonDown := false
        return
    }

    if !ourRButtonDown
        return
    ourRButtonDown := false

    wasDown := rbuttonDown
    wasDragged := hasDragged
    wasMenuVisible := isMenuVisible

    ; 先停 Timer / 清 rbuttonDown，再执行可能阻塞的 Menu.Show()
    try SetTimer(CheckMouseMove, 0)
    timerActive := false
    rbuttonDown := false

    try {
        if !wasDown
            return

        ; 普通单击：未拖动 → 合成完整右键交给系统
        if !wasDragged {
            MouseGetPos(&_mx, &_my)
            still := Abs(_mx - startMouseX) <= threshold && Abs(_my - startMouseY) <= threshold
            if still
                ForwardRightButtonClick()
            return
        }

        ; 拖动了，但圆形菜单已被 ESC 等关闭
        if !wasMenuVisible
            return

        MouseGetPos(&mouseScrX, &mouseScrY)
        dx := mouseScrX - startMouseX
        dy := mouseScrY - startMouseY
        dist := Sqrt(dx * dx + dy * dy)

        try HideAllLayeredMenus()
        isMenuVisible := false

        if (dist <= R3 || dist > R + App_EscapeRadius)
            return

        targetRingCount := 0
        targetOffset := 0
        for ringIdx, ringRadius in RingRadiusArray {
            if (dist >= ringRadius.inner - 2 && dist <= ringRadius.outer + 2) {
                targetRingCount := SectorsPerRing[ringIdx]
                targetOffset := SectorOffset[ringIdx]
                break
            }
        }
        if (targetRingCount <= 0)
            return

        angle := ATan2(dy, dx)
        if (angle < 0)
            angle += 6.283185307179586
        angleStep := 6.283185307179586 / targetRingCount
        startAngle := GetClockStartAngle(targetRingCount)
        relativeAngle := angle - startAngle
        while (relativeAngle < 0)
            relativeAngle += 6.283185307179586
        while (relativeAngle >= 6.283185307179586)
            relativeAngle -= 6.283185307179586
        sectorIdx := Floor(relativeAngle / angleStep)
        if (sectorIdx < 0 || sectorIdx >= targetRingCount)
            sectorIdx := 0
        sectorNum := targetOffset + sectorIdx

        try {
            ExecuteSectorAction(String(sectorNum), mouseScrX, mouseScrY)
        } catch as e {
            MsgBox("执行扇区失败：`n扇区：" sectorNum "`n`n错误：" e.Message, AppName, "Icon!")
        }
    }
    finally {
        try SetTimer(CheckMouseMove, 0)
        timerActive := false
        rbuttonDown := false
        hasDragged := false
        isInteracting := false
        menuWasOpen := false
        try HideAllLayeredMenus()
        isMenuVisible := false
        RuntimeBusy := false
    }
}
#HotIf

; ============================================================
; 右键拖动监控
; 两种工作模式：
;   1. 右键拖动模式：rbuttonDown = true，按住右键拖动弹出/更新圆形菜单。
;   2. 热键模式（Win+Alt+空格）：circleMenuOpen = true，无需按住右键即可移动鼠标高亮扇区，左键执行。
CheckMouseMove() {
    global startMouseX, startMouseY
    global isMenuVisible, hasDragged, rbuttonDown
    global CX, CY
    global MyGui, ContentGui
    global threshold
    global MouseMonitorPaused
    global GuideGui
    global isInteracting
    global RingCount, SectorsPerRing, RingRadiusArray, SectorOffset
    global App_EscapeRadius, R, R3
    global HighlightedSector
    global circleMenuOpen
    global lastPollX, lastPollY
    global MenuVisualReady

    ; 暂停鼠标监控只作用于"右键拖动"，热键模式仍可正常使用。
    if (MouseMonitorPaused && !circleMenuOpen)
        return
    ; 右键未按下、热键菜单也未打开时，不处理任何鼠标移动。
    if (!rbuttonDown && !circleMenuOpen)
        return
    ; ---------- 确保视觉层 ----------
    if !IsObject(MyGui) {
        try BuildMenuGUI(true, true)
        if !IsObject(MyGui) {
            static warned := false
            if !warned {
                warned := true
                ShowAppNotify("TRunner", "圆形菜单视觉层不可用，右键拖动无法弹出。请用托盘「刷新」或重载。`n#HotIf: Startup=" StartupComplete " Paused=" MouseMonitorPaused " popup=" popupMenuOpen " menu=" IsStandardMenuOpen(), "error", 5000)
            }
            return
        }
    }

    ; 所有鼠标拖动处理放到 try 内。
    ; 如果 GDI+ / GUI / 位图任何一步发生异常，立即恢复到干净状态，而不是让状态机卡死。
    try {
        MouseGetPos(&curX, &curY)
        lastPollX := curX
        lastPollY := curY

        ; 判断是否超过拖动阈值（仅右键拖动模式需要）
        deltaX := curX - startMouseX
        deltaY := curY - startMouseY

        if (rbuttonDown && Abs(deltaX) <= threshold && Abs(deltaY) <= threshold) {
            return
        }

        ; 第一次超过阈值：先按当前窗口刷新 Profile，再显示（与历史行为一致）
        if !hasDragged {
            hasDragged := true
            try GetCurrentProfileSectors()
            ResetHighlightState()
            showX := startMouseX - CX
            showY := startMouseY - CY
            SetLayeredWindowPosition(showX, showY, true)
            isMenuVisible := true
        }

        ; 更新辅助线
        if IsObject(GuideGui) {
            RebuildGuideBitmap(deltaX, deltaY)
        }

        ; 计算当前鼠标指向的扇区，更新高亮 (V0.21)
        dx := curX - startMouseX
        dy := curY - startMouseY
        dist := Sqrt(dx * dx + dy * dy)
        if (dist <= R3 || dist > R + App_EscapeRadius) {
            ; 鼠标在中心区域或外部取消区域，清除高亮
            if (HighlightedSector != "") {
                HighlightedSector := ""
                UpdateHighlightLayer()
            }
        } else {
            ; 查找鼠标落在哪个环
            targetRingIdx := -1
            for ringIdx, ringRadius in RingRadiusArray {
                if (dist >= ringRadius.inner - 2 && dist <= ringRadius.outer + 2) {
                    targetRingIdx := ringIdx
                    break
                }
            }
            if (targetRingIdx >= 0) {
                sectorCount := SectorsPerRing[targetRingIdx]
                offset := SectorOffset[targetRingIdx]
                angle := ATan2(dy, dx)
                if (angle < 0)
                    angle += 6.283185307179586
                angleStep := 6.283185307179586 / sectorCount
                startAngle := GetClockStartAngle(sectorCount)
                relativeAngle := angle - startAngle
                while (relativeAngle < 0)
                    relativeAngle += 6.283185307179586
                while (relativeAngle >= 6.283185307179586)
                    relativeAngle -= 6.283185307179586
                sectorIdx := Floor(relativeAngle / angleStep)
                if (sectorIdx < 0 || sectorIdx >= sectorCount)
                    sectorIdx := 0
                newSector := String(offset + sectorIdx)
                if (newSector != HighlightedSector) {
                    HighlightedSector := newSector
                    UpdateHighlightLayer()
                }
            } else if (HighlightedSector != "") {
                HighlightedSector := ""
                UpdateHighlightLayer()
            }
        }
    }
    catch {
        ; 任何异常都不能留下 rbuttonDown=true 的死状态
        ResetMouseInteractionState(true)
    }
}

; ============================================================
;  3.13 热键与圆形菜单
;    Win+T / Win+空格      — 弹出"已安装程序列表"窗口
;    Win+Alt+空格          — 在鼠标位置弹出圆形窗口菜单（左键执行扇区）
;    ESC                   — 关闭圆形窗口菜单
; ============================================================


; ======== Core/Hotkeys.ahk ========
; Core — Hotkeys/circle
#t:: ShowInstalledApps()
#Space:: ShowInstalledApps()   ; Win+空格 与 Win+T 功能相同：弹出程序列表窗口
#!Space:: OpenCircleMenuFromHotkey()   ; Win+Alt+空格：弹出圆形窗口菜单
#!t:: ShowSettingsMenu()    ; Win+Alt+T：弹出设置菜单
#!F5:: ForceRefreshTRunner() ; Win+Alt+F5：刷新视觉层并修复点击状态
; ========== ESC 关闭圆形菜单 ==========
; #HotIf 仅在 isMenuVisible 为 true 时激活该热键，避免误触。
; 同时重置 hasDragged 和 rbuttonDown，防止释放右键时再次触发执行。
#HotIf isMenuVisible
Esc:: {
    ; ESC 的唯一职责： 关闭当前圆形菜单并彻底终止当前右键交互。
    ResetMouseInteractionState(true)
}
#HotIf

; ============================================================
; Win+Alt+空格：在当前鼠标位置弹出圆形窗口菜单（热键模式，V0.23.0）
; 使用说明：
;   - 圆心固定在按下热键时的鼠标位置。
;   - 之后移动鼠标即可高亮扇区（由 CheckMouseMove 的热键模式驱动，无需按住任何键）。
;   - 左键点击扇区执行动作；点击中心/圈外、按右键或 ESC 关闭菜单。
; ============================================================
OpenCircleMenuFromHotkey(*) {
    global StartupComplete
    global startMouseX, startMouseY
    global lastPollX, lastPollY
    global timerActive, hasDragged, isInteracting, menuWasOpen, rbuttonDown
    global circleMenuOpen, isMenuVisible
    global MyGui, GuideGui, CX, CY

    ; 启动未完成时不允许弹出，避免与初始化流程竞争。
    if !StartupComplete
        return
    ; 先彻底复位上一次交互（右键拖动或上一次热键菜单），再以干净状态开始。
    ResetMouseInteractionState(true)
    ; 按当前活跃窗口刷新 Profile 对应的扇区配置。
    GetCurrentProfileSectors()
    ; 确保视觉对象已构建（首次调用会构建四层分层窗口）。
    if !IsObject(MyGui) {
        if !BuildMenuGUI(true, true)
            return
    }
    MouseGetPos(&popX, &popY)
    startMouseX := popX
    startMouseY := popY
    lastPollX := popX
    lastPollY := popY

    ResetHighlightState()
    ; hasDragged 置 true 使 CheckMouseMove 跳过"首次超越阈值"分支，直接进入扇区高亮跟踪。
    hasDragged := true
    isInteracting := true
    rbuttonDown := false
    menuWasOpen := false
    circleMenuOpen := true
    isMenuVisible := true

    ; 以鼠标位置为圆心显示四层分层窗口。
    SetLayeredWindowPosition(popX - CX, popY - CY, true)
    ; 显示初始辅助线（指向圆心的小圆点），与右键拖动第一次弹出时的表现一致。
    if IsObject(GuideGui) {
        RebuildGuideBitmap(0, 0)
    }
    ; 启动鼠标跟踪定时器。
    if !timerActive {
        SetTimer(CheckMouseMove, 50)
        timerActive := true
    }
}

; 由鼠标相对圆心的偏移量 (dx, dy) 计算命中的扇区编号。
; 参数：dx, dy — 鼠标相对圆心的屏幕坐标偏移。
; 返回值：扇区编号字符串；若命中中心取消区或环形之外的区域，返回 ""（空字符串）。
; 计算逻辑与右键释放时的扇区判定完全一致（同一套角度/环带算法）。
GetSectorNumAtPoint(dx, dy) {
    global R3, R, App_EscapeRadius
    global RingRadiusArray, SectorsPerRing, SectorOffset

    dist := Sqrt(dx * dx + dy * dy)
    ; 中心取消区 / 圈外取消带：不执行任何动作
    if (dist <= R3 || dist > R + App_EscapeRadius)
        return ""
    for ringIdx, ringRadius in RingRadiusArray {
        if (dist >= ringRadius.inner - 2 && dist <= ringRadius.outer + 2) {
            angle := ATan2(dy, dx)
            if (angle < 0)
                angle += 6.283185307179586
            angleStep := 6.283185307179586 / SectorsPerRing[ringIdx]
            startAngle := GetClockStartAngle(SectorsPerRing[ringIdx])
            relativeAngle := angle - startAngle
            while (relativeAngle < 0)
                relativeAngle += 6.283185307179586
            while (relativeAngle >= 6.283185307179586)
                relativeAngle -= 6.283185307179586
            sectorIdx := Floor(relativeAngle / angleStep)
            if (sectorIdx < 0 || sectorIdx >= SectorsPerRing[ringIdx])
                sectorIdx := 0
            return String(SectorOffset[ringIdx] + sectorIdx)
        }
    }
    return ""
}

; 热键圆形菜单打开期间的鼠标点击处理（点击均被吞掉，不会误触被遮住的窗口）：
;   左键 — 点击扇区执行动作；点击中心/圈外关闭菜单。
; 额外要求 isMenuVisible：防止 circleMenuOpen 残留时误吞全系统左键。
#HotIf circleMenuOpen && isMenuVisible
LButton:: {
    global startMouseX, startMouseY

    MouseGetPos(&clickX, &clickY)
    sectorNum := GetSectorNumAtPoint(clickX - startMouseX, clickY - startMouseY)
    ; 先关闭菜单（同时清理高亮/辅助线），再执行动作，避免圆窗遮挡动作弹出的新窗口。
    ResetMouseInteractionState(true)
    if (sectorNum = "")
        return
    try {
        ExecuteSectorAction(String(sectorNum))
    } catch as e {
        MsgBox("执行扇区失败：`n扇区：" sectorNum "`n`n错误：" e.Message, AppName, "Icon!")
    }
}
#HotIf

; 动态调用 当前 TRunner 单文件脚本 中的函数（供菜单回调使用）
RunFunction(funcName, *) {
    if (funcName = "")
        return
    try {
        fn := String(funcName)
        %fn%()
    } catch as e {
        MsgBox("调用失败：" fn "`n" e.Message)
    }
}

ShowSettingsMenu() {
    global ActionConfig

    ; 根据当前活跃窗口刷新 Profile 对应的扇区配置
    ; 如果不想自动切换 Profile，可删除下面一行，使用默认扇区
    GetCurrentProfileSectors()

    mnu := Menu()

    ; 取出所有扇区编号（数字键），并按数字升序排序
    keys := []
    for key in ActionConfig
        keys.Push(key)

    ; 插入排序（数字从小到大）
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
        displayName := cfg.Has("Name") ? cfg["Name"] : key
        iconStr := cfg.Has("Icon") ? cfg["Icon"] : ""

        if (cfg["Type"] = "run") {
            target := ExpandEnvVars(cfg["Target"])
            mnu.Add(displayName, MenuRun(target))
        }
        else if (cfg["Type"] = "function") {
            funcName := cfg["Function"]
            if (funcName = "ShowTrayMenu") {
                ; 特殊处理：直接挂载系统托盘菜单
                mnu.Add(displayName, A_TrayMenu)
            } else {
                mnu.Add(displayName, RunFunction.Bind(funcName))
            }
        }
        else if (cfg["Type"] = "menu") {
            subMenu := Menu()
            subData := cfg.Has("Sub") ? cfg["Sub"] : ""
            BuildMenuForSector(key, cfg["Items"], subMenu, subData)
            mnu.Add(displayName, subMenu)
        }

        if (iconStr != "")
            SetMenuIconSafe(mnu, displayName, iconStr)
    }
    ; 在鼠标当前位置弹出菜单
    global popupMenuOpen
    popupMenuOpen := true
    try mnu.Show()
    finally popupMenuOpen := false
}

; ============================================================
; 定时电源任务（关机 / 重启 / 锁屏）(V0.24.0)
; 统一状态机：同一时刻只保留一个待执行的定时任务。
;   - 关机 / 重启：交由系统命令 shutdown /s|/r /t 实现，
;     通过 shutdown /a 中止。
;   - 锁屏：脚本内 SetTimer 轮询截止时间，到点调用 LockWorkStation。
;   - 取消：同时清理上述两者。
; ============================================================
PowerTaskType := ""       ; "" | "shutdown" | "restart" | "lock"
PowerTaskDeadline := 0    ; 锁屏任务的 A_TickCount 截止时刻
PowerTaskDisplay := ""    ; 友好时长文案

; 将 小时/分钟 转换为友好的中文时长文字。
; 例：FormatShutdownDuration(6, 30) 返回 "6小时30分"；
;     FormatShutdownDuration(0, 45) 返回 "45分钟"；
;     FormatShutdownDuration(2, 0)  返回 "2小时"。
FormatShutdownDuration(hours, minutes) {
    parts := []
    if (hours > 0)
        parts.Push(hours . "小时")
    if (minutes > 0)
        parts.Push(minutes . "分")
    if (parts.Length = 0)
        return "0分钟"
    result := ""
    for i, part in parts
        result .= part
    return result
}

GetPowerTaskLabel(action) {
    switch action {
        case "shutdown": return "定时关机"
        case "restart": return "定时重启"
        case "lock": return "定时锁屏"
        default: return "定时任务"
    }
}

; ============================================================
; 共用倒计时输入窗口：按 action 区分关机 / 重启 / 锁屏

; ===== END INCLUDE CircleMenu/Input.ahk =====

; ===== BEGIN INCLUDE Features/PowerTasks/PowerTasks.ahk =====

; ============================================================


; ======== Features/PowerTasks.ahk ========
; Features — Power tasks
ShowSchedulePowerInput(action) {
    title := GetPowerTaskLabel(action)
    shutGui := Gui("+AlwaysOnTop -MinimizeBox", title)
    shutGui.SetFont("s10", "微软雅黑")

    shutGui.Add("Text", "x20 y20 w280", "请设置" . (action = "lock" ? "锁屏" : (action = "restart" ? "重启" : "关机")) . "倒计时：")

    shutGui.Add("Text", "x20 y72 w38 Right", "小时")
    hourEdit := shutGui.Add("Edit", "x66 y68 w70 Number Limit4")
    shutGui.Add("Text", "x150 y72 w38 Right", "分钟")
    minuteEdit := shutGui.Add("Edit", "x196 y68 w70 Number Limit3")

    shutGui.Add("Text", "x20 y114 w280", "示例：6小时30分 → 小时填 6，分钟填 30。`n留空的输入框按 0 处理。")

    okBtn := shutGui.Add("Button", "x20 y182 w90 Default", "确定")
    cancelBtn := shutGui.Add("Button", "x122 y182 w90", "取消")

    okBtn.OnEvent("Click", (*) => DoApplySchedulePower(action, shutGui, hourEdit, minuteEdit))
    cancelBtn.OnEvent("Click", (*) => shutGui.Destroy())
    shutGui.OnEvent("Close", (*) => shutGui.Destroy())
    shutGui.OnEvent("Escape", (*) => shutGui.Destroy())

    shutGui.Show()
}

ScheduleShutdownInput(*) {
    ShowSchedulePowerInput("shutdown")
}

ScheduleRestartInput(*) {
    ShowSchedulePowerInput("restart")
}

ScheduleLockInput(*) {
    ShowSchedulePowerInput("lock")
}

; 校验输入并执行对应类型的定时任务。
DoApplySchedulePower(action, gui, hourEdit, minuteEdit) {
    hours := (hourEdit.Value != "") ? Integer(hourEdit.Value) : 0
    minutes := (minuteEdit.Value != "") ? Integer(minuteEdit.Value) : 0

    totalSeconds := hours * 3600 + minutes * 60
    if (totalSeconds <= 0) {
        MsgBox("请输入有效的倒计时。`n`n小时和分钟不能同时为 0（或留空）。", AppName, "Icon!")
        return
    }
    ; 系统 shutdown 命令的 /t 参数上限为 10 年（315360000 秒）；锁屏同样限制。
    if (totalSeconds > 315360000) {
        MsgBox("倒计时过长。`n`n最长支持 10 年（87600 小时）。", AppName, "Icon!")
        return
    }
    gui.Destroy()
    SchedulePowerAction(action, totalSeconds, FormatShutdownDuration(hours, minutes))
}

; 设置新的定时任务前，先清掉已有任务（系统关机/重启 + 脚本锁屏定时器）。
SchedulePowerAction(action, seconds, displayText) {
    global PowerTaskType, PowerTaskDeadline, PowerTaskDisplay

    ClearPowerTaskState(true)

    label := GetPowerTaskLabel(action)
    try {
        if (action = "lock") {
            PowerTaskType := "lock"
            PowerTaskDeadline := A_TickCount + (seconds * 1000)
            PowerTaskDisplay := displayText
            SetTimer(CheckPowerLockDeadline, 1000)
            MsgBox(label . "已设置。`n`n将在 " . displayText . " 后自动锁屏。`n`n如需取消，请选择托盘菜单：`n关机 → 取消定时管理。", AppName, "Iconi")
            return
        }

        switchFlag := (action = "restart") ? "/r" : "/s"
        exitCode := RunWait(A_ComSpec ' /c shutdown ' switchFlag ' /t ' seconds, , "Hide")
        if (exitCode != 0) {
            MsgBox("设置" . label . "失败。`n`n系统返回代码：" exitCode, AppName, "IconX")
            return
        }
        PowerTaskType := action
        PowerTaskDisplay := displayText
        SavePowerTaskState()
        MsgBox(label . "已设置。`n`n将在 " . displayText . " 后自动" . (action = "restart" ? "重启" : "关机") . "。`n`n如需取消，请选择托盘菜单：`n关机 → 取消定时管理。", AppName, "Iconi")
    } catch as e {
        PowerTaskType := ""
        PowerTaskDeadline := 0
        PowerTaskDisplay := ""
        MsgBox("设置" . label . "失败。`n`n" . e.Message, AppName, "IconX")
    }
}

; 锁屏截止时间检查（由 SetTimer 每秒触发）。
CheckPowerLockDeadline() {
    global PowerTaskType, PowerTaskDeadline
    if (PowerTaskType != "lock")
        return
    if (A_TickCount >= PowerTaskDeadline) {
        SetTimer(CheckPowerLockDeadline, 0)
        PowerTaskType := ""
        PowerTaskDeadline := 0
        try DllCall("LockWorkStation")
    }
}

; 清理当前定时任务状态。
; abortSystem = true 时额外调用 shutdown /a 中止系统待执行的关机/重启。
ClearPowerTaskState(abortSystem := false) {
    global PowerTaskType, PowerTaskDeadline, PowerTaskDisplay

    if (PowerTaskType = "lock")
        SetTimer(CheckPowerLockDeadline, 0)

    if (abortSystem) {
        try RunWait(A_ComSpec " /c shutdown /a", , "Hide")
    }

    PowerTaskType := ""
    PowerTaskDeadline := 0
    PowerTaskDisplay := ""
    SavePowerTaskState()
}

PowerTaskStateFile() {
    return A_ScriptDir "\TRunner\PowerTask.json"
}

SavePowerTaskState() {
    global PowerTaskType, PowerTaskDeadline, PowerTaskDisplay
    try {
        path := PowerTaskStateFile()
        SplitPath(path, , &dir)
        if !DirExist(dir)
            DirCreate(dir)
        data := Map(
            "type", PowerTaskType,
            "deadline", PowerTaskDeadline,
            "display", PowerTaskDisplay,
            "tick", A_TickCount,
            "savedAt", A_Now
        )
        FileOpen(path, "w", "UTF-8").Write(Json.Stringify(data))
    }
}

LoadPowerTaskState() {
    global PowerTaskType, PowerTaskDeadline, PowerTaskDisplay
    path := PowerTaskStateFile()
    if !FileExist(path)
        return
    try {
        data := Json.Parse(FileRead(path, "UTF-8"))
        t := data.Has("type") ? data["type"] : ""
        if (t = "" || t = "lock")
            return
        ; 系统关机/重启任务在脚本重载后仍然存在；恢复展示状态。
        PowerTaskType := t
        PowerTaskDisplay := data.Has("display") ? data["display"] : ""
        PowerTaskDeadline := 0
        TrayTip(AppName, "检测到系统中仍有待执行的" . GetPowerTaskLabel(t) . "任务", "Icon!")
    }
}

; 取消定时管理：一键中止系统关机/重启任务，并清除脚本锁屏定时器。
CancelScheduledPowerTasks(*) {
    global PowerTaskType, PowerTaskDisplay

    hadTask := (PowerTaskType != "")
    hadLabel := hadTask ? GetPowerTaskLabel(PowerTaskType) : ""
    hadDisplay := PowerTaskDisplay

    abortedSystem := false
    try {
        exitCode := RunWait(A_ComSpec " /c shutdown /a", , "Hide")
        abortedSystem := (exitCode = 0)
    }

    ClearPowerTaskState(false)

    if (hadTask || abortedSystem) {
        msg := "已取消定时管理。"
        if (hadTask)
            msg .= "`n`n原先任务：" . hadLabel . (hadDisplay != "" ? "（" . hadDisplay . "）" : "")
        if (abortedSystem)
            msg .= "`n系统待执行的关机/重启任务已中止。"
        MsgBox(msg, AppName, "Iconi")
    } else {
        MsgBox("当前没有正在等待的定时任务。", AppName, "Icon!")
    }
}

; 兼容旧名称：保留入口，行为与 CancelScheduledPowerTasks 一致。
CancelScheduledShutdown(*) {
    CancelScheduledPowerTasks()
}

; ============================================================

; ===== END INCLUDE Features/PowerTasks/PowerTasks.ahk =====

; ===== BEGIN INCLUDE Features/WinMgrMedia/WinMgrMedia.ahk =====

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
    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
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
        MsgBox("设置阻止熄屏失败。", AppName, "Icon!")
        UpdateTrayStatus()
        return
    }
    UpdateTrayStatus()
    MsgBox(
        newState
            ? "阻止熄屏已启用。`n`n系统不会自动进入睡眠，显示器也不会因空闲而关闭。"
        : "阻止熄屏已关闭。`n`n已恢复 Windows 正常电源管理。",
        AppName,
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

; ===== END INCLUDE Features/WinMgrMedia/WinMgrMedia.ahk =====

; ===== BEGIN INCLUDE Features/Hardware/HardwareInfo.ahk =====

; ============================================================
; Features/Hardware/HardwareInfo.ahk
; V0.27 系统硬件信息
;
; 按需创建窗口；读取 WMI 时使用一次性 Timer，让 GUI 先出现。
; 关闭窗口时彻底释放 GUI 与控件引用。
; ============================================================

HardwareInfoGui := ""
HardwareInfoEdit := ""
HardwareInfoLoadTimer := ""

InitializeHardwareInfo() {
    global HardwareInfoGui
    global HardwareInfoEdit
    global HardwareInfoLoadTimer

    if IsObject(HardwareInfoGui)
        return true

    HardwareInfoGui := ""
    HardwareInfoEdit := ""
    HardwareInfoLoadTimer := ""
    FeatureManager.SetState("HardwareInfo", "loaded")
    return true
}

ShowHardwareInfo(*) {
    global HardwareInfoGui
    global HardwareInfoEdit

    if !InitializeHardwareInfo()
        return

    if IsObject(HardwareInfoGui) {
        try {
            if WinExist("ahk_id " HardwareInfoGui.Hwnd) {
                HardwareInfoGui.Show()
                WinActivate("ahk_id " HardwareInfoGui.Hwnd)
                if IsObject(HardwareInfoEdit)
                    HardwareInfoEdit.Focus()
                LoadHardwareInfoAsync()
                return
            }
        } catch {
            HardwareInfoGui := ""
            HardwareInfoEdit := ""
        }
    }

    g := Gui("+AlwaysOnTop -MinimizeBox", "系统硬件信息")
    g.SetFont("s10", "微软雅黑")

    edit := g.Add(
        "Edit",
        "xm ym w520 h420 ReadOnly VScroll",
        "正在读取硬件信息…"
    )

    HardwareInfoEdit := edit

    refreshBtn := g.Add("Button", "xm y+10 w100", "刷新")
    copyBtn := g.Add("Button", "x+10 w100", "复制全部")
    closeBtn := g.Add("Button", "x+10 w110", "关闭功能")

    refreshBtn.OnEvent(
        "Click",
        (*) => LoadHardwareInfoAsync()
    )

    copyBtn.OnEvent(
        "Click",
        (*) => (
            A_Clipboard := edit.Value,
            TrayTip("已复制", "硬件信息已复制到剪贴板", "Iconi")
        )
    )

    closeBtn.OnEvent(
        "Click",
        ShutdownHardwareInfo
    )

    g.OnEvent("Close", ShutdownHardwareInfo)
    g.OnEvent("Escape", ShutdownHardwareInfo)

    HardwareInfoGui := g

    g.Show("w540 h480")

    FeatureManager.SetState("HardwareInfo", "running")

    LoadHardwareInfoAsync()
}

LoadHardwareInfoAsync() {
    global HardwareInfoEdit
    global HardwareInfoLoadTimer

    if IsObject(HardwareInfoEdit)
        HardwareInfoEdit.Value := "正在读取硬件信息…"

    if IsObject(HardwareInfoLoadTimer) {
        try SetTimer(HardwareInfoLoadTimer, 0)
    }

    HardwareInfoLoadTimer := FillHardwareInfo
    SetTimer(HardwareInfoLoadTimer, -1)
}

FillHardwareInfo() {
    global HardwareInfoEdit
    global HardwareInfoLoadTimer

    HardwareInfoLoadTimer := ""

    if !IsObject(HardwareInfoEdit)
        return

    text := BuildHardwareInfoText()

    if IsObject(HardwareInfoEdit)
        HardwareInfoEdit.Value := text
}

BuildHardwareInfoText() {
    text := ""
    text .= "【操作系统】`n"
    text .= "系统：" A_OSVersion "`n"
    text .= "架构：" (A_PtrSize * 8) " 位`n"
    try text .= "计算机名：" A_ComputerName "`n"

    text .= "`n【实时状态】`n"
    mem := GetMemoryStatus()
    text .= "内存占用：" mem.load "%（总计 " mem.totalGB " GB，可用 " mem.availGB " GB）`n"

    text .= "`n【WMI 详情】`n"

    try {
        wmi := ComObject(
            "WbemScripting.SWbemLocator"
        ).ConnectServer(
            ".",
            "root\cimv2"
        )

        for c in wmi.ExecQuery(
            "SELECT Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed FROM Win32_Processor"
        ) {
            text .= "CPU：" Trim(c.Name) "`n"
            text .= "  物理核心：" c.NumberOfCores
                . "  逻辑核心：" c.NumberOfLogicalProcessors
                . "  最大频率：" Round(c.MaxClockSpeed / 1000, 2)
                . " GHz`n"
        }

        for o in wmi.ExecQuery(
            "SELECT Caption,Version,BuildNumber,OSArchitecture FROM Win32_OperatingSystem"
        )
            text .= "OS：" Trim(o.Caption) " Build " o.BuildNumber
                . "（" o.OSArchitecture "）`n"

        for m in wmi.ExecQuery(
            "SELECT Manufacturer,Product FROM Win32_BaseBoard"
        )
            text .= "主板：" Trim(m.Manufacturer)
                . " " Trim(m.Product) "`n"

        for g in wmi.ExecQuery(
            "SELECT Name,AdapterRAM,DriverVersion FROM Win32_VideoController"
        ) {
            ramGB := ""
            try ramGB := " / 显存报告值 " Round(
                g.AdapterRAM / 1024 ** 3,
                2
            ) " GB"
            text .= "显卡：" Trim(g.Name) ramGB "`n"
        }

        for d in wmi.ExecQuery(
            "SELECT DeviceID,Size,FreeSpace,VolumeName FROM Win32_LogicalDisk WHERE DriveType=3"
        ) {
            sizeGB := Round(
                d.Size / 1024 ** 3,
                1
            )
            freeGB := Round(
                d.FreeSpace / 1024 ** 3,
                1
            )

            text .= "磁盘 " d.DeviceID " " Trim(d.VolumeName)
                . "：共 " sizeGB " GB，可用 " freeGB " GB`n"
        }

        for n in wmi.ExecQuery(
            "SELECT Description,IPAddress,MACAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=TRUE"
        ) {
            ip := ""
            try {
                if IsObject(n.IPAddress) && n.IPAddress.Length
                    ip := n.IPAddress[0]
            }

            text .= "网卡：" Trim(n.Description) "`n"

            if (ip != "")
                text .= "  IP：" ip "  MAC：" n.MACAddress "`n"
        }
    } catch as e {
        text .= "WMI 读取失败：" e.Message "`n"
        text .= "可尝试以管理员权限运行，或检查 WMI 服务是否可用。`n"
    }

    text .= "`n生成时间：" FormatTime(
        A_Now,
        "yyyy-MM-dd HH:mm:ss"
    ) "`n"

    return text
}

GetMemoryStatus() {
    stat := Buffer(64, 0)
    NumPut("UInt", 64, stat, 0)
    DllCall("GlobalMemoryStatusEx", "Ptr", stat)

    return {
        load: NumGet(stat, 4, "UInt"),
        totalGB: Round(
            NumGet(stat, 8, "UInt64") / 1024 ** 3,
            2
        ),
        availGB: Round(
            NumGet(stat, 16, "UInt64") / 1024 ** 3,
            2
        )
    }
}

ShutdownHardwareInfo(*) {
    global HardwareInfoGui
    global HardwareInfoEdit
    global HardwareInfoLoadTimer

    if IsObject(HardwareInfoLoadTimer) {
        try SetTimer(HardwareInfoLoadTimer, 0)
    }

    HardwareInfoLoadTimer := ""

    if IsObject(HardwareInfoGui) {
        try HardwareInfoGui.Destroy()
    }

    HardwareInfoGui := ""
    HardwareInfoEdit := ""

    FeatureManager.SetState(
        "HardwareInfo",
        "unloaded"
    )
}

; ===== END INCLUDE Features/Hardware/HardwareInfo.ahk =====

; ===== BEGIN INCLUDE Features/Clipboard/ClipboardHistory.ahk =====

; ============================================================
; Features/Clipboard/ClipboardHistory.ahk
; V0.27 剪贴板历史
;
; 生命周期：
;   未使用：不创建窗口、不启动 Timer
;   打开：创建 GUI，并启动剪贴板监控
;   关闭：停止 Timer、Destroy GUI、清空内存历史
; ============================================================

ClipHistory := []
ClipHistoryGui := ""
ClipHistoryLV := ""
ClipHistoryMax := 30
ClipHistoryTimer := ""
ClipLastText := ""

InitializeClipboardHistory() {
    global ClipHistory
    global ClipHistoryGui
    global ClipHistoryLV
    global ClipHistoryTimer
    global ClipLastText

    ; 资源已经存在时直接复用。
    if IsObject(ClipHistoryGui) || IsObject(ClipHistoryLV) {
        return true
    }

    ClipHistory := []
    ClipHistoryGui := ""
    ClipHistoryLV := ""
    ClipHistoryTimer := ""
    ClipLastText := ""
    FeatureManager.SetState("ClipboardHistory", "loaded")
    return true
}

ShowClipboardHistory(*) {
    global ClipHistoryGui
    global ClipHistoryLV

    if !InitializeClipboardHistory()
        return

    if IsObject(ClipHistoryGui) {
        try {
            if WinExist("ahk_id " ClipHistoryGui.Hwnd) {
                ClipHistoryGui.Show()
                WinActivate("ahk_id " ClipHistoryGui.Hwnd)
                RefreshClipHistoryList()
                StartClipboardWatcher()
                return
            }
        } catch {
            ClipHistoryGui := ""
            ClipHistoryLV := ""
        }
    }

    g := Gui("+AlwaysOnTop -MinimizeBox", "剪贴板历史")
    g.SetFont("s10", "微软雅黑")

    lv := g.Add("ListView", "xm ym w520 h360", ["#", "内容预览"])
    ClipHistoryLV := lv

    copyBtn := g.Add("Button", "xm y+10 w100", "复制选中")
    clearBtn := g.Add("Button", "x+10 w100", "清空")
    closeBtn := g.Add("Button", "x+10 w110", "关闭功能")

    copyBtn.OnEvent("Click", CopySelectedClip)
    clearBtn.OnEvent("Click", ClearClipboardHistory)
    closeBtn.OnEvent("Click", ShutdownClipboardHistory)

    g.OnEvent("Close", ShutdownClipboardHistory)
    g.OnEvent("Escape", ShutdownClipboardHistory)
    lv.OnEvent("DoubleClick", CopySelectedClip)

    ClipHistoryGui := g

    RefreshClipHistoryList()
    g.Show("w540 h430")

    StartClipboardWatcher()
    FeatureManager.SetState("ClipboardHistory", "running")
}

StartClipboardWatcher() {
    global ClipHistoryTimer

    if IsObject(ClipHistoryTimer)
        return

    ClipHistoryTimer := CheckClipboardChange
    SetTimer(ClipHistoryTimer, 1000)
}

StopClipboardWatcher() {
    global ClipHistoryTimer

    if !IsObject(ClipHistoryTimer)
        return

    try SetTimer(ClipHistoryTimer, 0)
    ClipHistoryTimer := ""
}

CheckClipboardChange() {
    global ClipLastText
    global ClipHistory
    global ClipHistoryMax

    try {
        cur := A_Clipboard

        if (cur = "" || cur = ClipLastText)
            return

        ClipLastText := cur

        ; 去重：相同内容已经存在时，把它移动到最前面。
        for i, item in ClipHistory {
            if (item = cur) {
                ClipHistory.RemoveAt(i)
                break
            }
        }

        ClipHistory.InsertAt(1, cur)

        if (ClipHistory.Length > ClipHistoryMax)
            ClipHistory.Length := ClipHistoryMax

        RefreshClipHistoryList()
    }
}

RefreshClipHistoryList() {
    global ClipHistoryLV
    global ClipHistory

    if !IsObject(ClipHistoryLV)
        return

    try {
        ClipHistoryLV.Delete()

        for i, item in ClipHistory {
            preview := StrReplace(
                StrReplace(item, "`r", " "),
                "`n",
                " "
            )

            if (StrLen(preview) > 80)
                preview := SubStr(preview, 1, 80) "…"

            ClipHistoryLV.Add(, i, preview)
        }
    }
}

CopySelectedClip(*) {
    global ClipHistoryLV
    global ClipHistory

    if !IsObject(ClipHistoryLV)
        return

    row := ClipHistoryLV.GetNext()

    if !row
        return

    idx := Integer(ClipHistoryLV.GetText(row, 1))

    if (idx >= 1 && idx <= ClipHistory.Length) {
        A_Clipboard := ClipHistory[idx]
        TrayTip("剪贴板历史", "已复制到剪贴板", "Iconi")
    }
}

ClearClipboardHistory(*) {
    global ClipHistory

    ClipHistory := []
    RefreshClipHistoryList()
}

ShutdownClipboardHistory(*) {
    global ClipHistory
    global ClipHistoryGui
    global ClipHistoryLV
    global ClipHistoryTimer
    global ClipLastText

    ; 1. 停止后台监控。
    try StopClipboardWatcher()

    ; 2. 销毁窗口，不能只 Hide。
    if IsObject(ClipHistoryGui) {
        try ClipHistoryGui.Destroy()
    }

    ; 3. 清理控件引用。
    ClipHistoryGui := ""
    ClipHistoryLV := ""

    ; 4. 释放历史内容。
    ClipHistory := []
    ClipLastText := ""
    ClipHistoryTimer := ""

    FeatureManager.SetState(
        "ClipboardHistory",
        "unloaded"
    )
}

; ===== END INCLUDE Features/Clipboard/ClipboardHistory.ahk =====

; ===== BEGIN INCLUDE Features/Reminder/Reminder.ahk =====

; ============================================================
; Features/Reminder/Reminder.ahk
; V0.27 定时提醒
;
; 支持：
;   1. 间隔提醒
;   2. 每日提醒
;   3. 倒计时提醒
;
; 只有存在提醒任务时才启动 ReminderTick Timer。
; 没有任务时 Timer 自动关闭。
; 关闭功能时彻底销毁 GUI、停止 Timer 并清空任务。
; ============================================================

ReminderTasks := Map()
ReminderNextID := 1
ReminderTimerRunning := false
ReminderManagerGui := ""
ReminderManagerLV := ""
ReminderPopupGui := ""


InitializeReminderFeature() {
    global ReminderTasks
    global ReminderManagerGui
    global ReminderManagerLV
    global ReminderPopupGui
    global ReminderTimerRunning

    if IsObject(ReminderManagerGui) {
        FeatureManager.SetState("Reminder", "running")
        return true
    }

    ReminderTasks := Map()
    ReminderManagerGui := ""
    ReminderManagerLV := ""
    ReminderPopupGui := ""
    ReminderTimerRunning := false

    FeatureManager.SetState("Reminder", "loaded")
    return true
}

ShowReminderManager(*) {
    global ReminderManagerGui
    global ReminderManagerLV

    if !InitializeReminderFeature()
        return

    if IsObject(ReminderManagerGui) {
        try {
            if WinExist("ahk_id " ReminderManagerGui.Hwnd) {
                ReminderManagerGui.Show()
                WinActivate("ahk_id " ReminderManagerGui.Hwnd)
                RefreshReminderList()
                return
            }
        } catch {
            ReminderManagerGui := ""
            ReminderManagerLV := ""
        }
    }

    g := Gui("+AlwaysOnTop -MinimizeBox", "定时提醒")
    g.SetFont("s10", "微软雅黑")

    g.Add("Text", "x15 y15 w80", "提醒类型：")
    cbType := g.Add(
        "DropDownList",
        "x100 y12 w140 Choose1",
        ["间隔提醒", "每日提醒", "倒计时提醒"]
    )

    g.Add("Text", "x15 y55 w80", "提醒内容：")
    edtContent := g.Add("Edit", "x100 y52 w430 h70")

    g.Add("Text", "x15 y140 w80", "间隔：")
    edtIntervalH := g.Add("Edit", "x100 y137 w60 Number", "0")
    g.Add("Text", "x165 y140 w20", "时")
    edtIntervalM := g.Add("Edit", "x190 y137 w60 Number", "0")
    g.Add("Text", "x255 y140 w20", "分")
    edtIntervalS := g.Add("Edit", "x280 y137 w60 Number", "30")
    g.Add("Text", "x345 y140 w20", "秒")

    g.Add("Text", "x15 y180 w80", "每日时间：")
    edtDailyTime := g.Add("Edit", "x100 y177 w100", "20:30")
    g.Add("Text", "x210 y180 w250 c666666", "格式：HH:MM，例如 08:30")

    g.Add("Text", "x15 y220 w80", "倒计时：")
    edtCountdownH := g.Add("Edit", "x100 y217 w60 Number", "0")
    g.Add("Text", "x165 y220 w20", "时")
    edtCountdownM := g.Add("Edit", "x190 y217 w60 Number", "5")
    g.Add("Text", "x255 y220 w20", "分")
    edtCountdownS := g.Add("Edit", "x280 y217 w60 Number", "0")
    g.Add("Text", "x345 y220 w20", "秒")

    btnAdd := g.Add("Button", "x100 y255 w100 Default", "添加提醒")
    btnStopSelected := g.Add("Button", "x210 y255 w100", "停止选中")
    btnStopAll := g.Add("Button", "x320 y255 w100", "停止全部")
    btnClose := g.Add("Button", "x430 y255 w100", "关闭功能")

    lv := g.Add("ListView", "x15 y300 w610 h210 Grid -Multi", ["编号", "类型", "内容", "状态"])
    ReminderManagerLV := lv

    btnAdd.OnEvent("Click", (*) => AddReminderTask(
        cbType,
        edtContent,
        edtIntervalH,
        edtIntervalM,
        edtIntervalS,
        edtDailyTime,
        edtCountdownH,
        edtCountdownM,
        edtCountdownS
    ))

    btnStopSelected.OnEvent("Click", StopSelectedReminder)
    btnStopAll.OnEvent("Click", StopAllReminders)
    btnClose.OnEvent("Click", ShutdownReminderFeature)
    g.OnEvent("Close", ShutdownReminderFeature)
    g.OnEvent("Escape", ShutdownReminderFeature)

    ReminderManagerGui := g
    RefreshReminderList()
    g.Show("w650 h530")

    FeatureManager.SetState("Reminder", "running")
}

AddReminderTask(
    cbType,
    edtContent,
    edtIntervalH,
    edtIntervalM,
    edtIntervalS,
    edtDailyTime,
    edtCountdownH,
    edtCountdownM,
    edtCountdownS
) {
    global ReminderTasks
    global ReminderNextID

    content := Trim(edtContent.Value)
    if (content = "") {
        MsgBox("请输入提醒内容。", "定时提醒", "Icon!")
        edtContent.Focus()
        return
    }

    taskType := cbType.Text
    task := 0

    if (taskType = "间隔提醒") {
        h := Integer(edtIntervalH.Value)
        m := Integer(edtIntervalM.Value)
        s := Integer(edtIntervalS.Value)
        totalSeconds := h * 3600 + m * 60 + s

        if (totalSeconds <= 0) {
            MsgBox("间隔时间必须大于 0。", "定时提醒", "Icon!")
            return
        }

        task := {
            id: ReminderNextID,
            type: "interval",
            typeName: "间隔提醒",
            content: content,
            intervalMs: totalSeconds * 1000,
            nextTick: A_TickCount + totalSeconds * 1000,
            dailyTime: "",
            lastDailyDate: "",
            deadline: 0,
            status: "运行中"
        }
    }
    else if (taskType = "每日提醒") {
        dailyTime := Trim(edtDailyTime.Value)
        if !RegExMatch(dailyTime, "^(?:[01]\d|2[0-3]):[0-5]\d$") {
            MsgBox("每日时间格式错误。`n`n正确格式：HH:MM`n例如：08:30", "定时提醒", "Icon!")
            edtDailyTime.Focus()
            return
        }

        task := {
            id: ReminderNextID,
            type: "daily",
            typeName: "每日提醒",
            content: content,
            intervalMs: 0,
            nextTick: 0,
            dailyTime: dailyTime,
            lastDailyDate: "",
            deadline: 0,
            status: "运行中"
        }
    }
    else {
        h := Integer(edtCountdownH.Value)
        m := Integer(edtCountdownM.Value)
        s := Integer(edtCountdownS.Value)
        totalSeconds := h * 3600 + m * 60 + s

        if (totalSeconds <= 0) {
            MsgBox("倒计时时间必须大于 0。", "定时提醒", "Icon!")
            return
        }

        task := {
            id: ReminderNextID,
            type: "countdown",
            typeName: "倒计时提醒",
            content: content,
            intervalMs: 0,
            nextTick: 0,
            dailyTime: "",
            lastDailyDate: "",
            deadline: A_TickCount + totalSeconds * 1000,
            status: "运行中"
        }
    }

    ReminderTasks[ReminderNextID] := task
    ReminderNextID++
    EnsureReminderTimer()
    RefreshReminderList()
    edtContent.Value := ""

    TrayTip("定时提醒", "提醒已添加。", "Iconi")
}

EnsureReminderTimer() {
    global ReminderTimerRunning
    global ReminderTasks

    if ReminderTimerRunning || ReminderTasks.Count = 0
        return

    SetTimer(ReminderTick, 1000)
    ReminderTimerRunning := true
}

ReminderTick() {
    global ReminderTasks
    global ReminderTimerRunning

    if (ReminderTasks.Count = 0) {
        SetTimer(ReminderTick, 0)
        ReminderTimerRunning := false
        return
    }

    removeIDs := []
    currentDate := FormatTime(A_Now, "yyyyMMdd")
    currentTime := FormatTime(A_Now, "HH:mm")
    currentTick := A_TickCount

    for id, task in ReminderTasks {
        if (task.type = "interval") {
            if (currentTick >= task.nextTick) {
                ShowReminderNotification(task.content)
                task.nextTick += task.intervalMs
                if (task.nextTick <= currentTick)
                    task.nextTick := currentTick + task.intervalMs
                ReminderTasks[id] := task
            }
        }
        else if (task.type = "daily") {
            if (currentTime = task.dailyTime && task.lastDailyDate != currentDate) {
                ShowReminderNotification(task.content)
                task.lastDailyDate := currentDate
                ReminderTasks[id] := task
            }
        }
        else if (task.type = "countdown") {
            if (currentTick >= task.deadline) {
                ShowReminderNotification(task.content)
                removeIDs.Push(id)
            }
        }
    }

    for _, id in removeIDs {
        if ReminderTasks.Has(id)
            ReminderTasks.Delete(id)
    }

    RefreshReminderList()

    if (ReminderTasks.Count = 0) {
        SetTimer(ReminderTick, 0)
        ReminderTimerRunning := false
    }
}

ShowReminderNotification(content) {
    global ReminderPopupGui

    if IsObject(ReminderPopupGui) {
        try ReminderPopupGui.Destroy()
        ReminderPopupGui := ""
    }

    g := Gui("+AlwaysOnTop -MinimizeBox +ToolWindow", "TRunner - 定时提醒")
    g.SetFont("s11", "微软雅黑")
    g.Add("Text", "x20 y20 w360 h90 Center", content)
    btnClose := g.Add("Button", "x150 y125 w100 Default", "关闭")

    closeReminder(*) {
        global ReminderPopupGui
        if IsObject(ReminderPopupGui) {
            try ReminderPopupGui.Destroy()
        }
        ReminderPopupGui := ""
    }

    btnClose.OnEvent("Click", closeReminder)
    g.OnEvent("Escape", closeReminder)
    g.OnEvent("Close", closeReminder)
    ReminderPopupGui := g
    g.Show("w400 h175 Center")
    try WinActivate("ahk_id " g.Hwnd)
}

RefreshReminderList() {
    global ReminderManagerLV
    global ReminderTasks

    if !IsObject(ReminderManagerLV)
        return

    try {
        ReminderManagerLV.Delete()
        for id, task in ReminderTasks
            ReminderManagerLV.Add(, id, task.typeName, task.content, task.status)

        loop 4
            ReminderManagerLV.ModifyCol(A_Index, "AutoHdr")
    }
}

StopSelectedReminder(*) {
    global ReminderManagerLV
    global ReminderTasks

    if !IsObject(ReminderManagerLV)
        return

    row := ReminderManagerLV.GetNext()
    if !row
        return

    id := Integer(ReminderManagerLV.GetText(row, 1))
    if ReminderTasks.Has(id)
        ReminderTasks.Delete(id)

    RefreshReminderList()
    CheckReminderTimerState()
}

StopAllReminders(*) {
    global ReminderTasks
    ReminderTasks.Clear()
    RefreshReminderList()
    CheckReminderTimerState()
}

CheckReminderTimerState() {
    global ReminderTasks
    global ReminderTimerRunning

    if (ReminderTasks.Count = 0) {
        try SetTimer(ReminderTick, 0)
        ReminderTimerRunning := false
    } else {
        EnsureReminderTimer()
    }
}

ShutdownReminderFeature(*) {
    global ReminderTasks
    global ReminderManagerGui
    global ReminderManagerLV
    global ReminderPopupGui
    global ReminderTimerRunning

    try SetTimer(ReminderTick, 0)
    ReminderTimerRunning := false

    if IsObject(ReminderPopupGui) {
        try ReminderPopupGui.Destroy()
    }

    if IsObject(ReminderManagerGui) {
        try ReminderManagerGui.Destroy()
    }

    ReminderPopupGui := ""
    ReminderManagerGui := ""
    ReminderManagerLV := ""
    ReminderTasks := Map()

    FeatureManager.SetState("Reminder", "unloaded")
}

; ===== END INCLUDE Features/Reminder/Reminder.ahk =====

; ===== BEGIN INCLUDE Features/InstalledApps/InstalledApps.ahk =====

; ======== Features/InstalledApps.ahk ========
; Features — Apps
;  Region 4 — 内置功能函数库
;  用户可在此区域添加、修改或删除函数
;  函数名需与配置编辑器中的 FunctionList 对应
; ============================================================
;
;  4.1 全局变量
; ============================================================
TopMostMarkGui := ""
TopMostMarkTimer := ""

Global MW_MaxWindows := 50
Global MW_Windows := Map()
Global HiddenMgrGui := ""
Global HiddenMgrLV := ""
Global HiddenMgrCollapsed := true
Global HiddenMgrTitlesHidden := false
Global HiddenMgrIconHwnd := 0       ; 图标窗口句柄
Global MW_HiddenOrder := []
;
; ============================================================
; ============================================================
; 4.2 已安装程序列表 —— 高性能版本
; ---------- 列出系统中已安装的应用程序，点击可快速启动 ----------
; 显示已安装程序列表
;
; 功能：
;   1. 显示开始菜单中的程序
;   2. 每个程序显示自己的图标
;   3. 鼠标滚轮直接滚动
;   4. 搜索框实时筛选
;   5. 支持中文名称搜索
;   6. 支持拼音首字母搜索
;      例如：
;          微信      -> 微信
;          wx        -> 微信
;          W X       -> 微信
;   7. 支持英文程序名搜索
;   8. Enter 启动选中程序
;   9. 双击启动
;
; 设计目标：
;   1. 窗口先显示，再加载数据，避免打开时“卡几秒”。
;   2. 使用磁盘 JSON 缓存，TRunner 重启后也可以立即显示上次结果。
;   3. 缓存显示后，后台重新扫描开始菜单；有变化才更新。
;   4. 图标按批次异步加载，每批 20 个，避免 IL_Add 连续卡顿。
;   5. 窗口关闭时完整释放 GUI / ImageList / 图标缓存；磁盘 JSON 缓存保留以便下次快速恢复。
;   6. 搜索结果缓存 + 延迟过滤，连续输入不会反复重建列表。
;   7. 拼音首字母优先复用缓存，减少 CP936 转换。
;
; 注意：磁盘缓存只缓存“程序数据”，不保存 HICON/HBITMAP，
;       因为 Windows 图标句柄不能跨进程持久化。
; ============================================================

InstalledAppsGui := ""
InstalledAppsLV := ""
InstalledAppsEdit := ""
InstalledAppsImageList := 0
InstalledAppsAll := []
InstalledAppsFiltered := []
InstalledAppsRowMap := Map()
InstalledAppsStatus := ""

; ---------- 性能相关状态 ----------
InstalledAppsLoaded := false
InstalledAppsLoading := false
InstalledAppsNeedRefresh := true
InstalledAppsCacheLoaded := false
InstalledAppsRefreshTimer := ""
InstalledAppsIconTimer := ""
InstalledAppsSearchTimer := ""
InstalledAppsIconLoadIndex := 1
InstalledAppsIconCache := Map()
InstalledAppsSearchCache := Map()
InstalledAppsPinyinCache := Map()
InstalledAppsDataGeneration := 0
InstalledAppsCacheVersion := 2

; 缓存文件：放到 LocalAppData，不污染程序目录，也避免权限问题。
InstalledAppsCacheFile := A_ScriptDir "\TRunner\InstalledAppsCache_v2.json"

; ---------- 显示已安装程序 ----------
ShowInstalledApps(*) {
    global InstalledAppsGui
    global InstalledAppsLV
    global InstalledAppsEdit
    global InstalledAppsImageList
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsRowMap
    global InstalledAppsStatus
    global InstalledAppsLoaded
    global InstalledAppsLoading
    global InstalledAppsCacheLoaded
    global InstalledAppsNeedRefresh

    ; --------------------------------------------------------
    ; 已存在的窗口：直接显示。
    ; 不重新扫描、不重新创建 GUI。
    ; --------------------------------------------------------
    if IsObject(InstalledAppsGui) {
        try {
            if WinExist("ahk_id " InstalledAppsGui.Hwnd) {
                InstalledAppsGui.Show()
                WinActivate("ahk_id " InstalledAppsGui.Hwnd)

                if IsObject(InstalledAppsEdit)
                    InstalledAppsEdit.Focus()

                return
            }
        }
        catch {
            InstalledAppsGui := ""
        }
    }

    ; --------------------------------------------------------
    ; Listary 风格：默认只有输入框；有输入时才展开结果列表。
    ; --------------------------------------------------------
    g := Gui("+AlwaysOnTop +ToolWindow", AppName)
    InstalledAppsGui := g
    g.SetFont("s11", "微软雅黑")

    edit := g.Add("Edit", "x10 y10 w480 h32")
    InstalledAppsEdit := edit
    DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x1501, "Ptr", true, "WStr", "输入名称或拼音首字母…")

    lv := g.Add("ListView", "x10 y50 w480 h300 -Multi -Hdr Hidden", ["程序"])
    InstalledAppsLV := lv
    statusText := g.Add("Text", "x10 y355 w480 h16 c888888 Hidden", "")
    statusText.SetFont("s9", "微软雅黑")
    InstalledAppsStatus := statusText

    imageList := IL_Create(512, 20, false)
    InstalledAppsImageList := imageList
    lv.SetImageList(imageList, 1)
    lv.ModifyCol(1, 470)

    lv.OnEvent("DoubleClick", RunSelectedInstalledApp)
    lv.OnEvent("ItemFocus", (*) => 0)
    edit.OnEvent("Change", (*) => ScheduleInstalledAppsFilter())
    g.OnEvent("Close", CloseInstalledAppsWindow)
    g.OnEvent("Escape", CloseInstalledAppsWindow)

    SetInstalledAppsPanelVisible(false)

    winW := 500
    showX := (A_ScreenWidth - winW) // 2
    showY := (A_ScreenHeight - 80) // 3
    g.Show("x" showX " y" showY " w" winW " h70")
    edit.Focus()

    SetTimer(LoadInstalledAppsFastStart, -10)
}

; Listary：有关键字才显示结果列表
SetInstalledAppsPanelVisible(show) {
    global InstalledAppsLV, InstalledAppsStatus, InstalledAppsGui
    static listShown := false
    if (show = listShown)
        return
    listShown := show
    try {
        if show {
            InstalledAppsLV.Visible := true
            InstalledAppsStatus.Visible := true
        } else {
            InstalledAppsLV.Visible := false
            InstalledAppsStatus.Visible := false
        }
    }
    UpdateInstalledAppsPanelSize()
}

UpdateInstalledAppsPanelSize() {
    global InstalledAppsGui, InstalledAppsEdit
    if !IsObject(InstalledAppsGui)
        return
    q := ""
    try q := Trim(InstalledAppsEdit.Value)
    winW := 500
    showX := (A_ScreenWidth - winW) // 2
    if (q != "") {
        winH := 390
        showY := (A_ScreenHeight - winH) // 3
        try InstalledAppsGui.Show("x" showX " y" showY " w" winW " h" winH)
    } else {
        winH := 70
        showY := (A_ScreenHeight - winH) // 3
        try InstalledAppsGui.Show("x" showX " y" showY " w" winW " h" winH)
    }
}

IsInstalledAppsWindowActive() {
    global InstalledAppsGui
    if !IsObject(InstalledAppsGui)
        return false
    try return !!WinActive("ahk_id " InstalledAppsGui.Hwnd)
    return false
}

MoveInstalledAppsSelection(step) {
    global InstalledAppsLV
    if !IsObject(InstalledAppsLV)
        return
    if !InstalledAppsLV.Visible
        return
    count := InstalledAppsLV.GetCount()
    if !count
        return
    cur := InstalledAppsLV.GetNext()
    if !cur
        next := (step > 0) ? 1 : count
    else
        next := cur + step
    if (next < 1)
        next := count
    if (next > count)
        next := 1
    InstalledAppsLV.Modify(0, "-Select")
    InstalledAppsLV.Modify(next, "Select Focus Vis")
}

; 搜索框内 Up/Down/Enter，无需先点列表
#HotIf IsInstalledAppsWindowActive()
Up:: {
    global InstalledAppsLV
    if IsObject(InstalledAppsLV) && WinActive("ahk_id " InstalledAppsLV.Hwnd)
        return
    MoveInstalledAppsSelection(-1)
}
Down:: {
    global InstalledAppsLV
    if IsObject(InstalledAppsLV) && WinActive("ahk_id " InstalledAppsLV.Hwnd)
        return
    MoveInstalledAppsSelection(1)
}
Enter:: RunSelectedInstalledApp()
F5:: RefreshInstalledAppsWindow()
#HotIf

; ============================================================
; 首次打开：先从磁盘缓存恢复
; ============================================================
LoadInstalledAppsFastStart(*) {
    global InstalledAppsCacheLoaded
    global InstalledAppsLoaded
    global InstalledAppsLoading
    global InstalledAppsNeedRefresh

    if InstalledAppsLoading
        return

    InstalledAppsLoading := true

    ; 先读磁盘缓存；失败并不影响后面的后台扫描。
    cacheOK := LoadInstalledAppsCache()

    if cacheOK {
        InstalledAppsCacheLoaded := true
        InstalledAppsLoaded := true
        InstalledAppsNeedRefresh := false
        InstalledAppsFiltered := InstalledAppsAll
        UpdateInstalledAppsStatus("")
        SetTimer(LoadInstalledAppsBackground, -30)
    } else {
        InstalledAppsCacheLoaded := false
        InstalledAppsLoaded := false
        InstalledAppsNeedRefresh := true
        SetTimer(LoadInstalledAppsBackground, -10)
    }
}

; ============================================================
; 后台扫描
; ============================================================
LoadInstalledAppsBackground(*) {
    global InstalledAppsLoading
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsLoaded
    global InstalledAppsNeedRefresh
    global InstalledAppsPinyinCache
    global InstalledAppsDataGeneration
    global InstalledAppsIconCache
    global InstalledAppsSearchCache

    if !IsObject(InstalledAppsGui) {
        InstalledAppsLoading := false
        return
    }

    ; --------------------------------------------------------
    ; 保存旧数据用于判断是否真正变化。
    ; --------------------------------------------------------
    oldKeys := Map()
    for _, oldApp in InstalledAppsAll {
        if IsObject(oldApp) && oldApp.HasOwnProp("cacheKey")
            oldKeys[oldApp.cacheKey] := true
    }

    ; 旧缓存中的拼音直接复用。
    oldPinyinCache := InstalledAppsPinyinCache
    UpdateInstalledAppsStatus("正在后台扫描开始菜单程序……")
    apps := ScanInstalledAppsFast(oldPinyinCache)
    InstalledAppsLoading := false
    if (apps.Length = 0) {
        ; 如果扫描失败且已有缓存，则不要用空结果覆盖用户看到的缓存。
        if (InstalledAppsAll.Length > 0) {
            UpdateInstalledAppsStatus("共 " InstalledAppsAll.Length " 个程序　（扫描未发现有效项目，继续使用缓存）")
            InstalledAppsLoaded := true
            InstalledAppsNeedRefresh := false
            return
        }

        ClearInstalledAppsList()
        InstalledAppsLoaded := true
        InstalledAppsNeedRefresh := false
        UpdateInstalledAppsStatus("未找到已安装的应用程序")
        return
    }

    ; --------------------------------------------------------
    ; 比较缓存与新扫描结果。
    ; --------------------------------------------------------
    changed := (apps.Length != InstalledAppsAll.Length)
    if !changed {
        for _, app in apps {
            if !oldKeys.Has(app.cacheKey) {
                changed := true
                break
            }
        }
    }

    ; 即使数量/Key 未变，也把最新 app 对象缓存下来，
    ; 这样目标路径等信息能够保持最新。
    if changed || !InstalledAppsLoaded {
        SortInstalledApps(apps)

        InstalledAppsAll := apps
        InstalledAppsFiltered := apps
        InstalledAppsDataGeneration++

        ; 搜索缓存必须在数据代际变化后清空。
        InstalledAppsSearchCache := Map()

        ; 图标缓存只需保留仍然存在的 key。
        newIconCache := Map()
        for _, app in apps {
            key := GetInstalledAppIconCacheKey(app)
            if InstalledAppsIconCache.Has(key)
                newIconCache[key] := InstalledAppsIconCache[key]
        }
        InstalledAppsIconCache := newIconCache

        PopulateInstalledAppsList(false)
        SaveInstalledAppsCache(apps)

        UpdateInstalledAppsStatus(apps.Length " 个程序　·　Enter 启动")
    } else {
        ; 没有变化时也重新写一次时间戳不是必须的，
        ; 为减少磁盘写入，这里不写文件。
        UpdateInstalledAppsStatus(InstalledAppsAll.Length " 个程序　·　已是最新")
    }

    InstalledAppsLoaded := true
    InstalledAppsNeedRefresh := false

    ; 最后再分批加载图标。
    SetTimer(LoadInstalledAppIconsChunk, -10)
}

; ============================================================
; 高性能开始菜单扫描
; ============================================================
ScanInstalledAppsFast(reusePinyinCache := 0) {
    global InstalledAppsPinyinCache

    apps := []
    seen := Map()
    newPinyinCache := Map()

    if !IsObject(reusePinyinCache)
        reusePinyinCache := Map()

    startMenuPaths := [A_Programs, A_ProgramsCommon]
    processed := 0

    for _, basePath in startMenuPaths {
        if !DirExist(basePath)
            continue

        loop files, basePath "\*.lnk", "R" {
            processed++
            lnkPath := A_LoopFileFullPath
            target := ""
            workDir := ""
            args := ""
            desc := ""
            icon := ""
            iconNum := 0
            hotkey := ""
            try {
                FileGetShortcut(lnkPath, &target, &workDir, &args, &desc, &icon, &iconNum, &hotkey)
            }
            catch {
                if Mod(processed, 24) = 0
                    Sleep 1
                continue
            }

            if (target = "") {
                if Mod(processed, 24) = 0
                    Sleep 1
                continue
            }

            displayName := A_LoopFileName
            if (StrLower(SubStr(displayName, -4)) = ".lnk")
                displayName := SubStr(displayName, 1, -4)

            if InStr(displayName, "卸载")
                continue
            if InStr(StrLower(displayName), "uninstall")
                continue
            if (Trim(displayName) = "")
                continue

            uniqueKey := StrLower(displayName "`n" target "`n" args)
            if seen.Has(uniqueKey)
                continue
            seen[uniqueKey] := true

            if (icon = "")
                icon := target

            if (icon = "" || !FileExist(icon)) {
                if FileExist(target)
                    icon := target
                else
                    icon := ""
            }

            ; ------------------------------------------------
            ; 优先复用缓存过的拼音，避免重复 CP936 转换。
            ; ------------------------------------------------
            if reusePinyinCache.Has(displayName) {
                pinyin := reusePinyinCache[displayName]
            } else {
                pinyin := GetPinyinInitials(displayName)
            }

            newPinyinCache[displayName] := pinyin

            apps.Push({
                name: displayName,
                target: target,
                args: args,
                icon: icon,
                iconNum: iconNum,
                pinyin: pinyin,
                cacheKey: uniqueKey
            })

            ; ------------------------------------------------
            ; 定期让出时间片并处理 GUI 消息。
            ; 这样大量快捷方式扫描时不会长时间“假死”。
            ; ------------------------------------------------
            if Mod(processed, 24) = 0
                Sleep 1
        }
    }
    InstalledAppsPinyinCache := newPinyinCache
    return apps
}

; ============================================================
; 高性能排序：QuickSort，替代 O(n²) 冒泡排序
; ============================================================
SortInstalledApps(apps) {
    if !IsObject(apps)
        return

    count := apps.Length
    if (count <= 1)
        return

    QuickSortInstalledApps(apps, 1, count)
}

QuickSortInstalledApps(apps, left, right) {
    i := left
    j := right
    pivot := apps[(left + right) // 2].name

    while (i <= j) {
        while (i <= right && StrCompare(apps[i].name, pivot, true) < 0)
            i++

        while (j >= left && StrCompare(apps[j].name, pivot, true) > 0)
            j--

        if (i <= j) {
            temp := apps[i]
            apps[i] := apps[j]
            apps[j] := temp
            i++
            j--
        }
    }

    if (left < j)
        QuickSortInstalledApps(apps, left, j)
    if (i < right)
        QuickSortInstalledApps(apps, i, right)
}

; ============================================================
; 列表填充
; loadIcons=false 时：只立即显示文字/路径，图标后台加载。
; ============================================================
PopulateInstalledAppsList(loadIcons := false) {
    global InstalledAppsLV
    global InstalledAppsImageList
    global InstalledAppsFiltered
    global InstalledAppsRowMap
    global InstalledAppsIconCache
    global InstalledAppsIconLoadIndex
    global InstalledAppsIconTimer

    if !IsObject(InstalledAppsLV)
        return

    if IsObject(InstalledAppsIconTimer) {
        try SetTimer(InstalledAppsIconTimer, 0)
    }
    try SetTimer(LoadInstalledAppIconsChunk, 0)

    InstalledAppsLV.Delete()
    InstalledAppsRowMap := Map()

    fallbackIcon := GetInstalledAppsFallbackIcon()

    for index, app in InstalledAppsFiltered {
        iconIndex := fallbackIcon
        cacheKey := GetInstalledAppIconCacheKey(app)

        ; ----------------------------------------------------
        ; 内存中已经有图标，就直接使用。
        ; ----------------------------------------------------
        if InstalledAppsIconCache.Has(cacheKey) {
            cachedIndex := InstalledAppsIconCache[cacheKey]
            if (cachedIndex > 0)
                iconIndex := cachedIndex
        }

        row := InstalledAppsLV.Add("Icon" iconIndex, app.name)
        InstalledAppsRowMap[row] := index
    }

    ; Listary 式：默认选中第一项
    if (InstalledAppsFiltered.Length > 0) {
        try InstalledAppsLV.Modify(1, "Select Focus Vis")
    }

    InstalledAppsIconLoadIndex := 1

    if loadIcons && InstalledAppsFiltered.Length > 0
        SetTimer(LoadInstalledAppIconsChunk, -10)
    else if InstalledAppsFiltered.Length > 0
        SetTimer(LoadInstalledAppIconsChunk, -10)
}

; ============================================================
; 获取默认系统图标
; ============================================================
GetInstalledAppsFallbackIcon() {
    global InstalledAppsImageList

    static fallbackIcon := 0

    if (fallbackIcon > 0)
        return fallbackIcon

    try {
        fallbackIcon := IL_Add(InstalledAppsImageList, A_WinDir "\System32\shell32.dll", 3)
    }

    return fallbackIcon
}

; ============================================================
; 图标缓存 Key
; ============================================================
GetInstalledAppIconCacheKey(app) {
    iconPath := app.icon
    if (iconPath = "")
        iconPath := app.target

    iconNum := app.iconNum
    if (iconNum = 0)
        iconNum := 1

    return StrLower(iconPath "|" iconNum)
}

; ============================================================
; 分批加载图标
; 每批只处理 20 个。
; ============================================================
LoadInstalledAppIconsChunk(*) {
    global InstalledAppsLV
    global InstalledAppsFiltered
    global InstalledAppsImageList
    global InstalledAppsIconLoadIndex
    global InstalledAppsIconCache
    global InstalledAppsIconTimer

    if !IsObject(InstalledAppsLV) {
        SetTimer(LoadInstalledAppIconsChunk, 0)
        return
    }

    ; 捕获当前数组快照：过滤/刷新可能在本函数执行期间替换 InstalledAppsFiltered。
    apps := InstalledAppsFiltered
    count := apps.Length

    if (count = 0) {
        SetTimer(LoadInstalledAppIconsChunk, 0)
        return
    }

    startIndex := InstalledAppsIconLoadIndex
    if (startIndex < 1)
        startIndex := 1
    ; 搜索会缩短列表并重置加载起点；若本函数已被旧 startIndex 打断，直接纠正。
    if (startIndex > count)
        startIndex := 1

    endIndex := Min(startIndex + 19, count)

    loop (endIndex - startIndex + 1) {
        index := startIndex + A_Index - 1
        if (index < 1 || index > apps.Length)
            break
        app := apps[index]

        iconIndex := 0
        cacheKey := GetInstalledAppIconCacheKey(app)

        if InstalledAppsIconCache.Has(cacheKey) {
            iconIndex := InstalledAppsIconCache[cacheKey]
        } else {
            iconPath := app.icon
            iconNum := app.iconNum
            if (iconNum = 0)
                iconNum := 1

            ; -----------------------------------------------
            ; 优先快捷方式指定的图标。
            ; -----------------------------------------------
            if (iconPath != "" && FileExist(iconPath)) {
                try {
                    iconIndex := IL_Add(InstalledAppsImageList, iconPath, iconNum)
                }
                catch {
                    iconIndex := 0
                }
            }

            ; -----------------------------------------------
            ; 失败后尝试目标 EXE。
            ; -----------------------------------------------
            if (iconIndex = 0 && app.target != "" && FileExist(app.target)) {
                try {
                    iconIndex := IL_Add(InstalledAppsImageList, app.target, 1)
                }
                catch {
                    iconIndex := 0
                }
            }

            ; 记住成功和失败结果，避免搜索时反复提取。
            InstalledAppsIconCache[cacheKey] := iconIndex
        }

        if (iconIndex > 0) {
            try InstalledAppsLV.Modify(index, "Icon" iconIndex)
        }
    }

    InstalledAppsIconLoadIndex := endIndex + 1

    if (InstalledAppsIconLoadIndex > count) {
        SetTimer(LoadInstalledAppIconsChunk, 0)
        InstalledAppsIconTimer := ""
        UpdateInstalledAppsStatus("共 " count " 个程序　　图标加载完成　　支持：名称 / 拼音首字母 / 英文搜索　　Enter / 双击启动")
    } else {
        percent := Round((InstalledAppsIconLoadIndex - 1) / count * 100)
        UpdateInstalledAppsStatus("共 " count " 个程序　　图标加载中 " percent "%")

        ; 不立即 0ms 重入，给 GUI 一个消息处理窗口。
        SetTimer(LoadInstalledAppIconsChunk, 10)
    }
}

; ============================================================
; 延迟搜索
; ============================================================
ScheduleInstalledAppsFilter(*) {
    global InstalledAppsSearchTimer

    if (IsObject(InstalledAppsSearchTimer)) {
        try SetTimer(InstalledAppsSearchTimer, 0)
    }

    InstalledAppsSearchTimer := FilterInstalledAppsDelayed
    SetTimer(InstalledAppsSearchTimer, -60)
}

FilterInstalledAppsDelayed() {
    FilterInstalledApps()
}

; ============================================================
; 实时搜索 + 搜索缓存
; ============================================================
FilterInstalledApps(*) {
    global InstalledAppsEdit
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsSearchCache
    global InstalledAppsDataGeneration
    global InstalledAppsIconLoadIndex
    global InstalledAppsLV

    if !IsObject(InstalledAppsEdit)
        return

    searchText := Trim(InstalledAppsEdit.Value)
    query := StrLower(searchText)
    query := StrReplace(query, " ")
    query := StrReplace(query, "`t")

    cacheKey := InstalledAppsDataGeneration ":" query

    ; --------------------------------------------------------
    ; 空搜索：Listary 风格收起列表，只留输入框。
    ; --------------------------------------------------------
    if (query = "") {
        try SetTimer(LoadInstalledAppIconsChunk, 0)
        InstalledAppsFiltered := InstalledAppsAll
        ClearInstalledAppsList()
        SetInstalledAppsPanelVisible(false)
        UpdateInstalledAppsStatus("")
        return
    }

    SetInstalledAppsPanelVisible(true)

    ; --------------------------------------------------------
    ; 命中搜索缓存：直接恢复索引。
    ; --------------------------------------------------------
    if InstalledAppsSearchCache.Has(cacheKey) {
        try SetTimer(LoadInstalledAppIconsChunk, 0)
        indexes := InstalledAppsSearchCache[cacheKey]
        result := []

        for _, idx in indexes {
            if (idx >= 1 && idx <= InstalledAppsAll.Length)
                result.Push(InstalledAppsAll[idx])
        }

        InstalledAppsFiltered := result
        PopulateInstalledAppsList(false)
        UpdateInstalledAppsStatus(result.Length " 个结果")

        if (result.Length > 0) {
            try InstalledAppsLV.Modify(1, "Select Focus Vis")
        }
        return
    }

    ; --------------------------------------------------------
    ; 第一次搜索：建立索引缓存。
    ; --------------------------------------------------------
    result := []
    indexes := []

    for index, app in InstalledAppsAll {
        nameLower := StrLower(app.name)
        pinyinLower := StrLower(app.pinyin)
        targetLower := StrLower(app.target)

        if InStr(nameLower, query) {
            result.Push(app)
            indexes.Push(index)
            continue
        }

        if (pinyinLower != "" && InStr(pinyinLower, query)) {
            result.Push(app)
            indexes.Push(index)
            continue
        }

        if InStr(targetLower, query) {
            result.Push(app)
            indexes.Push(index)
            continue
        }
    }

    InstalledAppsSearchCache[cacheKey] := indexes
    InstalledAppsFiltered := result
    InstalledAppsIconLoadIndex := 1

    PopulateInstalledAppsList(false)
    UpdateInstalledAppsStatus(result.Length " 个结果")

    if (result.Length > 0) {
        try InstalledAppsLV.Modify(1, "Select Focus Vis")
    }
}

; ============================================================
; 启动选中程序
; ============================================================
RunSelectedInstalledApp(*) {
    global InstalledAppsLV
    global InstalledAppsFiltered

    if !IsObject(InstalledAppsLV)
        return
    if !InstalledAppsLV.Visible
        return

    row := InstalledAppsLV.GetNext(0, "Focused")
    if (row = 0)
        row := InstalledAppsLV.GetNext(0, "Selected")
    if (row = 0)
        return

    if (row > InstalledAppsFiltered.Length)
        return

    app := InstalledAppsFiltered[row]
    cmd := app.target

    if (app.args != "")
        cmd .= " " app.args

    try {
        Run(cmd)
        CloseInstalledAppsWindow()
    }
    catch as e {
        MsgBox("程序启动失败：`n`n" app.name "`n`n命令：" cmd "`n`n错误：" e.Message, "程序启动失败", "Icon!")
    }
}

; ============================================================
; 关闭程序列表功能：真正释放内存资源
; ============================================================
CloseInstalledAppsWindow(*) {
    ShutdownInstalledApps()
}

ShutdownInstalledApps(*) {
    global InstalledAppsGui
    global InstalledAppsLV
    global InstalledAppsEdit
    global InstalledAppsImageList
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsRowMap
    global InstalledAppsStatus
    global InstalledAppsLoaded
    global InstalledAppsLoading
    global InstalledAppsNeedRefresh
    global InstalledAppsCacheLoaded
    global InstalledAppsRefreshTimer
    global InstalledAppsIconTimer
    global InstalledAppsSearchTimer
    global InstalledAppsIconLoadIndex
    global InstalledAppsIconCache
    global InstalledAppsSearchCache
    global InstalledAppsPinyinCache

    ; 停止所有与程序列表有关的一次性/周期 Timer。
    try SetTimer(LoadInstalledAppsFastStart, 0)
    try SetTimer(LoadInstalledAppsBackground, 0)
    try SetTimer(LoadInstalledAppsBackgroundRefresh, 0)
    try SetTimer(LoadInstalledAppIconsChunk, 0)
    try SetTimer(FilterInstalledAppsDelayed, 0)

    if IsObject(InstalledAppsRefreshTimer)
        try SetTimer(InstalledAppsRefreshTimer, 0)
    if IsObject(InstalledAppsIconTimer)
        try SetTimer(InstalledAppsIconTimer, 0)
    if IsObject(InstalledAppsSearchTimer)
        try SetTimer(InstalledAppsSearchTimer, 0)

    InstalledAppsRefreshTimer := ""
    InstalledAppsIconTimer := ""
    InstalledAppsSearchTimer := ""

    ; 销毁 GUI。
    if IsObject(InstalledAppsGui)
        try InstalledAppsGui.Destroy()

    ; ImageList 包含大量系统图标句柄引用，必须释放。
    if InstalledAppsImageList
        try IL_Destroy(InstalledAppsImageList)

    InstalledAppsGui := ""
    InstalledAppsLV := ""
    InstalledAppsEdit := ""
    InstalledAppsImageList := 0
    InstalledAppsStatus := ""

    InstalledAppsAll := []
    InstalledAppsFiltered := []
    InstalledAppsRowMap := Map()
    InstalledAppsIconCache := Map()
    InstalledAppsSearchCache := Map()
    InstalledAppsPinyinCache := Map()

    InstalledAppsLoaded := false
    InstalledAppsLoading := false
    InstalledAppsNeedRefresh := true
    InstalledAppsCacheLoaded := false
    InstalledAppsIconLoadIndex := 1

    FeatureManager.SetState(
        "InstalledApps",
        "unloaded"
    )
}

; ============================================================
; 刷新：明确要求重新扫描
; ============================================================
RefreshInstalledAppsWindow(*) {
    global InstalledAppsLoading
    global InstalledAppsLoaded
    global InstalledAppsNeedRefresh
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsSearchCache
    global InstalledAppsIconCache
    global InstalledAppsDataGeneration

    if InstalledAppsLoading
        return

    InstalledAppsNeedRefresh := true
    InstalledAppsLoaded := false
    InstalledAppsLoading := true
    InstalledAppsAll := []
    InstalledAppsFiltered := []
    InstalledAppsSearchCache := Map()
    InstalledAppsIconCache := Map()
    InstalledAppsDataGeneration++

    ClearInstalledAppsList()
    UpdateInstalledAppsStatus("正在重新扫描开始菜单……")

    SetTimer(LoadInstalledAppsBackgroundRefresh, -10)
}

LoadInstalledAppsBackgroundRefresh(*) {
    global InstalledAppsLoading
    InstalledAppsLoading := false
    LoadInstalledAppsBackground()
}

; ============================================================
; 清空 ListView，但保留窗口、ImageList 和内存缓存结构
; ============================================================
ClearInstalledAppsList() {
    global InstalledAppsLV
    global InstalledAppsRowMap
    global InstalledAppsIconLoadIndex

    try {
        if IsObject(InstalledAppsLV)
            InstalledAppsLV.Delete()
    }

    InstalledAppsRowMap := Map()
    InstalledAppsIconLoadIndex := 1
}

; ============================================================
; 状态文字
; ============================================================
UpdateInstalledAppsStatus(text) {
    global InstalledAppsStatus

    try {
        if IsObject(InstalledAppsStatus)
            InstalledAppsStatus.Text := text
    }
}

; ============================================================
; 磁盘缓存 —— 读取
; ============================================================
LoadInstalledAppsCache() {
    global InstalledAppsCacheFile
    global InstalledAppsCacheVersion
    global InstalledAppsAll
    global InstalledAppsFiltered
    global InstalledAppsPinyinCache
    global InstalledAppsSearchCache
    global InstalledAppsDataGeneration

    try {
        if !FileExist(InstalledAppsCacheFile)
            return false

        raw := FileRead(InstalledAppsCacheFile, "UTF-8")
        if (Trim(raw) = "")
            return false

        data := Json.Parse(raw)

        if !IsObject(data)
            return false

        if !data.Has("version")
            return false

        if (Integer(data["version"]) != InstalledAppsCacheVersion)
            return false

        if !data.Has("apps") || !IsObject(data["apps"])
            return false

        apps := []
        pinyinMap := Map()

        for _, item in data["apps"] {
            if !IsObject(item)
                continue

            name := item.Has("name") ? String(item["name"]) : ""
            target := item.Has("target") ? String(item["target"]) : ""
            args := item.Has("args") ? String(item["args"]) : ""
            icon := item.Has("icon") ? String(item["icon"]) : ""
            iconNum := item.Has("iconNum") ? Integer(item["iconNum"]) : 0
            pinyin := item.Has("pinyin") ? String(item["pinyin"]) : ""
            cacheKey := item.Has("cacheKey") ? String(item["cacheKey"]) : StrLower(name "`n" target "`n" args)

            if (name = "" || target = "")
                continue

            apps.Push({
                name: name,
                target: target,
                args: args,
                icon: icon,
                iconNum: iconNum,
                pinyin: pinyin,
                cacheKey: cacheKey
            })

            pinyinMap[name] := pinyin
        }

        if (apps.Length = 0)
            return false

        SortInstalledApps(apps)

        InstalledAppsAll := apps
        InstalledAppsFiltered := apps
        InstalledAppsPinyinCache := pinyinMap
        InstalledAppsSearchCache := Map()
        InstalledAppsDataGeneration++

        return true
    }
    catch as e {
        ; 缓存损坏时删除，下次重新建立。
        try FileDelete(InstalledAppsCacheFile)
        return false
    }
}

; ============================================================
; 磁盘缓存 —— 保存
; ============================================================
SaveInstalledAppsCache(apps) {
    global InstalledAppsCacheFile
    global InstalledAppsCacheVersion

    try {
        cacheDir := RegExReplace(InstalledAppsCacheFile, "\\[^\\]+$", "")
        if !DirExist(cacheDir)
            DirCreate(cacheDir)

        data := Map()
        data["version"] := InstalledAppsCacheVersion
        data["savedAt"] := A_Now
        data["apps"] := []

        for _, app in apps {
            item := Map()
            item["name"] := app.name
            item["target"] := app.target
            item["args"] := app.args
            item["icon"] := app.icon
            item["iconNum"] := app.iconNum
            item["pinyin"] := app.pinyin
            item["cacheKey"] := app.cacheKey
            data["apps"].Push(item)
        }

        jsonText := Json.Stringify(data, false)

        ; 原子写入：先写临时文件，再替换正式缓存。
        tempFile := InstalledAppsCacheFile ".tmp"
        FileDelete(tempFile)
        FileAppend(jsonText, tempFile, "UTF-8")

        if FileExist(InstalledAppsCacheFile)
            FileDelete(InstalledAppsCacheFile)

        FileMove(tempFile, InstalledAppsCacheFile, true)
    }
    catch {
        ; 缓存只是优化项，写入失败不能影响程序列表。
    }
}

; 获取拼音首字母
; 例如：
;   微信       -> WX
;   百度       -> BD
;   文件管理器 -> WJGLQ
;   Photoshop  -> PHOTOSHOP
; 中文字符通过 CP936/GB2312 编码范围判断首字母。
GetPinyinInitials(text) {
    result := ""
    loop parse, text {
        ch := A_LoopField
        ; ASCII 字符
        code := Ord(ch)
        if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
            result .= StrUpper(ch)
            continue
        }
        ; 数字也保留
        if (code >= 0x30 && code <= 0x39) {
            result .= ch
            continue
        }

        ; 汉字
        initial := GetChineseInitial(ch)
        if (initial != "")
            result .= initial
    }
    return result
}

; 获取单个汉字拼音首字母
; 使用 GB2312/CP936 编码范围。
; 常用汉字的首字母区间是固定的。
GetChineseInitial(ch) {
    ; 转换成 CP936
    buf := Buffer(8, 0)
    try {
        byteCount := StrPut(ch, buf, "CP936")
    } catch {
        return ""
    }
    ; 非双字节中文
    if (byteCount < 2)
        return ""
    b1 := NumGet(buf, 0, "UChar")
    b2 := NumGet(buf, 1, "UChar")
    ; GB2312 代码
    code := (b1 << 8) | b2
    ; A
    if (code >= 0xB0A1 && code <= 0xB0C4)
        return "A"
    ; B
    if (code >= 0xB0C5 && code <= 0xB2C0)
        return "B"
    ; C
    if (code >= 0xB2C1 && code <= 0xB4ED)
        return "C"
    ; D
    if (code >= 0xB4EE && code <= 0xB6E9)
        return "D"
    ; E
    if (code >= 0xB6EA && code <= 0xB7A1)
        return "E"
    ; F
    if (code >= 0xB7A2 && code <= 0xB8C0)
        return "F"
    ; G
    if (code >= 0xB8C1 && code <= 0xB9FD)
        return "G"
    ; H
    if (code >= 0xB9FE && code <= 0xBBF6)
        return "H"
    ; J
    if (code >= 0xBBF7 && code <= 0xBFA5)
        return "J"
    ; K
    if (code >= 0xBFA6 && code <= 0xC0AB)
        return "K"
    ; L
    if (code >= 0xC0AC && code <= 0xC2E7)
        return "L"
    ; M
    if (code >= 0xC2E8 && code <= 0xC4C2)
        return "M"
    ; N
    if (code >= 0xC4C3 && code <= 0xC5B5)
        return "N"
    ; O
    if (code >= 0xC5B6 && code <= 0xC5BD)
        return "O"
    ; P
    if (code >= 0xC5BE && code <= 0xC6D9)
        return "P"
    ; Q
    if (code >= 0xC6DA && code <= 0xC8BA)
        return "Q"
    ; R
    if (code >= 0xC8BB && code <= 0xC8F5)
        return "R"
    ; S
    if (code >= 0xC8F6 && code <= 0xCBF9)
        return "S"
    ; T
    if (code >= 0xCBFA && code <= 0xCDD9)
        return "T"
    ; W
    if (code >= 0xCDDA && code <= 0xCEF3)
        return "W"
    ; X
    if (code >= 0xCEF4 && code <= 0xD1B8)
        return "X"
    ; Y
    if (code >= 0xD1B9 && code <= 0xD4D0)
        return "Y"
    ; Z
    if (code >= 0xD4D1 && code <= 0xFEFF)
        return "Z"
    return ""
}

; 全局消息处理：窗口失活时销毁
CheckAppListActivate(hwnd, wParam, lParam, msg, hwnd2) {
    ; 只处理我们关心的窗口
    if (hwnd2 != hwnd)
        return
    ; wParam 低位表示激活状态：0 = 失活
    if ((wParam & 0xFFFF) = 0) {
        try GuiFromHwnd(hwnd).Destroy()
        catch
            return
    }
}

; ============================================================

; ===== END INCLUDE Features/InstalledApps/InstalledApps.ahk =====

; ===== BEGIN INCLUDE Features/HiddenWindows/HiddenWindows.ahk =====

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

; ===== END INCLUDE Features/HiddenWindows/HiddenWindows.ahk =====

; ===== BEGIN INCLUDE Features/TopMost/TopMost.ahk =====

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

; ===== END INCLUDE Features/TopMost/TopMost.ahk =====

; ===== BEGIN INCLUDE ConfigEditor/ConfigEditor.ahk =====

; ======== Editor/ConfigEditor.ahk ========
; Editor
;  Region 5 — 内置配置设置
; ============================================================
;
;  5.1 图标解析与编辑
; ============================================================

class IconResolver {
    static FindExecutable(command) {
        command := Trim(command)
        if (command = "")
            return ""
        if FileExist(command)
            return IconResolver.ValidateExe(command)

        token := ""
        if (SubStr(command, 1, 1) = '"') {
            p := InStr(command, '"', , 2)
            if p > 2
                token := SubStr(command, 2, p - 2)
        } else {
            test := command
            loop {
                if FileExist(test) {
                    token := test
                    break
                }
                p := InStr(test, " ", , -1)
                if p <= 0
                    break
                test := RTrim(SubStr(test, 1, p - 1))
            }
            if (token = "") {
                p := InStr(command, " ")
                token := p > 1 ? SubStr(command, 1, p - 1) : command
            }
        }
        token := Trim(token, ' "')
        if (token = "")
            return ""

        result := IconResolver.ValidateExe(token)
        if result != ""
            return result

        if !RegExMatch(token, "i)\.[A-Za-z0-9]+$")
            token .= ".exe"
        result := IconResolver.ValidateExe(token)
        if result != ""
            return result

        pathText := EnvGet("PATH")
        if pathText != "" {
            for dir in StrSplit(pathText, ";") {
                dir := Trim(dir, ' "')
                if dir = ""
                    continue
                result := IconResolver.ValidateExe(dir "\" token)
                if result != ""
                    return result
            }
        }
        for dir in [A_WinDir "\System32", A_WinDir, A_WinDir "\SysWOW64"] {
            result := IconResolver.ValidateExe(dir "\" token)
            if result != ""
                return result
        }
        return ""
    }

    static ValidateExe(path) {
        if !FileExist(path)
            return ""
        SplitPath(path, , , &ext)
        return StrLower(ext) = "exe" ? path : ""
    }
}

; ============================================================
;  5.2 图标编辑与自动填充
; ============================================================

class IconEditor {
    static Parse(spec) {
        spec := Trim(String(spec))
        if spec = ""
            return { file: "", index: 0 }
        spec := StrReplace(spec, ",", ":")
        if RegExMatch(spec, "^(.+):(\d+)$", &m)
            return { file: IconEditor.Normalize(m[1]), index: Integer(m[2]) }
        return { file: IconEditor.Normalize(spec), index: 0 }
    }

    static Normalize(file) {
        file := Trim(String(file))
        if file = ""
            return ""
        if SubStr(file, 1, 1) = '"' && SubStr(file, -1) = '"'
            file := SubStr(file, 2, StrLen(file) - 2)
        if FileExist(file)
            return file
        if !InStr(file, "\") && !InStr(file, "/") {
            candidate := A_WinDir "\System32\" file
            if FileExist(candidate)
                return candidate
        }
        if !RegExMatch(file, "i)^[A-Za-z]:\\|^\\\\") {
            candidate := A_ScriptDir "\" file
            if FileExist(candidate)
                return candidate
        }
        return file
    }

    static Compose(file, index := 0) {
        file := Trim(String(file))
        if file = ""
            return ""
        try index := Max(0, Integer(index))
        catch
            index := 0
        return IconEditor.Normalize(file) ":" index
    }

    static Init(spec, command, fileCtrl, indexCtrl) {
        info := IconEditor.Parse(spec)
        fileCtrl.Value := info.file
        indexCtrl.Value := info.index
        if Trim(fileCtrl.Value) = "" {
            exe := IconResolver.FindExecutable(command)
            if exe != "" {
                fileCtrl.Value := exe
                indexCtrl.Value := 0
            }
        }
    }

    static Browse(owner, fileCtrl, indexCtrl) {
        try {
            file := FileSelect(1, , "选择图标文件", "图标文件 (*.ico;*.exe;*.dll;*.icl)")
            if file = ""
                return
            fileCtrl.Value := file
            indexCtrl.Value := 0
        } catch as e {
            MsgBox("选择图标文件失败：`n" e.Message, AppName " " AppVersion " - 配置设置", "Icon!")
        }
    }

    static Read(fileCtrl, indexCtrl) {
        if Trim(fileCtrl.Value) = ""
            return ""
        return IconEditor.Compose(fileCtrl.Value, indexCtrl.Value)
    }
}

class IconAutoFillDebouncer {
    __New(cmdCtrl, fileCtrl, indexCtrl, delay := 400, force := false) {
        this.cmdCtrl := cmdCtrl
        this.fileCtrl := fileCtrl
        this.indexCtrl := indexCtrl
        this.delay := delay
        this.force := force
        this.enabled := true
        this.timer := ObjBindMethod(this, "Execute")
        this.changeHandler := ObjBindMethod(this, "Change")
        this.loseFocusHandler := ObjBindMethod(this, "LoseFocus")
    }
    Change(*) {
        if !this.enabled
            return
        SetTimer(this.timer, 0)
        SetTimer(this.timer, -this.delay)
    }
    LoseFocus(*) {
        if !this.enabled
            return
        SetTimer(this.timer, 0)
        this.Execute()
    }
    Execute(*) {
        if !this.enabled
            return
        command := Trim(this.cmdCtrl.Value)
        if command = ""
            return
        exe := IconResolver.FindExecutable(command)
        if exe = ""
            return
        if !this.force && Trim(this.fileCtrl.Value) != ""
            return
        this.fileCtrl.Value := exe
        this.indexCtrl.Value := 0
    }
    Stop() {
        try SetTimer(this.timer, 0)
    }
    Enable() {
        this.enabled := true
    }
    Disable() {
        this.Stop()
        this.enabled := false
    }
}

; ============================================================
;  5.3 配置编辑器核心
; ============================================================

class EditorState {
    static ConfigPath := ""
    static ConfigData := Map()
    static Sectors := Map()
    static Modified := false
    static Closing := false
    static MainGui := ""
    static LV := ""
    static FunctionList := Map()
}

LoadConfigFile() {
    path := EditorState.ConfigPath

    if !FileExist(path) {
        MsgBox("配置文件不存在：`n" path, AppName " " AppVersion " - 配置设置", "IconX")
        return false
    }

    try {
        raw := FileRead(path, "UTF-8")
        data := Json.Parse(raw)
    } catch as e {
        MsgBox("读取配置失败：`n`n" e.Message, AppName " " AppVersion " - 配置设置", "IconX")
        return false
    }

    if (Type(data) != "Map") {
        MsgBox("Settings.json 顶层必须是对象。", AppName " " AppVersion " - 配置设置", "IconX")
        return false
    }

    EditorState.ConfigData := data
    EditorState.Sectors := ExtractSectors(data)
    EditorState.Modified := false
    EditorState.Closing := false
    return true
}

ExtractSectors(data) {
    sectors := Map()
    for key, value in data {
        if !RegExMatch(String(key), "^\d+$")
            continue
        if (Type(value) != "Map")
            continue
        NormalizeSector(value, key)
        sectors[String(key)] := value
    }
    return sectors
}

NormalizeSector(sec, key := "") {
    if !sec.Has("name")
        sec["name"] := "扇区 " key
    if !sec.Has("type")
        sec["type"] := "run"
    if !sec.Has("target")
        sec["target"] := ""
    if !sec.Has("function")
        sec["function"] := ""
    if !sec.Has("icon")
        sec["icon"] := ""
    if !sec.Has("items") || Type(sec["items"]) != "Array"
        sec["items"] := []
    if !sec.Has("sub") || Type(sec["sub"]) != "Map"
        sec["sub"] := Map()
}

SafeIntegerValue(ctrl, defaultValue, minValue := "", maxValue := "") {
    try {
        raw := Trim(String(ctrl.Value))
    } catch {
        raw := ""
    }
    if (raw = "" || !RegExMatch(raw, "^-?\d+$"))
        return defaultValue
    value := Integer(raw)
    if (minValue != "" && value < minValue)
        value := minValue
    if (maxValue != "" && value > maxValue)
        value := maxValue
    return value
}

SaveConfigFile(showSuccess := true) {

    data := EditorState.ConfigData
    oldKeys := []
    for key in data {
        if RegExMatch(String(key), "^\d+$")
            oldKeys.Push(key)
    }
    for key in oldKeys
        data.Delete(key)

    for key, sec in EditorState.Sectors
        data[key] := sec

    jsonText := Json.Stringify(data, true, 2)
    temp := EditorState.ConfigPath ".tmp"
    bak := EditorState.ConfigPath ".bak"

    try {
        if FileExist(temp)
            FileDelete(temp)

        FileAppend(jsonText, temp, "UTF-8")

        check := Json.Parse(FileRead(temp, "UTF-8"))
        if (Type(check) != "Map")
            throw Error("临时配置文件验证失败")

        if FileExist(EditorState.ConfigPath) {
            if FileExist(bak)
                FileDelete(bak)
            FileCopy(EditorState.ConfigPath, bak, true)
            FileDelete(EditorState.ConfigPath)
        }

        FileMove(temp, EditorState.ConfigPath, true)
        EditorState.Modified := false

        ; 保存成功后立即让当前 TRunner 进程应用新配置。
        ApplyConfigChangesInPlace(true)

        if showSuccess
            MsgBox("配置文件已保存并立即应用。`n`n旧配置已备份为：Settings.json.bak", AppName " " AppVersion " - 配置设置", "Iconi")
        return true
    } catch as e {
        try {
            if FileExist(temp)
                FileDelete(temp)
        }
        MsgBox("保存失败：`n`n" e.Message, AppName " " AppVersion " - 配置设置", "IconX")
        return false
    }
}

MarkConfigModified(*) {
    EditorState.Modified := true
}

LoadFunctionsFromFile() {
    EditorState.FunctionList := Map(
        "ShowTrayMenu", "显示托盘菜单",
        "ShowHelp", "使用帮助",
        "ShowAbout", "关于",
        "ToggleSuspend", "暂停/恢复脚本",
        "CloseWindowUnderMouse", "关闭当前窗口",
        "CopySelectedText", "复制选中内容",
        "CutSelectedText", "剪切选中内容",
        "PasteText", "粘贴",
        "CaptureScreen", "截取屏幕并保存",
        "OpenScreenshotsFolder", "打开截图文件夹",
        "ToggleDesktop", "显示/隐藏桌面",
        "OpenTaskManager", "打开任务管理器",
        "EmptyRecycleBin", "清空回收站",
        "ToggleWindowAlwaysOnTop", "切换窗口置顶",
        "ShowInstalledApps", "程序列表",
        "ShowHardwareInfo", "系统硬件信息",
        "ShowClipboardHistory", "剪贴板历史",
        "ShowReminderManager", "定时提醒",
        "CaptureScreenRegion", "区域截图",
        "CaptureActiveWindow", "活动窗口截图",
        "WindowCenter", "窗口居中",
        "WindowHalfLeft", "窗口靠左半屏",
        "WindowHalfRight", "窗口靠右半屏",
        "WindowMaximize", "最大化窗口",
        "WindowRestore", "还原窗口",
        "WindowMoveNextMonitor", "窗口移到下一显示器",
        "VolumeUp", "音量增加",
        "VolumeDown", "音量减少",
        "VolumeMute", "切换静音",
        "MediaPlayPause", "播放/暂停",
        "MediaNext", "下一曲",
        "MediaPrev", "上一曲",
        "HideWindowUnderMouse", "隐藏当前窗口",
        "ShowHiddenWindowManager", "窗口隐藏管理",
        "RestoreAllHiddenWindows", "恢复所有隐藏窗口"
    )
    files := [A_ScriptFullPath]
    for _, file in files {
        if !FileExist(file)
            continue
        try text := FileRead(file, "UTF-8")
        catch
            continue
        pos := 1
        while RegExMatch(text, "m)^([A-Za-z_][A-Za-z0-9_]*)\s*\([^`r`n]*\)\s*\{", &m, pos) {
            name := m[1]
            if !EditorState.FunctionList.Has(name)
                EditorState.FunctionList[name] := "内部函数：" name
            pos := m.Pos + m.Len
        }
    }
}

; 取函数的中文显示名；无中文说明时退回函数名
GetFunctionDisplayName(fn) {
    if IsObject(EditorState.FunctionList) && EditorState.FunctionList.Has(fn) {
        cn := EditorState.FunctionList[fn]
        if (cn != "" && !RegExMatch(cn, "^内部函数："))
            return cn
    }
    return fn
}

; 下拉框显示「函数名（中文名）」，便于按函数名排序统一辨认；保存时解析回纯函数名。
FormatFunctionLabel(fn) {
    if !IsObject(EditorState.FunctionList) || !EditorState.FunctionList.Has(fn)
        return fn
    cn := EditorState.FunctionList[fn]
    if (cn = "" || cn = fn)
        return fn
    if RegExMatch(cn, "^内部函数：")
        return fn
    return fn "（" cn "）"
}

; 从下拉框文本解析出真实函数名：
;   "ShowHardwareInfo（系统硬件信息）" → ShowHardwareInfo
;   "系统硬件信息（ShowHardwareInfo）" → ShowHardwareInfo
;   "ShowHardwareInfo"                 → ShowHardwareInfo
ParseFunctionNameFromLabel(label) {
    label := Trim(label)
    if (label = "")
        return ""
    ; 函数名（中文名）—— 推荐格式
    if RegExMatch(label, "^([A-Za-z_][A-Za-z0-9_]*)（", &m)
        return m[1]
    ; 中文名（函数名）—— 兼容旧格式
    if RegExMatch(label, "（([A-Za-z_][A-Za-z0-9_]*)）$", &m)
        return m[1]
    return label
}

; 将下拉框的 Items 填成中文标签，并返回 函数名→标签 的映射
FillFunctionCombo(cbo) {
    items := []
    labelMap := Map()
    if IsObject(EditorState.FunctionList) {
        for fn, cn in EditorState.FunctionList {
            label := FormatFunctionLabel(fn)
            items.Push(label)
            labelMap[fn] := label
        }
    }
    if items.Length
        cbo.Add(items)
    return labelMap
}

; 根据函数名选中下拉项；找不到则直接写入函数名
SelectFunctionInCombo(cbo, fn, labelMap) {
    fn := Trim(fn)
    if (fn = "")
        return
    if IsObject(labelMap) && labelMap.Has(fn)
        cbo.Text := labelMap[fn]
    else
        cbo.Text := fn
}

SortNumeric(arr) {
    out := []
    for _, v in arr
        out.Push(v)
    loop out.Length - 1 {
        i := A_Index + 1
        j := i - 1
        key := out[i]
        while (j >= 1 && Integer(out[j]) > Integer(key)) {
            out[j + 1] := out[j]
            j--
        }
        out[j + 1] := key
    }
    return out
}

BuildMainGui() {
    g := Gui("", AppName " " AppVersion " - 配置设置")
    ; 不使用 +Owner / +ToolWindow：保持当前进程内的配置窗口，同时让它拥有独立任务栏按钮。
    EditorState.MainGui := g
    g.SetFont("s10", "微软雅黑")
    g.OnEvent("Close", ConfirmCloseEditor)

    lv := g.Add("ListView", "x10 y10 w1080 h490 Grid -Multi", ["编号", "名称", "类型", "目标/函数", "图标"])
    EditorState.LV := lv
    lv.OnEvent("DoubleClick", (*) => EditSector())

    buttons := []
    buttons.Push(g.Add("Button", "x10 y+10 w70", "新增"))
    buttons[1].OnEvent("Click", AddSector)
    buttons.Push(g.Add("Button", "x+8 w70", "编辑"))
    buttons[2].OnEvent("Click", EditSector)
    buttons.Push(g.Add("Button", "x+8 w100", "编辑菜单项"))
    buttons[3].OnEvent("Click", EditMenuItemsFromMain)
    buttons.Push(g.Add("Button", "x+8 w70", "删除"))
    buttons[4].OnEvent("Click", DeleteSector)
    buttons.Push(g.Add("Button", "x+15 w70", "上移"))
    buttons[5].OnEvent("Click", MoveSectorUp)
    buttons.Push(g.Add("Button", "x+8 w70", "下移"))
    buttons[6].OnEvent("Click", MoveSectorDown)
    buttons.Push(g.Add("Button", "x+15 w95 Default", "保存配置"))
    buttons[7].OnEvent("Click", (*) => SaveConfigFile(true))
    buttons.Push(g.Add("Button", "x+8 w80", "全局设置"))
    buttons[8].OnEvent("Click", OpenGlobalSettings)
    buttons.Push(g.Add("Button", "x+10 w80", "关闭"))
    buttons[9].OnEvent("Click", ConfirmCloseEditor)

    RefreshListView()
    g.Show("w1100 h550")
}

RefreshListView() {
    lv := EditorState.LV
    if !IsObject(lv)
        return
    lv.Delete()
    keys := []
    for key in EditorState.Sectors
        keys.Push(key)
    for key in SortNumeric(keys) {
        sec := EditorState.Sectors[key]
        target := ""
        sectorType := sec.Has("type") ? sec["type"] : "run"
        if (sectorType = "run")
            target := sec.Has("target") ? sec["target"] : ""
        else if (sectorType = "function")
            target := sec.Has("function") ? sec["function"] : ""
        lv.Add(, key, sec.Has("name") ? sec["name"] : "", sectorType, target, sec.Has("icon") ? sec["icon"] : "")
    }
    loop 5
        lv.ModifyCol(A_Index, "AutoHdr")
}

SelectedSectorKey() {
    lv := EditorState.LV
    row := lv.GetNext()
    if !row
        return ""
    return lv.GetText(row, 1)
}

AddSector(*) {
    max := 0
    for key in EditorState.Sectors {
        n := Integer(key)
        if n > max
            max := n
    }
    EditSectorDialog(String(max + 1), true)
}

EditSector(*) {
    key := SelectedSectorKey()
    if (key = "") {
        MsgBox("请先选择一个扇区。", AppName " " AppVersion " - 配置设置", "Icon!")
        return
    }
    EditSectorDialog(key, false)
}

EditSectorDialog(key, isNew := false) {
    if isNew {
        sec := Map("name", "新扇区", "type", "run", "target", "", "function", "", "icon", "", "items", [], "sub", Map())
    } else {
        sec := EditorState.Sectors[key]
        NormalizeSector(sec, key)
    }

    parent := EditorState.MainGui
    parent.Opt("+Disabled")
    g := Gui("", isNew ? "新增扇区" : "编辑扇区 " key)
    g.SetFont("s10", "微软雅黑")

    g.Add("Text", "x10 y10 w80", "编号:")
    txtKey := g.Add("Edit", "x+10 w90", key)
    g.Add("Text", "x10 y+10 w80", "名称:")
    txtName := g.Add("Edit", "x+10 w320", sec["name"])
    g.Add("Text", "x10 y+10 w80", "类型:")
    typeIndex := sec["type"] = "run" ? 1 : sec["type"] = "menu" ? 2 : 3
    cbType := g.Add("DropDownList", "x+10 w140 Choose" typeIndex, ["run", "menu", "function"])
    g.Add("Text", "x10 y+10 w80", "目标:")
    txtTarget := g.Add("Edit", "x+10 w320", sec.Has("target") ? sec["target"] : "")
    g.Add("Text", "x10 y+10 w80", "函数名:")
    cboFunc := g.Add("ComboBox", "x+10 w320")
    current := sec.Has("function") ? sec["function"] : ""
    funcLabelMap := FillFunctionCombo(cboFunc)
    SelectFunctionInCombo(cboFunc, current, funcLabelMap)

    g.Add("Text", "x10 y+10 w80", "图标文件:")
    txtIconFile := g.Add("Edit", "x+10 w260")
    btnBrowse := g.Add("Button", "x+6 w70", "浏览...")
    g.Add("Text", "x10 y+10 w80", "图标索引:")
    txtIconIndex := g.Add("Edit", "x+10 w80 Number", "0")
    g.Add("UpDown", "Range0-9999", 0)
    IconEditor.Init(sec.Has("icon") ? sec["icon"] : "", sec.Has("target") ? sec["target"] : "", txtIconFile, txtIconIndex)
    btnBrowse.OnEvent("Click", (*) => IconEditor.Browse(g, txtIconFile, txtIconIndex))

    debouncer := IconAutoFillDebouncer(txtTarget, txtIconFile, txtIconIndex, 400, false)
    txtTarget.OnEvent("Change", debouncer.changeHandler)
    txtTarget.OnEvent("LoseFocus", debouncer.loseFocusHandler)

    note := g.Add("Text", "x10 y+10 w430 c666666", "目标输入 EXE 后自动识别图标；停止输入约 400ms 或离开目标框时自动检查。`n图标文件与索引分开编辑；手工填写图标不会被覆盖。")
    note.SetFont("s9", "微软雅黑")

    btnMenu := g.Add("Button", "x10 y+15 w120", "编辑菜单项")
    btnMenu.OnEvent("Click", (*) => EditMenuItems(sec, g))
    btnSave := g.Add("Button", "x+15 w80 Default", "保存")
    btnCancel := g.Add("Button", "x+10 w80", "取消")

    UpdateFields(*) {
        t := cbType.Text
        txtTarget.Enabled := (t = "run")
        cboFunc.Enabled := (t = "function")
        btnMenu.Enabled := (t = "menu")
        if (t != "run")
            debouncer.Disable()
        else
            debouncer.Enable()
    }
    cbType.OnEvent("Change", UpdateFields)
    OnFunctionChange(*) {
        fn := ParseFunctionNameFromLabel(cboFunc.Text)
        if (fn = "")
            return
        ; 选中函数后，自动把中文名称填入「名称」编辑框
        txtName.Value := GetFunctionDisplayName(fn)
    }
    cboFunc.OnEvent("Change", OnFunctionChange)

    Close(*) {
        debouncer.Stop()
        SafeDestroy(g, parent)
    }
    Save(*) {
        newKey := Trim(txtKey.Value)
        if !RegExMatch(newKey, "^\d+$") {
            MsgBox("编号必须是数字。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        if EditorState.Sectors.Has(newKey) && (!isNew && newKey != key) {
            MsgBox("编号 " newKey " 已存在。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        if (cbType.Text = "run") {
            debouncer.Stop()
            debouncer.Execute()
        }
        sec["name"] := Trim(txtName.Value)
        sec["type"] := cbType.Text
        sec["target"] := Trim(txtTarget.Value)
        sec["function"] := ParseFunctionNameFromLabel(cboFunc.Text)
        sec["icon"] := IconEditor.Read(txtIconFile, txtIconIndex)
        if (sec["type"] != "menu") {
            sec["items"] := []
            sec["sub"] := Map()
        } else {
            if (Type(sec["items"]) != "Array")
                sec["items"] := []
            if (Type(sec["sub"]) != "Map")
                sec["sub"] := Map()
        }
        if !isNew && newKey != key
            EditorState.Sectors.Delete(key)
        EditorState.Sectors[newKey] := sec
        EditorState.Modified := true
        debouncer.Stop()
        SafeDestroy(g, parent)
        RefreshListView()
    }
    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    btnSave.OnEvent("Click", Save)
    btnCancel.OnEvent("Click", Close)
    UpdateFields()
    g.Show("w500 h420")
}

EditMenuItemsFromMain(*) {
    key := SelectedSectorKey()
    if (key = "") {
        MsgBox("请先选择一个扇区。", AppName " " AppVersion " - 配置设置", "Icon!")
        return
    }
    sec := EditorState.Sectors[key]
    if (sec["type"] != "menu") {
        MsgBox("当前扇区不是 menu 类型。", AppName " " AppVersion " - 配置设置", "Icon!")
        return
    }
    EditMenuItems(sec, EditorState.MainGui)
}

EditMenuItems(sec, parent) {
    if !sec.Has("items") || Type(sec["items"]) != "Array"
        sec["items"] := []
    if !sec.Has("sub") || Type(sec["sub"]) != "Map"
        sec["sub"] := Map()
    ; rootSec 始终指向扇区本身：嵌套子菜单在 sec["sub"] 里扁平存放
    MenuEditorWindow(sec, "items", "编辑菜单项", parent, sec)
}

MenuEditorWindow(ownerMap, listKey, title, parent, rootSec := "") {
    if (rootSec = "")
        rootSec := ownerMap
    parent.Opt("+Disabled")
    g := Gui("", title)
    g.SetFont("s10", "微软雅黑")
    lv := g.Add("ListView", "x10 y10 w790 h290 Grid -Multi", ["文本", "命令", "图标"])
    list := ownerMap.Has(listKey) ? ownerMap[listKey] : []
    if (Type(list) != "Array")
        list := []
    PopulateItemLV(lv, list)

    btnAdd := g.Add("Button", "x10 y+10 w80", "添加")
    btnEdit := g.Add("Button", "x+8 w80", "编辑")
    btnDel := g.Add("Button", "x+8 w80", "删除")
    btnUp := g.Add("Button", "x+20 w80", "上移")
    btnDown := g.Add("Button", "x+8 w80", "下移")
    btnSub := g.Add("Button", "x+20 w100", "编辑子菜单")
    btnSave := g.Add("Button", "x+20 w100 Default", "保存并关闭")

    Close(*) => SafeDestroy(g, parent)
    Add(*) => OpenMenuItemEditor(g, lv, 0)
    Edit(*) {
        row := lv.GetNext()
        if row
            OpenMenuItemEditor(g, lv, row)
        else
            MsgBox("请选择一个菜单项。", AppName " " AppVersion " - 配置设置", "Icon!")
    }
    Del(*) {
        row := lv.GetNext()
        if row
            lv.Delete(row)
    }
    Up(*) => MoveListViewRow(lv, -1)
    Down(*) => MoveListViewRow(lv, 1)
    Sub(*) {
        row := lv.GetNext()
        if !row {
            MsgBox("请选择一个菜单项。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        cmd := lv.GetText(row, 2)
        if SubStr(cmd, 1, 1) != ">" {
            MsgBox("当前项不是子菜单项。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        name := SubStr(cmd, 2)
        ; 子菜单（含多层）都存在扇区 rootSec["sub"] 的扁平 Map 里
        if !rootSec.Has("sub") || Type(rootSec["sub"]) != "Map"
            rootSec["sub"] := Map()
        if !rootSec["sub"].Has(name)
            rootSec["sub"][name] := []
        MenuEditorWindow(rootSec["sub"], name, "编辑子菜单：" name, g, rootSec)
    }
    Save(*) {
        ownerMap[listKey] := ReadItemLV(lv)
        EditorState.Modified := true
        SafeDestroy(g, parent)
    }

    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    lv.OnEvent("DoubleClick", Edit)
    btnAdd.OnEvent("Click", Add)
    btnEdit.OnEvent("Click", Edit)
    btnDel.OnEvent("Click", Del)
    btnUp.OnEvent("Click", Up)
    btnDown.OnEvent("Click", Down)
    btnSub.OnEvent("Click", Sub)
    btnSave.OnEvent("Click", Save)
    g.Show("w810 h360")
}

PopulateItemLV(lv, items) {
    for item in items {
        if Type(item) != "Map"
            continue
        lv.Add(, item.Has("text") ? item["text"] : "", item.Has("cmd") ? item["cmd"] : "", item.Has("icon") ? item["icon"] : "")
    }
    loop 3
        lv.ModifyCol(A_Index, "AutoHdr")
}

ReadItemLV(lv) {
    items := []
    loop lv.GetCount() {
        m := Map()
        m["text"] := lv.GetText(A_Index, 1)
        m["cmd"] := lv.GetText(A_Index, 2)
        m["icon"] := lv.GetText(A_Index, 3)
        items.Push(m)
    }
    return items
}

GetListViewTopIndex(lv) {
    if !IsObject(lv)
        return 0
    try {
        ; LVM_GETTOPINDEX
        return DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x1027, "Ptr", 0, "Ptr", 0, "Ptr")
    }
    return 0
}

GetListViewRowHeight(lv) {
    if !IsObject(lv)
        return 20
    if (lv.GetCount() <= 0)
        return 20

    rect := Buffer(16, 0)

    ; RECT.left = 0 => LVIR_BOUNDS（整行边界）
    NumPut("Int", 0, rect, 0)

    ; LVM_GETITEMRECT = 0x100E
    DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x100E, "Ptr", 0, "Ptr", rect.Ptr)

    top := NumGet(rect, 4, "Int")
    bottom := NumGet(rect, 12, "Int")
    height := bottom - top

    return height > 0 ? height : 20
}

RestoreListViewView(lv, oldTopIndex, selectedRow) {
    if !IsObject(lv)
        return

    count := lv.GetCount()
    if (count <= 0)
        return

    rowHeight := GetListViewRowHeight(lv)

    lv.GetPos(&x, &y, &w, &h)
    visibleRows := Max(1, Floor(h / rowHeight) - 1)

    ; selectedRow 为 0-based
    if (selectedRow < oldTopIndex) {
        newTop := selectedRow
    } else if (selectedRow >= oldTopIndex + visibleRows) {
        newTop := selectedRow - visibleRows + 1
    } else {
        newTop := oldTopIndex
    }

    maxTop := Max(0, count - visibleRows)
    if (newTop > maxTop)
        newTop := maxTop
    if (newTop < 0)
        newTop := 0

    ; LVM_SCROLL = 0x1014（wParam=dx 水平，lParam=dy 垂直）
    DllCall("SendMessageW", "Ptr", lv.Hwnd, "UInt", 0x1014, "Ptr", 0, "Ptr", newTop * rowHeight)

    ; 选中当前项，但不使用 Focus，避免 Windows 再次自动改变滚动位置。
    lv.Modify(selectedRow + 1, "Select")
}

MoveListViewRow(lv, direction) {
    row := lv.GetNext()
    if !row
        return
    target := row + direction
    if target < 1 || target > lv.GetCount()
        return

    oldTop := GetListViewTopIndex(lv)

    arr := ReadItemLV(lv)
    tmp := arr[row]
    arr[row] := arr[target]
    arr[target] := tmp
    lv.Delete()
    PopulateItemLV(lv, arr)

    ; target - 1 为移动后选中项 0-based 索引
    RestoreListViewView(lv, oldTop, target - 1)
}

OpenMenuItemEditor(parent, lv, row) {
    text := row ? lv.GetText(row, 1) : ""
    cmd := row ? lv.GetText(row, 2) : ""
    icon := row ? lv.GetText(row, 3) : ""
    parent.Opt("+Disabled")
    g := CreateMenuItemEditorGui(text, cmd, icon, row, parent, lv)
    g.Show("w500 h400")
}

CreateMenuItemEditorGui(defText, defCmd := "", defIcon := "", row := 0, parentGui := 0, lvCtrl := 0) {
    g := Gui("", row ? "编辑菜单项" : "新增菜单项")
    g.SetFont("s10", "微软雅黑")
    g.Add("Text", "x10 y10 w70", "文本:")
    txtText := g.Add("Edit", "x+10 w350", defText)
    g.Add("Text", "x10 y+12 w70", "类型:")
    cbType := g.Add("DropDownList", "x+10 w180 Choose1", ["运行命令", "内部函数", "子菜单"])
    g.Add("Text", "x10 y+12 w70", "函数:")
    cbo := g.Add("ComboBox", "x+10 w350")
    menuFuncLabelMap := FillFunctionCombo(cbo)
    g.Add("Text", "x10 y+12 w70", "命令:")
    txtCmd := g.Add("Edit", "x+10 w350", defCmd)
    g.Add("Text", "x10 y+12 w70", "图标文件:")
    txtIconFile := g.Add("Edit", "x+10 w270")
    btnBrowse := g.Add("Button", "x+8 w75", "浏览...")
    g.Add("Text", "x10 y+12 w70", "图标索引:")
    txtIconIndex := g.Add("Edit", "x+10 w80 Number", "0")
    g.Add("UpDown", "Range0-9999", 0)
    IconEditor.Init(defIcon, defCmd, txtIconFile, txtIconIndex)
    debounce := IconAutoFillDebouncer(txtCmd, txtIconFile, txtIconIndex, 400, false)

    DetectType() {
        cmd := Trim(defCmd)
        if SubStr(cmd, 1, 1) = ">"
            cbType.Value := 3
        else if RegExMatch(cmd, "i)^function:(.+)$", &m) {
            cbType.Value := 2
            SelectFunctionInCombo(cbo, Trim(m[1]), menuFuncLabelMap)
        } else {
            cbType.Value := 1
        }
    }
    Update(*) {
        t := cbType.Value
        txtCmd.Enabled := (t != 2)
        cbo.Enabled := (t = 2)
        if (t = 1)
            debounce.Enable()
        else
            debounce.Disable()
    }
    DetectType()
    Update()
    cbType.OnEvent("Change", Update)
    OnMenuFunctionChange(*) {
        fn := ParseFunctionNameFromLabel(cbo.Text)
        if (fn = "")
            return
        cbType.Value := 2
        ; 命令框写入 function:函数名
        txtCmd.Value := "function:" fn
        ; 文本框自动填入中文名称（用户可继续改写）
        txtText.Value := GetFunctionDisplayName(fn)
    }
    cbo.OnEvent("Change", OnMenuFunctionChange)
    txtCmd.OnEvent("Change", debounce.changeHandler)
    txtCmd.OnEvent("LoseFocus", debounce.loseFocusHandler)
    btnBrowse.OnEvent("Click", (*) => IconEditor.Browse(g, txtIconFile, txtIconIndex))

    Close(*) {
        debounce.Stop()
        SafeDestroy(g, parentGui)
    }
    Save(*) {
        if (cbType.Value = 1) {
            debounce.Stop()
            debounce.Execute()
        }
        text := Trim(txtText.Value)
        cmd := Trim(txtCmd.Value)
        if (text = "") {
            MsgBox("菜单项文本不能为空。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        if (cbType.Value = 2) {
            fn := ParseFunctionNameFromLabel(cbo.Text)
            if (fn = "") {
                MsgBox("请选择内部函数。", AppName " " AppVersion " - 配置设置", "Icon!")
                return
            }
            cmd := "function:" fn
        } else if (cbType.Value = 3) {
            if (cmd = "") {
                MsgBox("请输入子菜单名称。", AppName " " AppVersion " - 配置设置", "Icon!")
                return
            }
            if SubStr(cmd, 1, 1) != ">"
                cmd := ">" cmd
        } else if (cmd = "") {
            MsgBox("请输入运行命令。", AppName " " AppVersion " - 配置设置", "Icon!")
            return
        }
        icon := IconEditor.Read(txtIconFile, txtIconIndex)
        if row
            lvCtrl.Modify(row, , text, cmd, icon)
        else
            lvCtrl.Add(, text, cmd, icon)
        debounce.Stop()
        SafeDestroy(g, parentGui)
    }
    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    g.Add("Text", "x10 y+12 w470 c666666", "运行命令停止输入约 400ms 或离开命令框时自动识别 EXE 图标。图标文件和索引独立保存。")
    ok := g.Add("Button", "x10 y+18 w90 Default", "确定")
    cancel := g.Add("Button", "x+10 w90", "取消")
    ok.OnEvent("Click", Save)
    cancel.OnEvent("Click", Close)
    return g
}

SafeDestroy(childGui, parentGui) {
    try {
        parentHwnd := parentGui.Hwnd
    } catch {
        parentHwnd := 0
    }

    ; 先关闭子窗口
    try childGui.Destroy()

    ; 恢复父窗口并重新置为前台
    if (parentHwnd) {
        try parentGui.Opt("-Disabled")
        try parentGui.Show("NA")
        SetTimer(ForceActivateParent.Bind(parentHwnd), -30)
    }
}

ForceActivateParent(hwnd) {
    if !hwnd
        return
    try {
        if !DllCall("IsWindow", "Ptr", hwnd)
            return

        ; 确保父窗口可用
        DllCall("EnableWindow", "Ptr", hwnd, "Int", 1)

        ; 提到 Z 顺序前面
        DllCall("BringWindowToTop", "Ptr", hwnd)

        ; 设置为前台窗口
        DllCall("SetForegroundWindow", "Ptr", hwnd)

        ; AHK 再确认一次
        try WinActivate("ahk_id " hwnd)
    }
}

DeleteSector(*) {
    key := SelectedSectorKey()
    if key = ""
        return
    if (MsgBox("确定删除扇区 " key "？", AppName " " AppVersion " - 配置设置", "YesNo Icon!") != "Yes")
        return
    EditorState.Sectors.Delete(key)
    EditorState.Modified := true
    RefreshListView()
}

MoveSectorUp(*) => MoveSector(-1)
MoveSectorDown(*) => MoveSector(1)

MoveSector(direction) {
    lv := EditorState.LV
    row := lv.GetNext()
    if !row
        return
    target := row + direction
    if target < 1 || target > lv.GetCount()
        return

    oldTop := GetListViewTopIndex(lv)

    key1 := lv.GetText(row, 1)
    key2 := lv.GetText(target, 1)
    sec1 := EditorState.Sectors.Delete(key1)
    sec2 := EditorState.Sectors.Delete(key2)
    EditorState.Sectors[key2] := sec1
    EditorState.Sectors[key1] := sec2
    EditorState.Modified := true
    RefreshListView()

    ; target - 1 为移动后选中项 0-based 索引
    RestoreListViewView(EditorState.LV, oldTop, target - 1)
}

OpenGlobalSettings(*) {
    parent := EditorState.MainGui
    parent.Opt("+Disabled")
    g := Gui("", "全局配置")
    g.SetFont("s10", "微软雅黑")
    data := EditorState.ConfigData
    app := data.Has("appearance") && Type(data["appearance"]) = "Map" ? data["appearance"] : Map()

    chkMenu := g.Add("Checkbox", "x20 y20", "菜单项显示图标")
    chkSector := g.Add("Checkbox", "x20 y+8", "扇区显示图标")
    g.Add("Text", "x20 y+20", "窗口尺寸:")
    edtSize := g.Add("Edit", "x+10 w100", app.Has("windowSize") ? app["windowSize"] : 500)
    g.Add("Text", "x20 y+10", "外圈半径:")
    edtRadius := g.Add("Edit", "x+10 w100", app.Has("outerRadius") ? app["outerRadius"] : 250)
    g.Add("Text", "x20 y+10", "分割线颜色:")
    edtPen := g.Add("Edit", "x+10 w100", app.Has("penColor") ? app["penColor"] : "FFFFFF")
    g.Add("Text", "x20 y+10", "分割线宽度:")
    edtPenW := g.Add("Edit", "x+10 w100", app.Has("penWidth") ? app["penWidth"] : 2)
    g.Add("Text", "x20 y+10", "背景颜色:")
    edtBg := g.Add("Edit", "x+10 w100", app.Has("bgColor") ? app["bgColor"] : "F0F0F0")
    g.Add("Text", "x20 y+10", "文字颜色:")
    edtText := g.Add("Edit", "x+10 w100", app.Has("textColor") ? app["textColor"] : "000000")
    g.Add("Text", "x20 y+10", "字体大小:")
    edtFont := g.Add("Edit", "x+10 w100", app.Has("fontSize") ? app["fontSize"] : 14)
    g.Add("Text", "x20 y+10", "字体粗细:")
    edtWeight := g.Add("Edit", "x+10 w100", app.Has("fontWeight") ? app["fontWeight"] : 700)
    g.Add("Text", "x20 y+10", "取消半径:")
    edtEscape := g.Add("Edit", "x+10 w100", app.Has("escapeRadius") ? app["escapeRadius"] : 40)
    g.Add("Text", "x20 y+10", "背景模式:")
    cbBg := g.Add("DropDownList", "x+10 w100", ["default", "transparent", "comfortable"])
    bg := app.Has("background") ? app["background"] : "default"
    cbBg.Text := bg
    g.Add("Text", "x20 y+10", "背景透明度:")
    edtAlpha := g.Add("Edit", "x+10 w100", app.Has("backgroundAlpha") ? app["backgroundAlpha"] : 230)
    chkMenu.Value := data.Has("showMenuIcon") ? data["showMenuIcon"] : 1
    chkSector.Value := data.Has("showSectorIcon") ? data["showSectorIcon"] : 1

    Close(*) => SafeDestroy(g, parent)
    Save(*) {
        data["showMenuIcon"] := chkMenu.Value
        data["showSectorIcon"] := chkSector.Value
        if !data.Has("appearance") || Type(data["appearance"]) != "Map"
            data["appearance"] := Map()
        appMap := data["appearance"]
        appMap["windowSize"] := SafeIntegerValue(edtSize, 500, 100, 2000)
        appMap["outerRadius"] := SafeIntegerValue(edtRadius, 250, 50, 1000)
        appMap["penColor"] := edtPen.Value
        appMap["penWidth"] := SafeIntegerValue(edtPenW, 2, 1, 20)
        appMap["bgColor"] := edtBg.Value
        appMap["textColor"] := edtText.Value
        appMap["fontSize"] := SafeIntegerValue(edtFont, 14, 6, 72)
        appMap["fontWeight"] := SafeIntegerValue(edtWeight, 700, 100, 900)
        appMap["escapeRadius"] := SafeIntegerValue(edtEscape, 40, 0, 500)
        appMap["background"] := cbBg.Text
        appMap["backgroundAlpha"] := SafeIntegerValue(edtAlpha, 230, 0, 255)
        EditorState.Modified := true
        SafeDestroy(g, parent)
    }
    g.OnEvent("Close", Close)
    g.OnEvent("Escape", Close)
    ok := g.Add("Button", "x60 y+20 w80 Default", "确定")
    cancel := g.Add("Button", "x+20 w80", "取消")
    ok.OnEvent("Click", Save)
    cancel.OnEvent("Click", Close)
    g.Show("w340 h540")
}

ConfirmCloseEditor(*) {

    if EditorState.Closing
        return

    if EditorState.Modified {
        result := MsgBox(
            "配置已经修改但尚未保存。`n`n是否保存后再关闭配置窗口？",
            AppName " " AppVersion " - 配置设置",
            "YesNoCancel Icon!"
        )
        if (result = "Cancel")
            return
        if (result = "Yes" && !SaveConfigFile(false))
            return
    }

    EditorState.Closing := true
    if IsObject(EditorState.MainGui)
        try EditorState.MainGui.Destroy()
    EditorState.MainGui := ""
    EditorState.LV := ""
    EditorState.Modified := false
    EditorState.Closing := false
}

; ===== END INCLUDE ConfigEditor/ConfigEditor.ahk =====

; ===== BEGIN INCLUDE Main/Main.ahk =====

; ============================================================
; Main_Start.ahk
; V0.27 主程序启动入口
; ============================================================

ShowConfigEditor(*) {

    if IsObject(EditorState.MainGui) {
        try {
            if WinExist("ahk_id " EditorState.MainGui.Hwnd) {
                EditorState.MainGui.Show()
                WinActivate("ahk_id " EditorState.MainGui.Hwnd)
                return
            }
        }
    }

    EditorState.ConfigPath := A_ScriptDir "\Settings.json"
    if !LoadConfigFile()
        return

    LoadFunctionsFromFile()
    BuildMainGui()

    if IsObject(EditorState.MainGui) {
        try EditorState.MainGui.Show("Center")
        try WinActivate("ahk_id " EditorState.MainGui.Hwnd)
    }
}

StartTRunner() {
    global StartupComplete
    global MouseMonitorPaused
    global LastProfileHWND

    try DllCall("SetProcessDPIAware")

    LoadConfig()
    GetCurrentProfileSectors()
    try LastProfileHWND := WinGetID("A")

    OnExit(CleanupMainResources)
    OnMessage(0x84, HandleLayeredHitTest)

    RegisterAllFeatures()

    try InitTrayMenu()
    try {
        if !BuildMenuGUI(true, true)
            ShowAppNotify("TRunner", "圆形菜单视觉层初始化失败，右键拖动可能无法弹出。可试托盘「刷新」。", "error", 4000)
    }
    try ResetMouseInteractionState(true)

    TimerManager.Register("Runtime", RuntimeMonitor, 1000)
    try TraySetIcon("comres.dll", 1, true)
    MouseMonitorPaused := false
    StartupComplete := true

    try UpdateTrayStatus()
    LoadPowerTaskState()
}

StartTRunner()

; ===== END INCLUDE Main/Main.ahk =====

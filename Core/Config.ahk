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
        MsgBox(msg, "TRunner", "IconX")
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
            WinGetPID(&pid, "ahk_id " hwnd)
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
            WinGetClass(&cls, "ahk_id " hwnd)
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

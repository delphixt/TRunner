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
                parentMenu.Add(text " (子菜单未定义)", (*) => MsgBox("子菜单「" subMenuName "」未配置。", "TRunner", "Icon!"))
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
                parentMenu.Add(text " (函数为空)", (*) => MsgBox("菜单项「" text "」没有指定函数。", "TRunner", "Icon!"))
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

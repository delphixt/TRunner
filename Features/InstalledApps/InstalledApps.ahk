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
    g := Gui("+AlwaysOnTop +ToolWindow", "TRunner")
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

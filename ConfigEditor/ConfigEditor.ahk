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
            MsgBox("选择图标文件失败：`n" e.Message, "TRunner " AppVersion " - 配置设置", "Icon!")
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
        MsgBox("配置文件不存在：`n" path, "TRunner " AppVersion " - 配置设置", "IconX")
        return false
    }

    try {
        raw := FileRead(path, "UTF-8")
        data := Json.Parse(raw)
    } catch as e {
        MsgBox("读取配置失败：`n`n" e.Message, "TRunner " AppVersion " - 配置设置", "IconX")
        return false
    }

    if (Type(data) != "Map") {
        MsgBox("Settings.json 顶层必须是对象。", "TRunner " AppVersion " - 配置设置", "IconX")
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
            MsgBox("配置文件已保存并立即应用。`n`n旧配置已备份为：Settings.json.bak", "TRunner " AppVersion " - 配置设置", "Iconi")
        return true
    } catch as e {
        try {
            if FileExist(temp)
                FileDelete(temp)
        }
        MsgBox("保存失败：`n`n" e.Message, "TRunner " AppVersion " - 配置设置", "IconX")
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
    g := Gui("", "TRunner " AppVersion " - 配置设置")
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
        MsgBox("请先选择一个扇区。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
            MsgBox("编号必须是数字。", "TRunner " AppVersion " - 配置设置", "Icon!")
            return
        }
        if EditorState.Sectors.Has(newKey) && (!isNew && newKey != key) {
            MsgBox("编号 " newKey " 已存在。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
        MsgBox("请先选择一个扇区。", "TRunner " AppVersion " - 配置设置", "Icon!")
        return
    }
    sec := EditorState.Sectors[key]
    if (sec["type"] != "menu") {
        MsgBox("当前扇区不是 menu 类型。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
            MsgBox("请选择一个菜单项。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
            MsgBox("请选择一个菜单项。", "TRunner " AppVersion " - 配置设置", "Icon!")
            return
        }
        cmd := lv.GetText(row, 2)
        if SubStr(cmd, 1, 1) != ">" {
            MsgBox("当前项不是子菜单项。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
            MsgBox("菜单项文本不能为空。", "TRunner " AppVersion " - 配置设置", "Icon!")
            return
        }
        if (cbType.Value = 2) {
            fn := ParseFunctionNameFromLabel(cbo.Text)
            if (fn = "") {
                MsgBox("请选择内部函数。", "TRunner " AppVersion " - 配置设置", "Icon!")
                return
            }
            cmd := "function:" fn
        } else if (cbType.Value = 3) {
            if (cmd = "") {
                MsgBox("请输入子菜单名称。", "TRunner " AppVersion " - 配置设置", "Icon!")
                return
            }
            if SubStr(cmd, 1, 1) != ">"
                cmd := ">" cmd
        } else if (cmd = "") {
            MsgBox("请输入运行命令。", "TRunner " AppVersion " - 配置设置", "Icon!")
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
    if (MsgBox("确定删除扇区 " key "？", "TRunner " AppVersion " - 配置设置", "YesNo Icon!") != "Yes")
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
            "TRunner " AppVersion " - 配置设置",
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

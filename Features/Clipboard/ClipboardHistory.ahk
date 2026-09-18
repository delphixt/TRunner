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

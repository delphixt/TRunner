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
        MsgBox("请输入有效的倒计时。`n`n小时和分钟不能同时为 0（或留空）。", "TRunner", "Icon!")
        return
    }
    ; 系统 shutdown 命令的 /t 参数上限为 10 年（315360000 秒）；锁屏同样限制。
    if (totalSeconds > 315360000) {
        MsgBox("倒计时过长。`n`n最长支持 10 年（87600 小时）。", "TRunner", "Icon!")
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
            MsgBox(label . "已设置。`n`n将在 " . displayText . " 后自动锁屏。`n`n如需取消，请选择托盘菜单：`n关机 → 取消定时管理。", "TRunner", "Iconi")
            return
        }

        switchFlag := (action = "restart") ? "/r" : "/s"
        exitCode := RunWait(A_ComSpec ' /c shutdown ' switchFlag ' /t ' seconds, , "Hide")
        if (exitCode != 0) {
            MsgBox("设置" . label . "失败。`n`n系统返回代码：" exitCode, "TRunner", "IconX")
            return
        }
        PowerTaskType := action
        PowerTaskDisplay := displayText
        SavePowerTaskState()
        MsgBox(label . "已设置。`n`n将在 " . displayText . " 后自动" . (action = "restart" ? "重启" : "关机") . "。`n`n如需取消，请选择托盘菜单：`n关机 → 取消定时管理。", "TRunner", "Iconi")
    } catch as e {
        PowerTaskType := ""
        PowerTaskDeadline := 0
        PowerTaskDisplay := ""
        MsgBox("设置" . label . "失败。`n`n" . e.Message, "TRunner", "IconX")
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
        TrayTip("TRunner", "检测到系统中仍有待执行的" . GetPowerTaskLabel(t) . "任务", "Icon!")
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
        MsgBox(msg, "TRunner", "Iconi")
    } else {
        MsgBox("当前没有正在等待的定时任务。", "TRunner", "Icon!")
    }
}

; 兼容旧名称：保留入口，行为与 CancelScheduledPowerTasks 一致。
CancelScheduledShutdown(*) {
    CancelScheduledPowerTasks()
}

; ============================================================

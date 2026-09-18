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

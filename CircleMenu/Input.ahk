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
;   右键 — 直接关闭菜单。
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

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

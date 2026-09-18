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

    ; InitTrayMenu 失败也必须继续，否则 StartupComplete 不会置位，
    ; #HotIf 会永久关掉右键拖动。
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

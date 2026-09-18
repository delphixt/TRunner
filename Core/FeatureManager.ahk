; ============================================================
; Core/FeatureManager.ahk
; V0.27 功能生命周期管理
; ============================================================

class FeatureManager {
    static States := Map()
    static ShutdownCallbacks := Map()

    static Register(name, shutdownFunctionName := "") {
        if !FeatureManager.States.Has(name)
            FeatureManager.States[name] := "unloaded"

        if (shutdownFunctionName != "")
            FeatureManager.ShutdownCallbacks[name] := String(shutdownFunctionName)
    }

    static SetState(name, state) {
        FeatureManager.States[name] := state
    }

    static GetState(name) {
        return FeatureManager.States.Has(name)
            ? FeatureManager.States[name]
            : "unregistered"
    }

    static IsLoaded(name) {
        state := FeatureManager.GetState(name)
        return (state = "loaded" || state = "running")
    }

    static Shutdown(name) {
        if FeatureManager.ShutdownCallbacks.Has(name) {
            fnName := FeatureManager.ShutdownCallbacks[name]
            try {
                ; AHK v2 中 Func() 是类构造器，不能当工厂用（Invalid base）。
                ; 用动态调用 %fnName%()，兼容 Shutdown*(*) 签名。
                if (fnName != "")
                    %fnName%()
            }
        }
        FeatureManager.States[name] := "unloaded"
    }

    static ShutdownAll() {
        names := []
        for name, _ in FeatureManager.ShutdownCallbacks
            names.Push(name)

        for _, name in names
            FeatureManager.Shutdown(name)
    }
}

RegisterAllFeatures() {
    FeatureManager.Register("ClipboardHistory", "ShutdownClipboardHistory")
    FeatureManager.Register("InstalledApps", "ShutdownInstalledApps")
    FeatureManager.Register("HardwareInfo", "ShutdownHardwareInfo")
    FeatureManager.Register("Reminder", "ShutdownReminderFeature")
    FeatureManager.Register("Screenshot", "ShutdownScreenshotFeature")
    FeatureManager.Register("WindowManager", "ShutdownWindowManagerFeature")
    FeatureManager.Register("HiddenWindowManager", "ShutdownHiddenWindowManagerFeature")
}

; ======== Core/PowerManager.ahk ========
; Core — Power
class PowerManager {
    static SetEnabled(enable := true) {
        try {
            if enable {
                flags := ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
                result := DllCall("Kernel32\SetThreadExecutionState", "UInt", flags, "UInt")
                if !result {
                    PreventSleep := false
                    return false
                }
                PreventSleep := true
                return true
            }
            result := DllCall("Kernel32\SetThreadExecutionState", "UInt", ES_CONTINUOUS, "UInt")
            if !result
                return false
            PreventSleep := false
            return true
        } catch {
            return false
        }
    }
    static Cleanup() {
        global PreventSleep
        if PreventSleep
            PowerManager.SetEnabled(false)
    }
}

; ============================================================
;  Region 2.5 — Icon 图标管理
;  EXE/DLL/ICO 图标提取、缓存与路径规范化
; ============================================================

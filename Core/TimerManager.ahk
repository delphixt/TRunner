; ======== Core/TimerManager.ahk ========
; Core — Timer
class TimerManager {
    static Items := Map()
    static Register(name, callback, interval) {
        if TimerManager.Items.Has(name)
            TimerManager.Stop(name)
        TimerManager.Items[name] := callback
        SetTimer(callback, interval)
    }

    static Stop(name) {
        if !TimerManager.Items.Has(name)
            return
        callback := TimerManager.Items[name]
        try SetTimer(callback, 0)
        TimerManager.Items.Delete(name)
    }

    static StopAll() {
        for _, callback in TimerManager.Items {
            try SetTimer(callback, 0)
        }
        TimerManager.Items.Clear()
    }
}

; ============================================================
;  Region 2.4 — Power 电源管理
;  使用 Windows API 实现系统电源控制（关机/重启/注销/阻止熄屏）
; ============================================================

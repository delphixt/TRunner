; ======== Core/GdiPlus.ahk ========
; Core — GDI+
class GdiPlusManager {
    static Token := 0
    static Initialized := false

    static Ensure() {
        if GdiPlusManager.Initialized
            return true
        token := 0
        si := Buffer(16, 0)
        NumPut("UInt", 1, si, 0)
        result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0, "UInt")
        if (result != 0 || token = 0)
            return false
        GdiPlusManager.Token := token
        GdiPlusManager.Initialized := true
        return true
    }

    static Stop() {
        if !GdiPlusManager.Initialized
            return
        token := GdiPlusManager.Token
        if token
            DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
        GdiPlusManager.Token := 0
        GdiPlusManager.Initialized := false
    }
}

; ============================================================
;  Region 2.3 — Timer 定时器管理
;  集中管理所有 SetTimer，支持注册/注销/暂停
; ============================================================

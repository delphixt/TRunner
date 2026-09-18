; ======== Core/IconManager.ahk ========
; Core — Icon
class IconManager {
    static Cache := Map()
    static Parse(spec) {
        spec := Trim(String(spec))
        if spec = ""
            return { file: "", index: 0 }
        spec := StrReplace(spec, ",", ":")
        if RegExMatch(spec, "^(.+):(\d+)$", &m)
            return { file: IconManager.NormalizePath(m[1]), index: Integer(m[2]) }
        return { file: IconManager.NormalizePath(spec), index: 0 }
    }

    static NormalizePath(file) {
        file := Trim(String(file))
        if file = ""
            return ""
        if SubStr(file, 1, 1) = '"' && SubStr(file, -1) = '"'
            file := SubStr(file, 2, StrLen(file) - 2)
        if FileExist(file)
            return file
        if !InStr(file, "\") && !InStr(file, "/") {
            p := A_WinDir "\System32\" file
            if FileExist(p)
                return p
        }
        if !RegExMatch(file, "i)^[A-Za-z]:\\|^\\\\") {
            p := A_ScriptDir "\" file
            if FileExist(p)
                return p
        }
        return file
    }

    static Compose(file, index := 0) {
        file := Trim(String(file))
        if file = ""
            return ""
        try index := Max(0, Integer(index))
        catch
            index := 0
        return IconManager.NormalizePath(file) ":" index
    }

    static Get(spec) {
        info := IconManager.Parse(spec)
        if info.file = ""
            return 0
        key := StrLower(info.file) "|" info.index
        if IconManager.Cache.Has(key)
            return IconManager.Cache[key]
        ; 系统目录路径直接提取；其它路径先 FileExist，
        ; 但用 try 包住，避免异常驱动器导致拖死。
        try {
            isSystem := InStr(info.file, A_WinDir) = 1
            if (!isSystem && !FileExist(info.file))
                return 0
            hLarge := 0
            hSmall := 0
            count := DllCall("Shell32\ExtractIconExW", "WStr", info.file, "Int", info.index > 0 ? info.index - 1 : 0,
                "Ptr*", &hLarge, "Ptr*", &hSmall, "UInt", 1)
            if count <= 0
                return 0
            hIcon := hLarge ? hLarge : hSmall
            if hLarge && hSmall {
                if hIcon = hLarge
                    DllCall("DestroyIcon", "Ptr", hSmall)
                else
                    DllCall("DestroyIcon", "Ptr", hLarge)
            }
            IconManager.Cache[key] := hIcon
            return hIcon
        } catch {
            return 0
        }
    }

    static Clear() {
        for _, hIcon in IconManager.Cache {
            if hIcon
                try DllCall("DestroyIcon", "Ptr", hIcon)
        }
        IconManager.Cache.Clear()
    }
}

; ============================================================

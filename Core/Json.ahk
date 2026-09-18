; ======== Core/Json.ahk ========
; Core — JSON
class Json {
    static Parse(str) {
        pos := 1
        value := Json._ParseValue(&pos, str)
        Json._SkipWhitespace(&pos, str)
        if (pos <= StrLen(str))
            throw Error("JSON 后存在无效内容，位置：" pos)
        return value
    }
    static _ParseValue(&pos, str) {
        Json._SkipWhitespace(&pos, str)
        if (pos > StrLen(str))
            throw Error("JSON 意外结束")
        ch := SubStr(str, pos, 1)
        if (ch = "{")
            return Json._ParseObject(&pos, str)
        if (ch = "[")
            return Json._ParseArray(&pos, str)
        if (ch = '"')
            return Json._ParseString(&pos, str)
        if (ch = "-" || (ch >= "0" && ch <= "9"))
            return Json._ParseNumber(&pos, str)
        if (SubStr(str, pos, 4) = "true") {
            pos += 4
            return true
        }
        if (SubStr(str, pos, 5) = "false") {
            pos += 5
            return false
        }
        if (SubStr(str, pos, 4) = "null") {
            pos += 4
            return ""
        }
        throw Error("JSON 无效字符：" ch "，位置：" pos)
    }
    static _SkipWhitespace(&pos, str) {
        while (pos <= StrLen(str) && InStr(" `t`n`r", SubStr(str, pos, 1)))
            pos++
    }
    static _ParseString(&pos, str) {
        pos++
        result := ""
        while (pos <= StrLen(str)) {
            ch := SubStr(str, pos, 1)
            if (ch = '"') {
                pos++
                return result
            }
            if (ch = "\") {
                pos++
                if (pos > StrLen(str))
                    throw Error("JSON 转义字符未完成")
                next := SubStr(str, pos, 1)
                switch next {
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    case "b": result .= Chr(8)
                    case "f": result .= Chr(12)
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "t": result .= "`t"
                    case "u":
                        if (pos + 4 > StrLen(str))
                            throw Error("JSON Unicode 转义无效")
                        hex := SubStr(str, pos + 1, 4)
                        if !RegExMatch(hex, "i)^[0-9a-f]{4}$")
                            throw Error("JSON Unicode 转义无效：" hex)
                        result .= Chr(Integer("0x" hex))
                        pos += 4
                    default: result .= next
                }
            } else {
                result .= ch
            }
            pos++
        }
        throw Error("JSON 字符串未闭合")
    }
    static _ParseNumber(&pos, str) {
        start := pos
        if (SubStr(str, pos, 1) = "-")
            pos++
        while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
            pos++
        if (SubStr(str, pos, 1) = ".") {
            pos++
            while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
                pos++
        }
        ch := SubStr(str, pos, 1)
        if (ch = "e" || ch = "E") {
            pos++
            ch := SubStr(str, pos, 1)
            if (ch = "+" || ch = "-")
                pos++
            while (pos <= StrLen(str) && RegExMatch(SubStr(str, pos, 1), "\d"))
                pos++
        }
        return Number(SubStr(str, start, pos - start))
    }
    static _ParseArray(&pos, str) {
        pos++
        arr := []
        Json._SkipWhitespace(&pos, str)
        if (SubStr(str, pos, 1) = "]") {
            pos++
            return arr
        }
        loop {
            arr.Push(Json._ParseValue(&pos, str))
            Json._SkipWhitespace(&pos, str)
            ch := SubStr(str, pos, 1)
            if (ch = "]") {
                pos++
                return arr
            }
            if (ch != ",")
                throw Error("JSON 数组缺少逗号")
            pos++
        }
    }
    static _ParseObject(&pos, str) {
        pos++
        obj := Map()
        Json._SkipWhitespace(&pos, str)
        if (SubStr(str, pos, 1) = "}") {
            pos++
            return obj
        }
        loop {
            Json._SkipWhitespace(&pos, str)
            if (SubStr(str, pos, 1) != '"')
                throw Error("JSON 对象键必须是字符串")
            key := Json._ParseString(&pos, str)
            Json._SkipWhitespace(&pos, str)
            if (SubStr(str, pos, 1) != ":")
                throw Error("JSON 缺少冒号")
            pos++
            obj[key] := Json._ParseValue(&pos, str)
            Json._SkipWhitespace(&pos, str)
            ch := SubStr(str, pos, 1)
            if (ch = "}") {
                pos++
                return obj
            }
            if (ch != ",")
                throw Error("JSON 对象缺少逗号")
            pos++
        }
    }
    static Stringify(value, pretty := true, indent := 2) {
        return Json._Serialize(value, 0, pretty, indent)
    }
    static _Serialize(value, level, pretty, indent) {
        valueType := Type(value)

        if (valueType = "Map") {
            result := "{"
            first := true
            for key, item in value {
                if first
                    first := false
                else
                    result .= ","
                if pretty
                    result .= "`n" Json._Repeat(" ", (level + 1) * indent)
                result .= Json._Quote(String(key)) ":"
                if pretty
                    result .= " "
                result .= Json._Serialize(item, level + 1, pretty, indent)
            }
            if !first && pretty
                result .= "`n" Json._Repeat(" ", level * indent)
            return result "}"
        }

        if (valueType = "Array") {
            result := "["
            first := true
            for _, item in value {
                if first
                    first := false
                else
                    result .= ","
                if pretty
                    result .= "`n" Json._Repeat(" ", (level + 1) * indent)
                result .= Json._Serialize(item, level + 1, pretty, indent)
            }
            if !first && pretty
                result .= "`n" Json._Repeat(" ", level * indent)
            return result "]"
        }

        if (valueType = "String")
            return Json._Quote(value)

        if (valueType = "Integer" || valueType = "Float") {
            return String(value)
        }

        return "null"
    }
    static _Quote(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`t", "\t")
        return '"' str '"'
    }
    static _Repeat(text, count) {
        result := ""
        loop count
            result .= text
        return result
    }
}

; ============================================================
;  Region 2.2 — GDI+ 图形渲染管理
;  统一管理 GDI+ 初始化与关闭，全局单例
; ============================================================

; ============================================================
; TRunner V0.27
; 结构化版本：核心常驻 + 功能按需初始化 + 完整资源释放
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
CoordMode "Mouse", "Screen"

#Include Core\Version.ahk
#Include Core\Json.ahk
#Include Core\GdiPlus.ahk
#Include Core\TimerManager.ahk
#Include Core\PowerManager.ahk
#Include Core\IconManager.ahk
#Include Core\FeatureManager.ahk
#Include Core\Globals.ahk
#Include Core\Config.ahk
#Include Tray\TrayMenu.ahk
#Include Core\HelpAbout.ahk
#Include Core\MenuBuild.ahk
#Include CircleMenu\Render.ahk
#Include CircleMenu\RightClick.ahk
#Include CircleMenu\Input.ahk
#Include Features\PowerTasks\PowerTasks.ahk
#Include Features\WinMgrMedia\WinMgrMedia.ahk
#Include Features\Hardware\HardwareInfo.ahk
#Include Features\Clipboard\ClipboardHistory.ahk
#Include Features\Reminder\Reminder.ahk
#Include Features\InstalledApps\InstalledApps.ahk
#Include Features\HiddenWindows\HiddenWindows.ahk
#Include Features\TopMost\TopMost.ahk
#Include ConfigEditor\ConfigEditor.ahk
#Include Main\Main.ahk

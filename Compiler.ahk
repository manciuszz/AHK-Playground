SetWorkingDir %A_ScriptDir%
SplitPath, A_AhkPath,, AhkDir

; Declaring paths and variables

appName := "AHK Playground.exe"
scriptName := "CompileThis.ahk"

paths := {}
paths["compiler"] := Format("{1}\{2}", AhkDir, "\Compiler\Ahk2Exe.exe")
paths["created"] := Format("{1}\{2}", A_WorkingDir, scriptName)
paths["input"] := Format(" {1} ""{2}\{3}""", "/in", A_WorkingDir, scriptName)
paths["output"] := Format(" {1} ""{2}\{3}""", "/out", A_WorkingDir, appName)

paths.dllFiles := {}
paths.dllFiles["folder"] := "/lib"
paths.dllFiles["ahkDll"] := paths.dllFiles["folder"] . "/AutoHotkey.dll"

paths.webFiles := {}
paths.webFiles["folder"] := "/static"
paths.webFiles["main"] := paths.webFiles["folder"] . "/main.js"
paths.webFiles["index"] := paths.webFiles["folder"] . "/index.html"
paths.webFiles["styles"] := paths.webFiles["folder"] . "/styles.css"

; Pack web files

script := ""
. "`n" "`;[Ahk2Exe Compiler Auto-Execute Section] { `; Gives the ability to pack all mandatory files to one .exe package"
. "`n" "FileCreateDir, `% A_ScriptDir . " """" paths.dllFiles["folder"] """"
. "`n" "FileCreateDir, `% A_ScriptDir . " """" paths.webFiles["folder"] """"
. "`n" "FileInstall, " A_ScriptDir . paths.dllFiles["ahkDll"] ", % A_ScriptDir . """ paths.dllFiles["ahkDll"] """"
. "`n" "FileInstall, " A_ScriptDir . paths.webFiles["main"] ", % A_ScriptDir . """ paths.webFiles["main"] """"
. "`n" "FileInstall, " A_ScriptDir . paths.webFiles["index"] ", % A_ScriptDir . """ paths.webFiles["index"] """"
. "`n" "FileInstall, " A_ScriptDir . paths.webFiles["styles"] ", % A_ScriptDir . """ paths.webFiles["styles"] """"
. "`n" "`;"
. "`n"
. "`n" "#Include AHK Playground.ahk"

; Start Compiling

FileAppend, % script, % paths["created"]
RunWait, % paths["compiler"] . paths["input"] . paths["output"]
FileDelete, % paths["created"]
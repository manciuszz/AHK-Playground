#NoEnv
#Persistent
#KeyHistory 0
#SingleInstance, force
SetBatchLines, -1

#include <AHKhttp>
#include <AhkDllThread>

@paths := {}

server := new HttpServer()
server.LoadMimes(A_ScriptDir . "/static/mime.types")
server.SetPaths(@paths)
server.Serve(8000)
; Run % "http://localhost:8000"

@paths["/"] := Func("mainPage")
mainPage(ByRef req, ByRef res) {	
    html := mountHTML()
    res.SetBodyText(html)
    res.status := 200
}

@paths["404"] := Func("notFound")
notFound(ByRef req, ByRef res) {
    res.SetBodyText("404 - Page not found!")
	res.status := 404
}

@paths["/asset/*"] := Func("asset")
asset(ByRef req, ByRef res, ByRef server) {
    server.ServeFile(res, A_ScriptDir . req.queries.path)
	if (!res.headers["Content-Type"])
		return notFound(req, res)
	res.headers["Cache-Control"] := "max-age=3600"
    res.status := 200
}

@paths["/ajax"] := Func("handleAjax")
handleAjax(ByRef req, ByRef res) {
    if (func := req.queries.func) {
        if (req.queries.params)
            params := StrSplit(req.queries.params, "|")
        retval := %func%(params ? params : [])
    }
    res.SetBodyText(retval)
    res.status := 200
}

@paths["/compile"] := Func("compiler")
compiler(ByRef req, ByRef res) {		
	output := runCode(req.body)
	res.SetBodyText(output)
	res.status := 200
}

_FileRead(path) {
	FileRead, output, % A_ScriptDir . path
	return output
}

@cache := {}
cache(key, value, shouldCache := false) { ; Enables RAM type caching strategy.
	global @cache
			
	if (IsObject(value))
		if (!shouldCache || !@cache[key])
			value := value.Call()
			
	if (!shouldCache)
		return value
	
	if (!@cache[key])
		@cache[key] := value

	return @cache[key]
}

mountHTML(htmlEndpoint := "/static/index.html", pos := 1) {
	elementsToBind := {}
	elementsToBind.title := "AHK Playground"
	elementsToBind.inputPlaceholder := "CheatSheet:"
	. "`n" "#useCOM `t`t`; Execute code via COM Interface instead of AutoHotkey.DLL"
	. "`n" "#NoOutput `t`t`; Don&#39;t wait for Std output."
	. "`n" "print(""Hello World"") `t`; Print ""Hello World"" to output window - if there&#39;s no #NoOutput directive."
	. "`n" "MsgBox, Hello World `t`; Output ""Hello World"" inside a message box."
	. "`n"
	. "`n" "AutoHotkey.DLL Specifics (https://hotkeyit.github.io/v2/docs):"
	. "`n" "dllModule := AhkDllThread(A_AhkDll) `; Import module"
	. "`n" "dllModule.ahktextdll(""MsgBox, Hello World"", """", """") `; Create new thread and execute "
	. "`n" "dllModule.addScript(""MsgBox, Hello World"", executionMethod := 2) `; Execute code and return line pointer"
	
	elementsToBind.outputPlaceholder := "Useful Editor shortcuts:"
	. "`n" "Ctrl-D `t`t`t`; Duplicate current line of code."
	. "`n" "Ctrl-Down `t`t`; Delete current line of code."
	. "`n" "Ctrl-Enter `t`t`; Execute code."
	
	HTML := cache(htmlEndpoint, Func("_FileRead").Bind(htmlEndpoint))
	while ( pos := RegExMatch(HTML, "O){{(.*)}}", foundMatch, pos + StrLen(foundMatch.1)) ) {
		bindings := StrSplit(foundMatch.1, "+")
				
		content := ""
		Loop % bindings.MaxIndex() {
			binding := Trim(bindings[ A_Index ])
			content .= elementsToBind[ binding ]
		}
		HTML := StrReplace(HTML, "{{" . foundMatch.1 . "}}", content)
	}
    	
    return HTML
}

builtInFunctions_DLL() {
	funcs = 
	( LTrim Join`n
		A_AhkDll := A_ScriptDir . "\lib\AutoHotkey.dll"
		global __stdOutput := ""
		print(msg) {
			__stdOutput .= (msg . "``n")
		}
	)
	return funcs
}

builtInFunctions_STDOUT() {
	funcs = 
	( LTrim Join`n
		print(msg) {
			FileAppend, `% msg . "``n", *
		}
	)
	return funcs
}

execScript(Script, Wait := true) {
    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec(A_AhkPath . " /ErrorStdOut *")
    exec.StdIn.Write(script)
    exec.StdIn.Close()
    if Wait
        return exec.StdOut.ReadAll()
}

execScriptWithDLL(Script, Wait) {
	static dllModule := false
	if (!dllModule)
		dllModule := AhkDllThread(A_ScriptDir . "\lib\AutoHotkey.dll")
	
	; Note: Wait=2 means add code, execute and return immediately (don't wait for code to end execution). 
	;       Wait=1 means add code, execute and wait for return.
	;       Wait=0 means add code but do not execute.
	Wait := (!Wait ? 2 : 1)
	
	hThread := dllModule.ahktextdll("", "", "")
	linePtr := dllModule.addScript(Script, Wait)
	if (Wait=1)
		return dllModule.ahkgetvar("__stdOutput")
}

runCode(injectedCode) {	
	injectedCode := StrReplace(injectedCode, "#useCOM", "", useCOM, 1) ; Creating a directive '#useCOM' to use AHK DLL code execution method.
	injectedCode := StrReplace(injectedCode, "#NoOutput", "", justCompile, 1) ; Creating a directive '#NoOutput' to not wait for response from prints.
	; injectedCode := StrReplace(injectedCode, "//", " `;") ; Allow JavaScript style comments

	if (!useCOM) {
		builtInFuncs := builtInFunctions_DLL()
		execFunc := Func("execScriptWithDLL")
	} else {
		builtInFuncs := builtInFunctions_STDOUT()
		execFunc := Func("execScript")
	}
	
    runnableScript =
    (LTrim Join`n
        ;[Directives] {
			#NoEnv
			#NoTrayIcon
			#SingleInstance Force
			#Warn All, StdOut
			; --
			SetBatchLines -1
			SendMode Input
			SetWorkingDir %A_ScriptDir%
			; --
        ;}		
				
		;[Built-In Functions] {
			%builtInFuncs%
		;}
		
		;[Body] {
			print(" > Using " . (!%useCOM% ? "AutoHotkey.DLL" : "COM Interface"))
			%injectedCode%
		;}
    )
		
    output := execFunc.Call(runnableScript, !justCompile)
	return output
}

; Hotkeys
#If WinActive("ahk_exe notepad++.exe")
^R::Reload
#NoEnv
#Persistent
#KeyHistory 0
#SingleInstance, force
SetBatchLines, -1

#include <AHKhttp>
#include <AhkDllThread>
#include <MimeTypes>

@paths := {}
@ahkDll := _RelativePath("\lib\AutoHotkey.dll")

server := new HttpServer()
server.LoadMimes(getMimeTypes())
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
    server.ServeFile(res, _RelativePath(req.queries.path))
	if (!res.headers["Content-Type"])
		return notFound(req, res)
	res.headers["Cache-Control"] := "max-age=3600"
    res.status := 200
}

; @paths["/ajax"] := Func("handleAjax")
; handleAjax(ByRef req, ByRef res) {
    ; if (func := req.queries.func) {
        ; if (req.queries.params)
            ; params := StrSplit(req.queries.params, "|")
        ; retval := %func%(params ? params : [])
    ; }
    ; res.SetBodyText(retval)
    ; res.status := 200
; }

@paths["/compile"] := Func("compiler")
compiler(ByRef req, ByRef res) {		
	output := runCode(req.body)
	res.SetBodyText(output)
	res.status := 200
}

_FileRead(path) {
	FileRead, output, % _RelativePath(path)
	return output
}

_RelativePath(path) {
	return A_ScriptDir . path
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
	. "`n" "#NoOutput `t`t`; Don&#39;t wait for printable output."
	. "`n" "#EnableMsgBox `t`t`; Enable usage of MsgBox."
	. "`n" "print(""Hello World"") `t`; Print ""Hello World"" to output window - if there&#39;s no #NoOutput directive."
	. "`n" "MsgBox, Hello World `t`; Output ""Hello World"" inside a message box."
	. "`n"
	. "`n" "AutoHotkey.DLL Specifics (https://hotkeyit.github.io/v2/docs):"
	. "`n" "#importMethods `; Import module method shortcuts"
	. "`n" "AhkTextDll(""MsgBox, Hello World"") `; Load a new thread from a string/memory/variable, current thread will be terminated."
	. "`n" "AhkAddScript(""MsgBox, Hello World"") `; Add and optionally execute additional script/code from text/memory/variable."
	. "`n" "AhkExec(""MsgBox, Hello World"") `; Execute some script/code from text/memory/variable temporarily."
	
	elementsToBind.outputPlaceholder := "Useful Editor shortcuts:"
	. "`n" "Ctrl-Q `t`t`t`; Toggle comment selected lines of code."
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

builtInFunctions_DLL(importMethods := false) {
	global @ahkDll
	
	if (importMethods) {
		importedMethods =
		( LTrim Join`n
			#DllImport, AhkAssign, %@ahkDll%\ahkassign,Str,,Str,,CDecl `; Assign a value to variable or pointer of variable.
			#DllImport, AhkGetVar, %@ahkDll%\ahkgetvar,Str,,UInt,0,CDecl `; Retrieve a value from a variable.
			#DllImport, AhkPause, %@ahkDll%\ahkPause,Str,,CDecl `; Pause Script.
			#DllImport, AhkExecuteLine, %@ahkDll%\ahkExecuteLine,PTR,,UInt,0,UInt,0,CDecl `; Executes script from given line pointer.
			#DllImport, AhkPostFunction, %@ahkDll%\ahkPostFunction,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,CDecl `; Call a function via PostMessage method (does not wait until function returns). Also used mainly with AutoHotkey.dll
			#DllImport, AhkFunction, %@ahkDll%\ahkFunction,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,Str,,CDecl `; Call a function via SendMessage method. Mainly used with AutoHotkey.dll to call a function in dll script or call a function in main script from dll.
			#DllImport, AhkTerminate, %@ahkDll%\ahkTerminate,UInt,0,CDecl `; Terminate thread.
			#DllImport, AhkReload, %@ahkDll%\ahkReload,UInt,0,CDecl `; Reload thread using same parameters used with ahkdll or ahktextdll.
			#DllImport, AhkReady, %@ahkDll%\ahkReady `; Returns 1 (true) if a thread is being executed currently, 0 (false) otherwise.
			#DllImport, AhkLabel, %@ahkDll%\ahkLabel,Str,,UInt,0,CDecl `; Goto (PostMessage) or Gosub (SendMessage) a Label.
			#DllImport, AhkDll, %@ahkDll%\ahkdll,Str,,Str,,Str,,CDecl `; Load a new thread from a file, current thread will be terminated.
			#DllImport, AhkFindFunc, %@ahkDll%\ahkFindFunc,Str,,CDecl `; Find a function and return its pointer.
			#DllImport, AhkFindLabel, %@ahkDll%\ahkFindLabel,Str,,CDecl `; Find a label and return its pointer.
			#DllImport, AhkTextDll, %@ahkDll%\ahktextdll,Str,,Str,,Str,,CDecl `; Load a new thread from a string/memory/variable, current thread will be terminated.
			#DllImport, AhkAddScript, %@ahkDll%\addScript,Str,,UInt,1,CDecl `; Add and optionally execute additional script/code from text/memory/variable.
			#DllImport, AhkAddFile, %@ahkDll%\addFile,Str,,UInt,1,CDecl `; Add and optionally execute additional script/code from file.
			#DllImport, AhkExec, %@ahkDll%\ahkExec,Str,,CDecl `; Execute some script/code from text/memory/variable temporarily.
		)
	}
	
	funcs = 
	( LTrim Join`n
		%importedMethods%

		A_AhkDll := "%@ahkDll%"
		global __stdOutput := ""
		print(msg) {
			__stdOutput .= (msg . "``n")
		}
	)
	
	return funcs
}

builtInFunctions_COM() {
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
	global @ahkDll
	static dllModule := false
	if (!dllModule)
		dllModule := AhkDllThread(@ahkDll)
	
	; Note: Wait=2 means add code, execute and return immediately (don't wait for code to end execution). 
	;       Wait=1 means add code, execute and wait for return.
	;       Wait=0 means add code but do not execute.
	Wait := (!Wait ? 2 : 1)

	hThread := dllModule.ahktextdll("", "", "")
	linePtr := dllModule.addScript(Script, Wait)
	if (Wait=1)
		return dllModule.ahkgetvar("__stdOutput")
}

runCode(browserInputCode) {	
	browserInputCode := StrReplace(browserInputCode, "#EnableMsgBox", "", enableMsgBox, 1) ; Creating a directive '#EnableMsgBox' to enable usage of MsgBox
	if (!enableMsgBox)
		browserInputCode := StrReplace(browserInputCode, "MsgBox", "OutputDebug") ; Disabling MsgBox built-in function by renaming it...
	browserInputCode := StrReplace(browserInputCode, "#useCOM", "", useCOM, 1) ; Creating a directive '#useCOM' to use AHK DLL code execution method.
	browserInputCode := StrReplace(browserInputCode, "#NoOutput", "", justCompile, 1) ; Creating a directive '#NoOutput' to not wait for response from prints.
	; browserInputCode := StrReplace(browserInputCode, "//", " `;") ; Allow JavaScript style comments

	; browserInputCode := RegExReplace(browserInputCode, "mJ)(*ANYCRLF)MsgBox(?:\W+(?<!""|\d|%)\d?(?<!""|%),?\s?,?\s?)(.*)(?<!\d)(?<!\s)(?<!,)", "FileAppend, $1, *")
	
	if (!useCOM) {
		browserInputCode := StrReplace(browserInputCode, "#importMethods", "", importMethods, 1) ; Creating a directive '#importMethods' to import AHK.DLL method shortcuts
		builtInFuncs := builtInFunctions_DLL(importMethods)
		execFunc := Func("execScriptWithDLL")
	} else {
		builtInFuncs := builtInFunctions_COM()
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
			%browserInputCode%
		;}
    )
		
    output := execFunc.Call(runnableScript, !justCompile)
	return output
}

; Hotkeys
#If WinActive("ahk_exe notepad++.exe")
^R::Reload
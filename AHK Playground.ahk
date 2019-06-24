#NoEnv
#Persistent
#KeyHistory 0
#SingleInstance, force
SetBatchLines, -1

#include <AHKhttp>

@paths := {}

server := new HttpServer()
server.LoadMimes(A_ScriptDir . "/mime.types")
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

@paths["/javascript"] := Func("javascript")
javascript(ByRef req, ByRef res) {
    if (!req.queries.path)
		return notFound(req, res)
		
	FileRead, js, % A_ScriptDir . req.queries.path
    res.SetBodyText(js)
    res.status := 200
}

@paths["/css"] := Func("css")
css(ByRef req, ByRef res, server) {
	if (!req.queries.path)
		return notFound(req, res) 
		
	FileRead, css, % A_ScriptDir . req.queries.path
    res.headers["Content-Type"] := "text/css"
    res.SetBodyText(css)
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

mountHTML(pos := 1) {
	elementsToBind := {}
	elementsToBind.title := "AHK Playground"
	elementsToBind.inputPlaceholder := "MsgBox, Hello World`nprint(""Hello World"")"
	elementsToBind.outputPlaceholder := " ... "
	
	FileRead, HTML, % A_ScriptDir . "/index.html"
	
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

builtInFunctions() {
	funcs = 
	( LTrim Join`n
		print(msg) {
			FileAppend `% (msg . "``n"), *
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

runCode(injectedCode) {	
	; injectedCode := StrReplace(injectedCode, "//", " `;") ; Allow JavaScript style comments
	
	builtInFuncs := builtInFunctions()
    runnableScript =
    (LTrim Join`n
        ;[Directives] {
			#NoEnv
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
			%injectedCode%
		;}
    )

    output := execScript(runnableScript)
	; if (!output)
		; output := ExecScript("FileAppend % (" . injectedCode . "), *")
	return output
}

; Hotkeys
#If WinActive("ahk_exe notepad++.exe")
^R::Reload
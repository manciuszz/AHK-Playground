#NoEnv
#Persistent
#KeyHistory 0
#SingleInstance, force
SetBatchLines, -1

#include <AHKhttp>

paths := {}

server := new HttpServer()
server.LoadMimes(A_ScriptDir . "/mime.types")
server.SetPaths(paths)
server.Serve(8000)

paths["/"] := Func("mainPage")
mainPage(ByRef req, ByRef res) {
    html := getHTML()
    res.SetBodyText(html)
    res.status := 200
}

paths["404"] := Func("notFound")
notFound(ByRef req, ByRef res) {
    res.SetBodyText("404 - Page not found!")
}

paths["/javascript"] := Func("javascript")
javascript(ByRef req, ByRef res) {
    js := getJS()
    res.SetBodyText(js)
    res.status := 200
}

paths["/ajax"] := Func("handleAjax")
handleAjax(ByRef req, ByRef res) {
    if (func := req.queries.func) {
        if (req.queries.params)
            params := StrSplit(req.queries.params, "|")
        retval := %func%(params ? params : [])
    }
    res.SetBodyText(retval)
    res.status := 200
}

paths["/compile"] := Func("compiler")
compiler(ByRef req, ByRef res) {		
	output := runCode(req.body)
	res.SetBodyText(output)
	res.status := 200
}

paths["/css"] := Func("css")
css(ByRef req, ByRef res, server) {
    css := getCSS()
    res.headers["Content-Type"] := "text/css"
    res.SetBodyText(css)
    res.status := 200
}

getHTML() {
	title := "AHK Playground"
    HTML := 
    ( LTrim Join
		"<!doctype html>
		<html lang='en'>
			<head>
				<meta charset='utf-8'>
				<title>" title "</title>
				<link rel='stylesheet' href='/css' />
				
				<script src='//unpkg.com/codemirror@5.23.0/lib/codemirror.js'></script>
				<script src='//unpkg.com/codemirror@5.23.0/mode/javascript/javascript.js'></script>
				<script src='//unpkg.com/codemirror@5.23.0/addon/display/placeholder.js'></script>
				<link rel='stylesheet' href='//unpkg.com/codemirror@5.23.0/lib/codemirror.css'>
			</head>
			<body>
				<h2>" title "</h2>
				<div class='row'>
				  <div class='column left' style='background-color:#aaa;'>
					<h2 class='center'>Input</h2>
					<textarea id='input' placeholder='MsgBox, Hello World'></textarea>
				  </div>
				  <div class='column right' style='background-color:#bbb;'>
					<h2 class='center'>Output</h2>
					<p id='output'>Autohotkey Output goes here...</p>
				  </div>
				</div>
				<div class='center btn'>
					<button id='runScript' type='submit' onClick='handleClick();'>Run</button>
				</div>
			</body>
			<script>
				var editor = document.getElementById('input');
				var edit = CodeMirror.fromTextArea(editor, {
					lineNumbers: true,
					mode: 'javascript'
				});
			</script>
			<script src='/javascript'></script>
		</html>"
    )
    return HTML
}

getJS() {
    JS =
    ( LTrim Join`n
		var handleClick = function() {
			let input = edit.getValue();
			let output = document.getElementById('output');
			
			fetch("/compile", {
				method: 'POST',
				headers: { 'Content-Type': 'text/plain' },
				body: input
			})
			.catch(error => { output.textContent = error; })
			.then(res => res.text())
			.then(data => { output.textContent = data; });
		};
    )
    return JS
}

getCSS() {
    CSS =
    ( LTrim Join`n		
		.center {
			margin: 0;
			padding: 15px;
			text-align: center;
			border-bottom: 1px solid black;
		}
		
		.btn {
			padding: 15px 47`% 15px 47`%;
		}
	
		.row {
		  display: flex;
		}

		.column {
		  flex: 50`%;
		}
		
		.left {
		  width: 75`%;
		}

		.right {
		  width: 25`%;
		}
		
		.CodeMirror {
		  border: 1px solid silver;
		}
		.CodeMirror-empty.CodeMirror-focused {
		  outline: none;
		}
		.CodeMirror pre.CodeMirror-placeholder {
		  color: #999;
		}
    )
    return CSS
}

ExecScript(Script, Wait := true) {
    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec("AutoHotkey.exe /ErrorStdOut *")
    exec.StdIn.Write(script)
    exec.StdIn.Close()
    if Wait
        return exec.StdOut.ReadAll()
}

runCode(_code) {	
    scriptHeader =
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
		
		
    )
	
	scriptHeader .= _code

    output := ExecScript(scriptHeader)
	if (!output)
		output := ExecScript("FileAppend % (" . _code . "), *")
	return output
}

; Hotkeys
#If WinActive("ahk_exe notepad++.exe")
^R::Reload
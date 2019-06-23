var handleClick = function() {
	let input = edit.getValue();
	let output = document.getElementById('output');
	
	output.textContent = ""; // Clear output logs. TODO: Make it optional in the future...
	fetch("/compile", {
		method: 'POST',
		headers: { 'Content-Type': 'text/plain' },
		body: input
	})
	.catch(error => { output.textContent += error; })
	.then(res => res.text())
	.then(data => { output.textContent += data; });
};

document.addEventListener('keypress', function(evt) {
	if (!evt) return;
	if (evt.keyCode === 10) { // CTRL + ENTER
		handleClick();
	}
});
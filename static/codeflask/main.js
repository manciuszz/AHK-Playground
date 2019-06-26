var handleClick = function() {
	if (!flask)
		return alert("Failed to fetch flask!");
	let input = flask.getCode();
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

document.addEventListener('keydown', function(evt) {
	if (evt.ctrlKey && evt.keyCode === 13) { // CTRL + ENTER
		evt.preventDefault();
		handleClick();
	}
});